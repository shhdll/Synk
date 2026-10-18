-- Returns how many activities a user has completed: activities they hosted
-- or were accepted into ('joined') whose start time has passed.
-- Pending, waitlisted, and rejected requests do not count.
--
-- Defaults to the signed-in user. Passing another user's id is allowed so
-- the count can be shown on other people's profiles; only the number is
-- returned, never which activities they were.
create or replace function public.get_completed_activities_count(
  target_user_id uuid default auth.uid()
)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(distinct activity.id)::integer
  from public.activities as activity
  where activity.starts_at < now()
    and (
      activity.host_id = target_user_id
      or exists (
        select 1
        from public.activity_participants as participation
        where participation.activity_id = activity.id
          and participation.user_id = target_user_id
          and participation.status = 'joined'
      )
    );
$$;

-- Prevent anonymous access.
revoke all
on function public.get_completed_activities_count(uuid)
from public;

-- Allow signed-in users to read completed counts.
grant execute
on function public.get_completed_activities_count(uuid)
to authenticated;
