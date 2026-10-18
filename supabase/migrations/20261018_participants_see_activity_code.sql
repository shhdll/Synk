-- Adds the activity code and participants_count.
create or replace function public.get_my_activity_participations()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      to_jsonb(activity)
      ||
      jsonb_build_object(
        'participation_id',
        participation.id,
        'participation_status',
        participation.status,
        -- host counts as one
        'participants_count',
        1 + (
          select count(*)
          from public.activity_participants as member
          where member.activity_id = activity.id
            and member.status = 'joined'
        )
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
