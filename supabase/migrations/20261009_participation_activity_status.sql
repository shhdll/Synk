-- Returns the activities that the signed-in user has joined,
-- requested to join, or entered the waitlist for.
create or replace function public.get_my_activity_participations()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      (
        -- Do not expose the host's private activity code.
        to_jsonb(activity) - 'activity_code'
      )
      ||
      jsonb_build_object(
        'participation_id',
        participation.id,
        'participation_status',
        participation.status
      )
      order by activity.starts_at
    ),
    '[]'::jsonb
  )
  from public.activity_participants as participation
  join public.activities as activity
    on activity.id = participation.activity_id
  where participation.user_id = auth.uid()
    and participation.status in (
      'joined',
      'pending',
      'waitlisted'
    );
$$;

-- Prevent anonymous access to participation details.
revoke all
on function public.get_my_activity_participations()
from public;

-- Allow signed-in users to request only their own participation list.
grant execute
on function public.get_my_activity_participations()
to authenticated;