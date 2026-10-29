-- Friends going: for a list of activities, which of the signed-in user's
-- friends are the host or a joined participant.
--
-- Uses the same rule as get_activity_participants_list: only public
-- activities, or ones the user hosts or has joined or is waitlisted for.

begin;

create or replace function public.get_friends_going(activity_ids uuid[])
returns table (
  activity_id uuid,
  user_id uuid,
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
  with my_friends as (
    select case when f.user_a = auth.uid() then f.user_b else f.user_a end as friend_id
    from public.friendships f
    where auth.uid() in (f.user_a, f.user_b)
  ),
  visible as (
    select a.id, a.host_id
    from public.activities a
    where a.id = any (activity_ids[1:200])
      and (
        a.is_public
        or a.host_id = auth.uid()
        or exists (
          select 1
          from public.activity_participants viewer
          where viewer.activity_id = a.id
            and viewer.user_id = auth.uid()
            and viewer.status in ('joined', 'waitlisted')
        )
      )
  ),
  going as (
    select v.id as activity_id, v.host_id as user_id, 0 as sort_order
    from visible v
    union
    select ap.activity_id, ap.user_id, 1
    from public.activity_participants ap
    join visible v on v.id = ap.activity_id
    where ap.status = 'joined'
      and ap.user_id is distinct from v.host_id
  )
  select g.activity_id, u.id, u.full_name, u.username, u.avatar_url, u.gender
  from going g
  join my_friends mf on mf.friend_id = g.user_id
  join public.users u on u.id = g.user_id
  where auth.uid() is not null
  order by g.activity_id, g.sort_order, lower(coalesce(u.full_name, u.username, ''));
$$;

revoke all on function public.get_friends_going(uuid[]) from public, anon;
grant execute on function public.get_friends_going(uuid[]) to authenticated;

commit;
