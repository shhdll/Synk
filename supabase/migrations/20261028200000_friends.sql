-- Friends: friend requests, friendships and blocked users.
--
-- Users only read rows that involve them. Every change goes through the
-- functions below, which keep the rules in one place:
--   * no requests to yourself, to a friend, or between blocked users
--   * a request to someone who already asked you makes you friends
--   * blocking removes the friendship and any request, both ways
-- Accepted and rejected requests are deleted, so someone can ask again later.

begin;

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.users (id) on delete cascade,
  receiver_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint friend_requests_not_self check (sender_id <> receiver_id),
  constraint friend_requests_unique_pair unique (sender_id, receiver_id)
);

create index if not exists friend_requests_receiver_idx
  on public.friend_requests (receiver_id, created_at desc);

-- One row per pair, smaller id first.
create table if not exists public.friendships (
  user_a uuid not null references public.users (id) on delete cascade,
  user_b uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  constraint friendships_ordered check (user_a < user_b)
);

create index if not exists friendships_user_b_idx
  on public.friendships (user_b);

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.users (id) on delete cascade,
  blocked_id uuid not null references public.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_not_self check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx
  on public.user_blocks (blocked_id);

alter table public.friend_requests enable row level security;
alter table public.friendships enable row level security;
alter table public.user_blocks enable row level security;

drop policy if exists "Users can read their friend requests" on public.friend_requests;
create policy "Users can read their friend requests"
  on public.friend_requests for select to authenticated
  using (auth.uid() in (sender_id, receiver_id));

drop policy if exists "Users can read their friendships" on public.friendships;
create policy "Users can read their friendships"
  on public.friendships for select to authenticated
  using (auth.uid() in (user_a, user_b));

-- Only the blocker sees a block, so nobody can tell they were blocked.
drop policy if exists "Users can read who they blocked" on public.user_blocks;
create policy "Users can read who they blocked"
  on public.user_blocks for select to authenticated
  using (auth.uid() = blocker_id);

revoke insert, update, delete on public.friend_requests from anon, authenticated;
revoke insert, update, delete on public.friendships from anon, authenticated;
revoke insert, update, delete on public.user_blocks from anon, authenticated;

-- ---- Helpers ---------------------------------------------------------------

-- Serialises changes to one pair, so two people asking each other at the
-- same moment can't leave two requests behind.
create or replace function public.lock_user_pair(first_id uuid, second_id uuid)
returns void
language sql
set search_path = ''
as $$
  select pg_advisory_xact_lock(
    hashtextextended(least(first_id, second_id)::text || greatest(first_id, second_id)::text, 0)
  );
$$;

create or replace function public.require_signed_in()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'You must be signed in.';
  end if;
  return auth.uid();
end;
$$;

revoke all on function public.lock_user_pair(uuid, uuid) from public, anon, authenticated;
revoke all on function public.require_signed_in() from public, anon, authenticated;

-- ---- Reading ---------------------------------------------------------------

create or replace function public.get_my_friends()
returns table (
  id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text,
  friends_since timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, u.full_name, u.username, u.avatar_url, u.gender, f.created_at
  from public.friendships f
  join public.users u
    on u.id = case when f.user_a = auth.uid() then f.user_b else f.user_a end
  where auth.uid() in (f.user_a, f.user_b)
  order by lower(coalesce(u.full_name, u.username, ''));
$$;

-- Both directions: is_incoming tells them apart.
create or replace function public.get_my_friend_requests()
returns table (
  id uuid,
  user_id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text,
  created_at timestamptz,
  is_incoming boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, u.id, u.full_name, u.username, u.avatar_url, u.gender,
    r.created_at, r.receiver_id = auth.uid()
  from public.friend_requests r
  join public.users u
    on u.id = case when r.sender_id = auth.uid() then r.receiver_id else r.sender_id end
  where auth.uid() in (r.sender_id, r.receiver_id)
  order by r.created_at desc;
$$;

create or replace function public.get_my_blocked_users()
returns table (
  id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text,
  blocked_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, u.full_name, u.username, u.avatar_url, u.gender, b.created_at
  from public.user_blocks b
  join public.users u on u.id = b.blocked_id
  where b.blocker_id = auth.uid()
  order by b.created_at desc;
$$;

-- People matching a name or @username, without yourself and without anyone
-- blocked in either direction.
create or replace function public.search_users(
  search_query text,
  result_limit integer default 20
)
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
  with q as (
    select replace(replace(replace(
      lower(ltrim(trim(coalesce(search_query, '')), '@')),
      '\', '\\'), '%', '\%'), '_', '\_') as term
  )
  select u.id, u.full_name, u.username, u.avatar_url, u.gender
  from public.users u, q
  where auth.uid() is not null
    and length(q.term) > 0
    and u.id <> auth.uid()
    and (
      lower(u.username) like q.term || '%'
      or lower(u.full_name) like '%' || q.term || '%'
    )
    and not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id = u.id)
         or (b.blocker_id = u.id and b.blocked_id = auth.uid())
    )
  order by
    (lower(u.username) = q.term) desc,
    (lower(u.username) like q.term || '%') desc,
    lower(coalesce(u.full_name, u.username, ''))
  limit least(greatest(coalesce(result_limit, 20), 1), 50);
$$;

-- ---- Changing --------------------------------------------------------------
-- Each returns {"result": "..."} so the app can show the right message.

create or replace function public.send_friend_request(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
begin
  if target_user_id = me then
    return jsonb_build_object('result', 'self');
  end if;

  perform public.lock_user_pair(me, target_user_id);

  if not exists (select 1 from public.users where id = target_user_id)
     or exists (
       select 1 from public.user_blocks
       where (blocker_id = me and blocked_id = target_user_id)
          or (blocker_id = target_user_id and blocked_id = me)
     ) then
    -- Same answer for blocked and missing users.
    return jsonb_build_object('result', 'not_found');
  end if;

  if exists (
    select 1 from public.friendships
    where user_a = least(me, target_user_id) and user_b = greatest(me, target_user_id)
  ) then
    return jsonb_build_object('result', 'already_friends');
  end if;

  -- They already asked: accept instead of sending a second request.
  if exists (
    select 1 from public.friend_requests
    where sender_id = target_user_id and receiver_id = me
  ) then
    delete from public.friend_requests
    where sender_id = target_user_id and receiver_id = me;

    insert into public.friendships (user_a, user_b)
    values (least(me, target_user_id), greatest(me, target_user_id))
    on conflict do nothing;

    return jsonb_build_object('result', 'now_friends');
  end if;

  insert into public.friend_requests (sender_id, receiver_id)
  values (me, target_user_id)
  on conflict (sender_id, receiver_id) do nothing;

  return jsonb_build_object('result', 'sent');
end;
$$;

create or replace function public.cancel_friend_request(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
begin
  delete from public.friend_requests
  where sender_id = me and receiver_id = target_user_id;

  return jsonb_build_object('result', case when found then 'cancelled' else 'not_found' end);
end;
$$;

create or replace function public.respond_to_friend_request(
  requester_id uuid,
  accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
begin
  perform public.lock_user_pair(me, requester_id);

  delete from public.friend_requests
  where sender_id = requester_id and receiver_id = me;

  if not found then
    return jsonb_build_object('result', 'not_found');
  end if;

  if not accept then
    return jsonb_build_object('result', 'rejected');
  end if;

  insert into public.friendships (user_a, user_b)
  values (least(me, requester_id), greatest(me, requester_id))
  on conflict do nothing;

  return jsonb_build_object('result', 'accepted');
end;
$$;

create or replace function public.remove_friend(friend_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
begin
  delete from public.friendships
  where user_a = least(me, friend_id) and user_b = greatest(me, friend_id);

  return jsonb_build_object('result', case when found then 'removed' else 'not_found' end);
end;
$$;

create or replace function public.block_user(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
begin
  if target_user_id = me then
    return jsonb_build_object('result', 'self');
  end if;

  if not exists (select 1 from public.users where id = target_user_id) then
    return jsonb_build_object('result', 'not_found');
  end if;

  perform public.lock_user_pair(me, target_user_id);

  delete from public.friendships
  where user_a = least(me, target_user_id) and user_b = greatest(me, target_user_id);

  delete from public.friend_requests
  where (sender_id = me and receiver_id = target_user_id)
     or (sender_id = target_user_id and receiver_id = me);

  insert into public.user_blocks (blocker_id, blocked_id)
  values (me, target_user_id)
  on conflict do nothing;

  return jsonb_build_object('result', 'blocked');
end;
$$;

create or replace function public.unblock_user(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
begin
  delete from public.user_blocks
  where blocker_id = me and blocked_id = target_user_id;

  return jsonb_build_object('result', case when found then 'unblocked' else 'not_found' end);
end;
$$;

revoke all on function public.get_my_friends() from public, anon;
revoke all on function public.get_my_friend_requests() from public, anon;
revoke all on function public.get_my_blocked_users() from public, anon;
revoke all on function public.search_users(text, integer) from public, anon;
revoke all on function public.send_friend_request(uuid) from public, anon;
revoke all on function public.cancel_friend_request(uuid) from public, anon;
revoke all on function public.respond_to_friend_request(uuid, boolean) from public, anon;
revoke all on function public.remove_friend(uuid) from public, anon;
revoke all on function public.block_user(uuid) from public, anon;
revoke all on function public.unblock_user(uuid) from public, anon;

grant execute on function public.get_my_friends() to authenticated;
grant execute on function public.get_my_friend_requests() to authenticated;
grant execute on function public.get_my_blocked_users() to authenticated;
grant execute on function public.search_users(text, integer) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.cancel_friend_request(uuid) to authenticated;
grant execute on function public.respond_to_friend_request(uuid, boolean) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;

commit;
