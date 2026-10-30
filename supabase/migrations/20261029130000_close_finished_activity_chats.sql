-- Activity chats close when the activity finishes.
--
-- Deleting an activity already deletes its chat (chats.activity_id cascades).
-- This adds the same for finished activities, whose ends_at has passed:
--   * get_my_chats hides them and send_chat_message refuses ('finished')
--     straight away
--   * a cron job deletes them, with their messages, every five minutes
--   * sync_activity_chat no longer recreates them, and moving an activity's
--     end time re-runs it, so a chat appears or goes with the new time

begin;

create or replace function public.sync_activity_chat(target_activity_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_chat_id uuid;
begin
  if not exists (select 1 from public.activities where id = target_activity_id) then
    return;
  end if;

  -- A finished activity has no chat, so a late change doesn't bring it back.
  if exists (
    select 1 from public.activities
    where id = target_activity_id and ends_at <= now()
  ) then
    delete from public.chats where activity_id = target_activity_id;
    return;
  end if;

  insert into public.chats (kind, activity_id)
  values ('activity', target_activity_id)
  on conflict (activity_id) do nothing;

  select id into target_chat_id
  from public.chats
  where activity_id = target_activity_id;

  with wanted as (
    select a.host_id as user_id
    from public.activities a
    where a.id = target_activity_id and a.host_id is not null
    union
    select ap.user_id
    from public.activity_participants ap
    where ap.activity_id = target_activity_id and ap.status = 'joined'
  )
  insert into public.chat_members (chat_id, user_id)
  select target_chat_id, w.user_id
  from wanted w
  join public.users u on u.id = w.user_id
  on conflict do nothing;

  delete from public.chat_members cm
  where cm.chat_id = target_chat_id
    and not exists (
      select 1 from public.activities a
      where a.id = target_activity_id and a.host_id = cm.user_id
    )
    and not exists (
      select 1 from public.activity_participants ap
      where ap.activity_id = target_activity_id
        and ap.user_id = cm.user_id
        and ap.status = 'joined'
    );
end;
$$;

-- Also when the end time changes.
drop trigger if exists sync_activity_chat_on_activity on public.activities;
create trigger sync_activity_chat_on_activity
  after insert or update of host_id, ends_at on public.activities
  for each row execute function public.sync_activity_chat_from_activity();

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
    (
      select count(*)::int
      from public.chat_messages msg
      where msg.chat_id = c.id
        and msg.created_at > me.last_read_at
        and msg.sender_id is distinct from auth.uid()
    ),
    c.created_at
  from public.chat_members me
  join public.chats c on c.id = me.chat_id
  left join public.activities a on a.id = c.activity_id
  left join public.users other
    on c.kind = 'direct'
   and other.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
  left join lateral (
    select msg.body, msg.sender_id
    from public.chat_messages msg
    where msg.chat_id = c.id
    order by msg.created_at desc
    limit 1
  ) last_msg on true
  left join public.users sender on sender.id = last_msg.sender_id
  where me.user_id = auth.uid()
    -- Finished, but the cron job hasn't deleted it yet.
    and (c.kind = 'direct' or a.ends_at > now())
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

create or replace function public.send_chat_message(target_chat_id uuid, message_body text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  target_chat public.chats;
  other_id uuid;
  cleaned text := trim(coalesce(message_body, ''));
  new_message public.chat_messages;
begin
  if length(cleaned) = 0 or length(cleaned) > 2000 then
    return jsonb_build_object('result', 'invalid');
  end if;

  if not public.is_chat_member(target_chat_id) then
    return jsonb_build_object('result', 'not_member');
  end if;

  select * into target_chat from public.chats where id = target_chat_id;

  if target_chat.kind = 'activity' and exists (
    select 1 from public.activities
    where id = target_chat.activity_id and ends_at <= now()
  ) then
    return jsonb_build_object('result', 'finished');
  end if;

  if target_chat.kind = 'direct' then
    other_id := case when target_chat.user_a = me then target_chat.user_b else target_chat.user_a end;
    if not exists (
      select 1 from public.friendships
      where user_a = target_chat.user_a and user_b = target_chat.user_b
    ) or exists (
      select 1 from public.user_blocks
      where (blocker_id = me and blocked_id = other_id)
         or (blocker_id = other_id and blocked_id = me)
    ) then
      return jsonb_build_object('result', 'not_friends');
    end if;
  end if;

  insert into public.chat_messages (chat_id, sender_id, body)
  values (target_chat_id, me, cleaned)
  returning * into new_message;

  return jsonb_build_object(
    'result', 'sent',
    'message', jsonb_build_object(
      'id', new_message.id,
      'chat_id', new_message.chat_id,
      'sender_id', new_message.sender_id,
      'body', new_message.body,
      'created_at', new_message.created_at
    )
  );
end;
$$;

-- Deletes the chats, and their messages, of activities that have finished.
create or replace function public.delete_finished_activity_chats()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted integer;
begin
  delete from public.chats c
  using public.activities a
  where c.activity_id = a.id
    and a.ends_at <= now();

  get diagnostics deleted = row_count;
  return deleted;
end;
$$;

-- Only the cron job should run this.
revoke all on function public.delete_finished_activity_chats() from public, anon, authenticated;

create extension if not exists pg_cron with schema pg_catalog;

-- Remove the old job first so running this again doesn't add a second one.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'delete-finished-activity-chats') then
    perform cron.unschedule('delete-finished-activity-chats');
  end if;
end;
$$;

select cron.schedule(
  'delete-finished-activity-chats',
  '*/5 * * * *',
  $cron$select public.delete_finished_activity_chats();$cron$
);

-- Chats of activities that finished before this ran.
select public.delete_finished_activity_chats();

commit;
