-- Blocking in activity group chats.
--
-- Both people stay in the chat and every message stays. Only how each one
-- sees the other changes, and the server applies it, not just the app:
--   * someone who blocked you: no real id, name, username or photo, as a
--     member, as a message author (old, new and quoted messages) or in the
--     chats list. The app shows "Synk user" with a default avatar. Their id
--     is swapped for a stand-in that is the same in every message of that
--     chat (so their messages still group together) but can't be turned
--     back into the real one;
--   * someone you blocked: real name, marked as blocked, no real photo;
--   * everyone else in the chat sees both of them as normal.
-- Runs after 20261104150000_encrypt_chat_messages.sql (message text is
-- encrypted) and 20261104170000_block_activities.sql (the helpers).
-- Safe to run again.

begin;

-- ---- Stand-in ids -----------------------------------------------------------------

-- A random secret, so nobody can work out the stand-in from ids they know.
create table if not exists private.block_alias_secret (
  only_row boolean primary key default true check (only_row),
  secret text not null
    default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '')
);
-- RLS on with no policies: no app user can read it. Not forced, so the
-- security definer functions below (run as the table owner) still can.
alter table private.block_alias_secret enable row level security;

revoke all
on table private.block_alias_secret
from public, anon, authenticated;

insert into private.block_alias_secret (only_row) values (true)
  on conflict (only_row) do nothing;

-- What the signed-in user sees instead of member_id in that chat.
create or replace function private.chat_stand_in_id(chat_id uuid, member_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select md5(s.secret || ':' || chat_id || ':' || member_id || ':' || auth.uid())::uuid
  from private.block_alias_secret s;
$$;

revoke all on function private.chat_stand_in_id(uuid, uuid) from public, anon, authenticated;

-- Only the direction where the signed-in user blocked other_user_id.
create or replace function private.blocked_by_me(other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_blocks b
    where b.blocker_id = auth.uid() and b.blocked_id = other_user_id
  );
$$;

revoke all on function private.blocked_by_me(uuid) from public, anon, authenticated;

-- ---- Members ----------------------------------------------------------------------

-- Same rules as get_activity_participants_list. Two new columns, so the
-- function is dropped and made again. Otherwise unchanged from
-- 20261029120000_chats.sql.
drop function if exists public.get_chat_members(uuid);

create function public.get_chat_members(target_chat_id uuid)
returns table (
  id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text,
  is_hidden boolean,
  blocked_by_me boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    case when x.hidden then private.chat_stand_in_id(m.chat_id, u.id) else u.id end,
    case when x.hidden then null else u.full_name end,
    case when x.hidden then null else u.username end,
    case when x.hidden or x.mine then null else u.avatar_url end,
    case when x.hidden or x.mine then private.avatar_gender(u.gender) else u.gender end,
    x.hidden,
    x.mine and not x.hidden
  from public.chat_members m
  join public.users u on u.id = m.user_id
  cross join lateral (
    select
      u.id <> auth.uid() and private.blocked_me(u.id) as hidden,
      u.id <> auth.uid() and private.blocked_by_me(u.id) as mine
  ) x
  where m.chat_id = target_chat_id
    and public.is_chat_member(target_chat_id)
  order by lower(coalesce(u.full_name, u.username, ''));
$$;

revoke all on function public.get_chat_members(uuid) from public, anon;
grant execute on function public.get_chat_members(uuid) to authenticated;

-- Their row in chat_members (and so their "Seen") isn't readable by the
-- person they blocked, from the table or realtime.
drop policy if exists "Hide chat members from users they blocked" on public.chat_members;
create policy "Hide chat members from users they blocked"
  on public.chat_members
  as restrictive
  for select
  to authenticated
  using (user_id = auth.uid() or not private.blocked_me(user_id));

-- ---- Messages ---------------------------------------------------------------------

-- An earlier draft of this file had a get_chat_messages with other
-- arguments; it never ran on the shared database, but just in case.
drop function if exists public.get_chat_messages(uuid, integer, uuid);

-- 20261104150000_encrypt_chat_messages.sql's version, with the text still
-- decrypted, plus: for a sender who blocked the viewer, sender_id is the
-- stand-in, and so is an older photo's file name when it has their id in
-- it (newer photos don't). Same arguments, so it's replaced in place.
create or replace function public.get_chat_messages(
  target_chat_id uuid,
  message_ids uuid[] default null,
  max_count integer default 200
)
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with key as (select public.chat_message_key() as value)
  select
    case when x.hidden then
      item || jsonb_build_object(
        'sender_id', private.chat_stand_in_id(m.chat_id, m.sender_id),
        'image_path', case when position(m.sender_id::text in coalesce(m.image_path, '')) > 0
          then null else m.image_path end
      )
    else item end
  from public.chat_messages m
  cross join key
  cross join lateral (
    select
      m.sender_id is not null
        and m.sender_id <> auth.uid()
        and private.blocked_me(m.sender_id) as hidden,
      (to_jsonb(m) - 'body_encrypted') || jsonb_build_object(
        'body', coalesce(extensions.pgp_sym_decrypt(m.body_encrypted, key.value), '')
      ) as item
  ) x
  where m.chat_id = target_chat_id
    and (message_ids is null or m.id = any (message_ids))
    and public.can_read_chat_message(m.chat_id, m.created_at)
    and not exists (
      select 1 from public.chat_hidden_messages h
      where h.message_id = m.id and h.user_id = auth.uid()
    )
  order by m.created_at desc
  limit least(greatest(coalesce(max_count, 200), 1), 500);
$$;

revoke all on function public.get_chat_messages(uuid, uuid[], integer) from public, anon;
grant execute on function public.get_chat_messages(uuid, uuid[], integer) to authenticated;

-- The table no longer gives out sender_id, so it can't be read around the
-- function. Realtime leaves it out too; the app already loads each new
-- message through get_chat_messages. Every other column stays readable.
revoke select on public.chat_messages from anon, authenticated;
do $$
declare
  readable text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position)
  into readable
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'chat_messages'
    and column_name <> 'sender_id';
  execute format('grant select (%s) on public.chat_messages to authenticated', readable);
end;
$$;

-- ---- Chats list -------------------------------------------------------------------

-- The last message's sender, redacted the same way. Adds
-- last_message_sender_hidden, so the function is dropped and made again.
-- Otherwise unchanged from 20261104150000_encrypt_chat_messages.sql.
drop function if exists public.get_my_chats();

create function public.get_my_chats()
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
  last_message_sender_hidden boolean,
  last_message_at timestamptz,
  last_message_is_deleted boolean,
  last_message_has_photo boolean,
  last_message_kind text,
  last_message_label text,
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
    c.created_at
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
