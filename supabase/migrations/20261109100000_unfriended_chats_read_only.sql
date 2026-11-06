-- A direct chat stays after the friendship ends, read only for both people.
--
-- remove_friend already keeps the chat and send_chat_message already
-- refuses ('not_friends'). This adds is_friend to get_my_chats so the app
-- can lock the chat for both people before anyone tries to send. Blocked
-- users' chats are still hidden, as before.
--
-- A new column, so the function is dropped and made again. Otherwise
-- unchanged from 20261105100000_keep_finished_activity_chats.sql.
--
-- Safe to run again.

begin;

drop function if exists public.get_my_chats();

create function public.get_my_chats()
returns table (
  chat_id uuid,
  kind text,
  activity_id uuid,
  activity_title text,
  activity_starts_at timestamptz,
  activity_ends_at timestamptz,
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
  last_message_sender_hidden boolean,
  last_message_at timestamptz,
  last_message_is_deleted boolean,
  last_message_has_photo boolean,
  last_message_kind text,
  last_message_label text,
  unread_count integer,
  is_muted boolean,
  created_at timestamptz,
  is_friend boolean
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
    a.ends_at,
    a.photo_url,
    a.category_label,
    a.category_emoji,
    (select count(*)::int from public.chat_members m where m.chat_id = c.id),
    other.id,
    other.full_name,
    other.username,
    other.avatar_url,
    other.gender,
    case when last_msg.id is not null
      then coalesce(public.decrypt_chat_body(last_msg.body_encrypted), '')
    end,
    case when sender_hidden.hidden
      then private.chat_stand_in_id(c.id, last_msg.sender_id)
      else last_msg.sender_id end,
    case when sender_hidden.hidden then null
      else coalesce(nullif(trim(sender.full_name), ''), sender.username) end,
    sender_hidden.hidden,
    c.last_message_at,
    last_msg.deleted_at is not null,
    last_msg.image_path is not null,
    last_msg.kind,
    coalesce(last_msg.shared_activity ->> 'title', last_msg.location_name),
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
    c.created_at,
    -- Direct chats only: false once either of you removes the other.
    c.kind = 'direct' and exists (
      select 1 from public.friendships f
      where f.user_a = c.user_a and f.user_b = c.user_b
    )
  from public.chat_members me
  join public.chats c on c.id = me.chat_id
  left join public.activities a on a.id = c.activity_id
  left join public.users other
    on c.kind = 'direct'
   and other.id = case when c.user_a = auth.uid() then c.user_b else c.user_a end
  left join lateral (
    select msg.id, msg.body_encrypted, msg.sender_id, msg.deleted_at,
      msg.image_path, msg.kind, msg.shared_activity, msg.location_name
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
  cross join lateral (
    select coalesce(
      last_msg.sender_id <> auth.uid() and private.blocked_me(last_msg.sender_id),
      false
    ) as hidden
  ) sender_hidden
  where me.user_id = auth.uid()
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
