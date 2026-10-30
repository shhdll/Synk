-- Deleting a message for yourself, and muting chats.
--
-- * Any member can delete any message they can see "for me": it's hidden
--   from them only, with no "This message was deleted" placeholder. Others
--   still see it.
-- * chat_members.muted marks a chat as muted for that person. The app leaves
--   muted chats out of the Chat tab badge; push notifications for messages
--   should skip muted chats too.

begin;

create table if not exists public.chat_hidden_messages (
  user_id uuid not null references public.users (id) on delete cascade,
  message_id uuid not null references public.chat_messages (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, message_id)
);

create index if not exists chat_hidden_messages_message_idx
  on public.chat_hidden_messages (message_id);

alter table public.chat_hidden_messages enable row level security;

drop policy if exists "Users can read what they hid" on public.chat_hidden_messages;
create policy "Users can read what they hid"
  on public.chat_hidden_messages for select to authenticated
  using (auth.uid() = user_id);

revoke insert, update, delete on public.chat_hidden_messages from anon, authenticated;

alter table public.chat_members
  add column if not exists muted boolean not null default false;

-- Also leaves out messages you deleted for yourself.
drop policy if exists "Members can read chat messages" on public.chat_messages;
create policy "Members can read chat messages"
  on public.chat_messages for select to authenticated
  using (
    public.can_read_chat_message(chat_id, created_at)
    and not exists (
      select 1 from public.chat_hidden_messages h
      where h.message_id = chat_messages.id and h.user_id = auth.uid()
    )
  );

create or replace function public.hide_chat_message(target_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
begin
  if not exists (
    select 1 from public.chat_messages m
    where m.id = target_message_id
      and public.can_read_chat_message(m.chat_id, m.created_at)
  ) then
    return jsonb_build_object('result', 'not_found');
  end if;

  insert into public.chat_hidden_messages (user_id, message_id)
  values (me, target_message_id)
  on conflict do nothing;

  return jsonb_build_object('result', 'hidden');
end;
$$;

create or replace function public.set_chat_muted(target_chat_id uuid, mute boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chat_members
  set muted = coalesce(mute, false)
  where chat_id = target_chat_id and user_id = public.require_signed_in();

  return jsonb_build_object('result', case when found then 'ok' else 'not_found' end);
end;
$$;

revoke all on function public.hide_chat_message(uuid) from public, anon;
revoke all on function public.set_chat_muted(uuid, boolean) from public, anon;
grant execute on function public.hide_chat_message(uuid) to authenticated;
grant execute on function public.set_chat_muted(uuid, boolean) to authenticated;

-- Adds is_muted, so a new return type: replaced rather than altered.
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
  is_muted boolean,
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
        and not exists (
          select 1 from public.chat_hidden_messages h
          where h.message_id = msg.id and h.user_id = auth.uid()
        )
    ),
    me.muted,
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
      and not exists (
        select 1 from public.chat_hidden_messages h
        where h.message_id = msg.id and h.user_id = auth.uid()
      )
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
