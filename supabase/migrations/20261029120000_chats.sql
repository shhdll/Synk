-- Chats: one group chat per activity, and one-to-one chats between friends.
--
-- Activity chats are created with the activity. Their members are always the
-- host and the joined participants: triggers on activities and
-- activity_participants keep chat_members in step, so joining, leaving,
-- being accepted from the waitlist or a host transfer all update the chat.
-- Deleting the activity deletes its chat.
--
-- Direct chats are opened with get_or_create_direct_chat, only between
-- friends. Messages can only be sent while the two are still friends.
--
-- Users only read chats they are members of. Every change goes through the
-- functions below.

begin;

create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('activity', 'direct')),
  activity_id uuid unique references public.activities (id) on delete cascade,
  -- Direct chats only: the pair, smaller id first.
  user_a uuid references public.users (id) on delete cascade,
  user_b uuid references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz,
  constraint chats_kind_shape check (
    (kind = 'activity' and activity_id is not null and user_a is null and user_b is null)
    or (kind = 'direct' and activity_id is null and user_a is not null and user_b is not null and user_a < user_b)
  ),
  constraint chats_direct_pair unique (user_a, user_b)
);

create table if not exists public.chat_members (
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  -- Messages after this are unread.
  last_read_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);

create index if not exists chat_members_user_idx
  on public.chat_members (user_id);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats (id) on delete cascade,
  sender_id uuid references public.users (id) on delete set null,
  body text not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_chat_idx
  on public.chat_messages (chat_id, created_at desc);

alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.chat_messages enable row level security;

create or replace function public.is_chat_member(target_chat_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.chat_members
    where chat_id = target_chat_id and user_id = auth.uid()
  );
$$;

revoke all on function public.is_chat_member(uuid) from public, anon;
grant execute on function public.is_chat_member(uuid) to authenticated;

drop policy if exists "Members can read their chats" on public.chats;
create policy "Members can read their chats"
  on public.chats for select to authenticated
  using (public.is_chat_member(id));

drop policy if exists "Members can read chat members" on public.chat_members;
create policy "Members can read chat members"
  on public.chat_members for select to authenticated
  using (public.is_chat_member(chat_id));

-- Also what realtime checks before delivering a new message.
drop policy if exists "Members can read chat messages" on public.chat_messages;
create policy "Members can read chat messages"
  on public.chat_messages for select to authenticated
  using (public.is_chat_member(chat_id));

revoke insert, update, delete on public.chats from anon, authenticated;
revoke insert, update, delete on public.chat_members from anon, authenticated;
revoke insert, update, delete on public.chat_messages from anon, authenticated;

-- The chat screen listens for new messages.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table public.chat_messages;
  end if;
end;
$$;

-- ---- Keeping activity chats in step ---------------------------------------

-- Makes the chat's members exactly the host and the joined participants.
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

revoke all on function public.sync_activity_chat(uuid) from public, anon, authenticated;

create or replace function public.sync_activity_chat_from_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.sync_activity_chat(new.id);
  return null;
end;
$$;

create or replace function public.sync_activity_chat_from_participant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    perform public.sync_activity_chat(new.activity_id);
  elsif tg_op = 'DELETE' then
    perform public.sync_activity_chat(old.activity_id);
  else
    perform public.sync_activity_chat(new.activity_id);
    if old.activity_id is distinct from new.activity_id then
      perform public.sync_activity_chat(old.activity_id);
    end if;
  end if;
  return null;
end;
$$;

revoke all on function public.sync_activity_chat_from_activity() from public, anon, authenticated;
revoke all on function public.sync_activity_chat_from_participant() from public, anon, authenticated;

drop trigger if exists sync_activity_chat_on_activity on public.activities;
create trigger sync_activity_chat_on_activity
  after insert or update of host_id on public.activities
  for each row execute function public.sync_activity_chat_from_activity();

drop trigger if exists sync_activity_chat_on_participant on public.activity_participants;
create trigger sync_activity_chat_on_participant
  after insert or update of status, user_id, activity_id or delete
  on public.activity_participants
  for each row execute function public.sync_activity_chat_from_participant();

-- Chats for the activities that already exist.
do $$
declare
  existing record;
begin
  for existing in select id from public.activities loop
    perform public.sync_activity_chat(existing.id);
  end loop;
end;
$$;

-- ---- Messages --------------------------------------------------------------

create or replace function public.touch_chat_last_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.chats
  set last_message_at = new.created_at
  where id = new.chat_id;

  -- Your own message is never unread.
  update public.chat_members
  set last_read_at = greatest(last_read_at, new.created_at)
  where chat_id = new.chat_id and user_id = new.sender_id;

  return null;
end;
$$;

revoke all on function public.touch_chat_last_message() from public, anon, authenticated;

drop trigger if exists touch_chat_last_message on public.chat_messages;
create trigger touch_chat_last_message
  after insert on public.chat_messages
  for each row execute function public.touch_chat_last_message();

-- ---- Reading ---------------------------------------------------------------

-- Every chat the user is in, newest activity first. Direct chats with
-- someone blocked either way are left out.
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

-- Everyone in a chat, for names and photos next to messages.
create or replace function public.get_chat_members(target_chat_id uuid)
returns table (
  id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text
)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, u.full_name, u.username, u.avatar_url, u.gender
  from public.chat_members m
  join public.users u on u.id = m.user_id
  where m.chat_id = target_chat_id
    and public.is_chat_member(target_chat_id)
  order by lower(coalesce(u.full_name, u.username, ''));
$$;

-- ---- Changing --------------------------------------------------------------
-- Each returns {"result": "..."} so the app can show the right message.

create or replace function public.get_or_create_direct_chat(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  found_chat_id uuid;
begin
  if target_user_id = me then
    return jsonb_build_object('result', 'self');
  end if;

  if not exists (
    select 1 from public.friendships
    where user_a = least(me, target_user_id) and user_b = greatest(me, target_user_id)
  ) then
    return jsonb_build_object('result', 'not_friends');
  end if;

  perform public.lock_user_pair(me, target_user_id);

  insert into public.chats (kind, user_a, user_b)
  values ('direct', least(me, target_user_id), greatest(me, target_user_id))
  on conflict (user_a, user_b) do nothing;

  select id into found_chat_id
  from public.chats
  where user_a = least(me, target_user_id) and user_b = greatest(me, target_user_id);

  insert into public.chat_members (chat_id, user_id)
  values (found_chat_id, me), (found_chat_id, target_user_id)
  on conflict do nothing;

  return jsonb_build_object('result', 'ok', 'chat_id', found_chat_id);
end;
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

create or replace function public.mark_chat_read(target_chat_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.chat_members
  set last_read_at = now()
  where chat_id = target_chat_id and user_id = auth.uid();
$$;

revoke all on function public.get_my_chats() from public, anon;
revoke all on function public.get_chat_members(uuid) from public, anon;
revoke all on function public.get_or_create_direct_chat(uuid) from public, anon;
revoke all on function public.send_chat_message(uuid, text) from public, anon;
revoke all on function public.mark_chat_read(uuid) from public, anon;

grant execute on function public.get_my_chats() to authenticated;
grant execute on function public.get_chat_members(uuid) to authenticated;
grant execute on function public.get_or_create_direct_chat(uuid) to authenticated;
grant execute on function public.send_chat_message(uuid, text) to authenticated;
grant execute on function public.mark_chat_read(uuid) to authenticated;

commit;
