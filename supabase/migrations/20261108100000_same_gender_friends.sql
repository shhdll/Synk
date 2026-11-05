-- Friends only within the same gender, like the discovery feed
-- (20261021220000_same_gender_discovery_feed.sql):
--   * search_users leaves out people of the other gender
--   * send_friend_request to them answers 'not_found', the same as for a
--     blocked or missing user, so it doesn't tell anything about them
--   * respond_to_friend_request can't accept one either
--   * pending requests between genders made before this are removed
-- Someone without a gender on their profile matches no one.
-- Friendships made before this are kept.
--
-- Otherwise unchanged from 20261028200000_friends.sql. Safe to run again.

begin;

create or replace function private.same_gender(first_id uuid, second_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select lower(trim(a.gender)) = lower(trim(b.gender))
    from public.users a, public.users b
    where a.id = first_id
      and b.id = second_id
      and coalesce(trim(a.gender), '') <> ''
      and coalesce(trim(b.gender), '') <> ''
  ), false);
$$;

revoke all on function private.same_gender(uuid, uuid) from public, anon, authenticated;

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
    and private.same_gender(auth.uid(), u.id)
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
     or not private.same_gender(me, target_user_id)
     or exists (
       select 1 from public.user_blocks
       where (blocker_id = me and blocked_id = target_user_id)
          or (blocker_id = target_user_id and blocked_id = me)
     ) then
    -- Same answer for blocked, missing and other-gender users.
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

  -- The request is gone either way; only same-gender ones become friends.
  if not private.same_gender(me, requester_id) then
    return jsonb_build_object('result', 'not_found');
  end if;

  insert into public.friendships (user_a, user_b)
  values (least(me, requester_id), greatest(me, requester_id))
  on conflict do nothing;

  return jsonb_build_object('result', 'accepted');
end;
$$;

-- Requests between genders from before this rule.
delete from public.friend_requests r
where not private.same_gender(r.sender_id, r.receiver_id);

revoke all on function public.search_users(text, integer) from public, anon;
revoke all on function public.send_friend_request(uuid) from public, anon;
revoke all on function public.respond_to_friend_request(uuid, boolean) from public, anon;
grant execute on function public.search_users(text, integer) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_to_friend_request(uuid, boolean) to authenticated;

commit;
