-- Who has checked in to an activity, so the host and every joined member
-- can see it in the participants list. Anyone else gets no rows.
-- People who blocked the viewer are left out, as they show as hidden there.

create or replace function public.get_activity_check_ins(p_activity_id uuid)
returns table (user_id uuid, checked_in_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  with activity as (
    select a.id, a.host_id, a.host_checked_in_at
    from public.activities a
    where a.id = p_activity_id
      and auth.uid() is not null
      and (
        a.host_id = auth.uid()
        or exists (
          select 1 from public.activity_participants viewer
          where viewer.activity_id = a.id
            and viewer.user_id = auth.uid()
            and viewer.status = 'joined'
        )
      )
  ),
  check_ins as (
    select activity.host_id as user_id, activity.host_checked_in_at as checked_in_at
    from activity
    where activity.host_checked_in_at is not null
    union all
    select ap.user_id, ap.checked_in_at
    from activity
    join public.activity_participants ap
      on ap.activity_id = activity.id
    where ap.status = 'joined'
      and ap.checked_in_at is not null
  )
  select c.user_id, c.checked_in_at
  from check_ins c
  where not exists (
    select 1 from public.user_blocks b
    where b.blocker_id = c.user_id and b.blocked_id = auth.uid()
  )
  order by c.checked_in_at;
$$;
revoke all on function public.get_activity_check_ins(uuid) from public, anon;
grant execute on function public.get_activity_check_ins(uuid) to authenticated;
