-- The activities count on profiles now counts only activities the user
-- actually checked in to, as host or as a joined member, instead of every
-- hosted or joined activity that has started.
--
-- Same name and signature as 20261018_completed_activities_count.sql, so
-- own and other people's profiles both pick it up. Only the number is
-- returned, never which activities they were.

create or replace function public.get_completed_activities_count(
  target_user_id uuid default auth.uid()
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(distinct activity.id)::integer
  from public.activities as activity
  where (
      activity.host_id = target_user_id
      and activity.host_checked_in_at is not null
    )
    or exists (
      select 1
      from public.activity_participants as participation
      where participation.activity_id = activity.id
        and participation.user_id = target_user_id
        and participation.status = 'joined'
        and participation.checked_in_at is not null
    );
$$;

revoke all on function public.get_completed_activities_count(uuid) from public, anon;
grant execute on function public.get_completed_activities_count(uuid) to authenticated;
