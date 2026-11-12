-- The activities a user hid from their recent activities, newest first,
-- so they can unhide them. Unhiding deletes the row (allowed by RLS).
--
-- Safe to run again.

begin;

create or replace function public.get_my_hidden_recent_activities()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', activity.id,
        'host_id', activity.host_id,
        'title', activity.title,
        'starts_at', activity.starts_at,
        'ends_at', activity.ends_at,
        'is_public', activity.is_public,
        'photo_url', activity.photo_url,
        'category_emoji', activity.category_emoji,
        'category_label', activity.category_label
      )
      order by activity.starts_at desc, activity.id
    ),
    '[]'::jsonb
  )
  from public.hidden_recent_activities as hidden
  join public.activities as activity on activity.id = hidden.activity_id
  where hidden.user_id = auth.uid()
    and activity.ends_at <= now()
    and public.is_activity_attendee(activity.id, auth.uid());
$$;

revoke all on function public.get_my_hidden_recent_activities()
  from public, anon;
grant execute on function public.get_my_hidden_recent_activities()
  to authenticated;

commit;
