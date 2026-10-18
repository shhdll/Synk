-- Withholds private activity locations from pending requesters and adds host and count fields.

begin;

create or replace function public.get_my_activity_participations()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      (
        (to_jsonb(activity) - 'activity_code'::text)
        - (
            case
              when not activity.is_public and participation.status = 'pending'
                then array['location_name', 'location_address', 'latitude', 'longitude']::text[]
              else array[]::text[]
            end
          )
      )
      || jsonb_build_object(
        'participation_id', participation.id,
        'participation_status', participation.status,
        'host_name', host_user.full_name,
        'host_username', host_user.username,
        'host_avatar_url', host_user.avatar_url,
        'host_gender', host_user.gender,
        -- The host counts as the first participant.
        'participants_count', 1 + (
          select count(*)
          from public.activity_participants jp
          where jp.activity_id = activity.id
            and jp.status = 'joined'
        )
      )
      order by activity.starts_at
    ),
    '[]'::jsonb
  )
  from public.activity_participants as participation
  join public.activities as activity
    on activity.id = participation.activity_id
  left join public.users as host_user
    on host_user.id = activity.host_id
  where participation.user_id = auth.uid()
    and participation.status in ('joined', 'pending', 'waitlisted');
$$;

revoke all on function public.get_my_activity_participations() from public;
revoke all on function public.get_my_activity_participations() from anon;
grant execute on function public.get_my_activity_participations() to authenticated;

commit;
