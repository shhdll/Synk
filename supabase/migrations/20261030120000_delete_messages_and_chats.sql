-- Deleting messages and chats.
--
-- * A sender can delete their own message for everyone. The row stays, so
--   the chat shows "This message was deleted", but its text and photo path
--   are cleared. The app removes the photo file itself (only the Storage API
--   can), under the new owner delete policy.
-- * Anyone can delete a chat for themselves only: chat_members.cleared_at
--   hides it and every message up to then for that person. A newer message
--   brings the chat back, showing only what came after.

begin;

alter table public.chat_messages
  add column if not exists deleted_at timestamptz;

-- A deleted message has neither text nor photo.
alter table public.chat_messages
  drop constraint if exists chat_messages_body_or_image;
alter table public.chat_messages
  add constraint chat_messages_body_or_image check (
    length(body) <= 2000
    and (
      deleted_at is not null
      or image_path is not null
      or length(trim(body)) >= 1
    )
  );

alter table public.chat_members
  add column if not exists cleared_at timestamptz;

-- Messages from before you deleted the chat are no longer yours to read.
create or replace function public.can_read_chat_message(
  target_chat_id uuid,
  sent_at timestamptz
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.chat_members
    where chat_id = target_chat_id
      and user_id = auth.uid()
      and (cleared_at is null or sent_at > cleared_at)
  );
$$;

revoke all on function public.can_read_chat_message(uuid, timestamptz) from public, anon;
grant execute on function public.can_read_chat_message(uuid, timestamptz) to authenticated;

drop policy if exists "Members can read chat messages" on public.chat_messages;
create policy "Members can read chat messages"
  on public.chat_messages for select to authenticated
  using (public.can_read_chat_message(chat_id, created_at));

drop policy if exists "chat-photos: owner delete" on storage.objects;
create policy "chat-photos: owner delete"
on storage.objects for delete
to authenticated
using (bucket_id = 'chat-photos' and owner = auth.uid());

-- Returns the deleted photo's path, for the app to remove the file.
create or replace function public.delete_chat_message(target_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  old_photo text;
begin
  select image_path into old_photo
  from public.chat_messages
  where id = target_message_id and sender_id = me and deleted_at is null
  for update;

  if not found then
    return jsonb_build_object('result', 'not_found');
  end if;

  update public.chat_messages
  set deleted_at = now(), body = '', image_path = null
  where id = target_message_id;

  return jsonb_build_object('result', 'deleted', 'image_path', old_photo);
end;
$$;

create or replace function public.delete_chat_for_me(target_chat_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chat_members
  set cleared_at = now(), last_read_at = greatest(last_read_at, now())
  where chat_id = target_chat_id and user_id = public.require_signed_in();

  return jsonb_build_object('result', case when found then 'deleted' else 'not_found' end);
end;
$$;

revoke all on function public.delete_chat_message(uuid) from public, anon;
revoke all on function public.delete_chat_for_me(uuid) from public, anon;
grant execute on function public.delete_chat_message(uuid) to authenticated;
grant execute on function public.delete_chat_for_me(uuid) to authenticated;

-- Adds last_message_is_deleted and last_message_has_photo, so a new return
-- type: replaced rather than altered.
drop function if exists public.get_my_chats();

create or replace function public.get_my_chats()
returns table (
  chat_id uuid,
  kind text,
  activity_id uuid,
  activity_title text,
  activity_starts_at timestamptz,
  activity_photo_url text,
  activity_category_label text,
  activity_category_emoji text,
  member_count integer,
  other_user_id uuid,
  other_full_name text,
  other_username text,
  other_avatar_url text,
  other_gender text,
  last_message_body text,
  last_message_sender_id uuid,
  last_message_sender_name text,
  last_message_at timestamptz,
  last_message_is_deleted boolean,
  last_message_has_photo boolean,
  unread_count integer,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    c.id,
    c.kind,
    a.id,
    a.title,
    a.starts_at,
    a.photo_url,
    a.category_label,
    a.category_emoji,
    (select count(*)::int from public.chat_members m where m.chat_id = c.id),
    other.id,
    other.full_name,
    other.username,
    other.avatar_url,
    other.gender,
    last_msg.body,
    last_msg.sender_id,
    coalesce(nullif(trim(sender.full_name), ''), sender.username),
    c.last_message_at,
    last_msg.deleted_at is not null,
    last_msg.image_path is not null,
    (
      select count(*)::int
      from public.chat_messages msg
      where msg.chat_id = c.id
        and msg.created_at > me.last_read_at
        and msg.sender_id is distinct from auth.uid()
        and msg.deleted_at is null
    ),
    c.created_at
  from public.chat_members me
  join public.chats c on c.id = me.chat_id
  left join public.activities a on a.id = c.activity_id
  left join public.users other
    on c.kind = 'direct'
   and other.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
  left join lateral (
    select msg.body, msg.sender_id, msg.deleted_at, msg.image_path
    from public.chat_messages msg
    where msg.chat_id = c.id
      and (me.cleared_at is null or msg.created_at > me.cleared_at)
    order by msg.created_at desc
    limit 1
  ) last_msg on true
  left join public.users sender on sender.id = last_msg.sender_id
  where me.user_id = auth.uid()
    -- Finished, but the cron job hasn't deleted it yet.
    and (c.kind = 'direct' or a.ends_at > now())
    -- Deleted for you, and nothing new since.
    and (
      me.cleared_at is null
      or coalesce(c.last_message_at, c.created_at) > me.cleared_at
    )
    and (
      c.kind = 'activity'
      or not exists (
        select 1 from public.user_blocks b
        where (b.blocker_id = auth.uid() and b.blocked_id = other.id)
           or (b.blocker_id = other.id and b.blocked_id = auth.uid())
      )
    )
  order by coalesce(c.last_message_at, c.created_at) desc;
$$;

revoke all on function public.get_my_chats() from public, anon;
grant execute on function public.get_my_chats() to authenticated;

commit;
