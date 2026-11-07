-- People to add on Find people, before anything is typed.
--
-- Same gender only, never blocked or suspended (users_blocked_either_way),
-- not already friends and no request either way. Ranked by activities done
-- together, then mutual friends, then shared interests. People with none of
-- these aren't suggested.
--
-- Safe to run again.

begin;

create or replace function public.suggest_people(result_limit integer default 10)
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
  with me as (
    select u.id, coalesce(u.interests, '{}') as interests
    from public.users u
    where u.id = auth.uid()
  ),
  -- Activities the user hosted or joined.
  my_activities as (
    select a.id as activity_id
    from public.activities a, me
    where a.host_id = me.id
    union
    select ap.activity_id
    from public.activity_participants ap, me
    where ap.user_id = me.id and ap.status = 'joined'
  ),
  together as (
    select people.user_id, count(distinct people.activity_id) as n
    from (
      select a.host_id as user_id, a.id as activity_id
      from public.activities a
      join my_activities m on m.activity_id = a.id
      union
      select ap.user_id, ap.activity_id
      from public.activity_participants ap
      join my_activities m on m.activity_id = ap.activity_id
      where ap.status = 'joined'
    ) people
    group by people.user_id
  ),
  my_friends as (
    select case when f.user_a = me.id then f.user_b else f.user_a end as friend_id
    from public.friendships f, me
    where me.id in (f.user_a, f.user_b)
  ),
  mutual as (
    select case when f.user_a = mf.friend_id then f.user_b else f.user_a end as user_id,
      count(*) as n
    from public.friendships f
    join my_friends mf on mf.friend_id in (f.user_a, f.user_b)
    group by 1
  )
  select u.id, u.full_name, u.username, u.avatar_url, u.gender
  from public.users u
  cross join me
  left join together t on t.user_id = u.id
  left join mutual mu on mu.user_id = u.id
  cross join lateral (
    select count(*) as n
    from unnest(coalesce(u.interests, '{}')) as i
    where i = any (me.interests)
  ) shared
  where u.id <> me.id
    and private.same_gender(me.id, u.id)
    and not public.users_blocked_either_way(me.id, u.id)
    and not exists (select 1 from my_friends mf where mf.friend_id = u.id)
    and not exists (
      select 1 from public.friend_requests r
      where (r.sender_id = me.id and r.receiver_id = u.id)
         or (r.sender_id = u.id and r.receiver_id = me.id)
    )
    and coalesce(t.n, 0) * 3 + coalesce(mu.n, 0) * 2 + shared.n > 0
  order by
    coalesce(t.n, 0) * 3 + coalesce(mu.n, 0) * 2 + shared.n desc,
    lower(coalesce(u.full_name, u.username, ''))
  limit least(greatest(coalesce(result_limit, 10), 1), 30);
$$;

revoke all on function public.suggest_people(integer) from public, anon;
grant execute on function public.suggest_people(integer) to authenticated;

commit;
