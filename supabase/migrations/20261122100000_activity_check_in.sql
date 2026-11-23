-- Members check in when they arrive at an activity. Allowed only while the
-- activity is running and only within 200 m of its location; the distance
-- is checked here so the app can't skip the rule.

alter table public.activity_participants
  add column if not exists checked_in_at timestamptz;

-- Great-circle distance in meters between two coordinates (haversine).
create or replace function public.distance_meters(
  lat1 double precision, lon1 double precision,
  lat2 double precision, lon2 double precision
)
returns double precision
language sql
immutable
strict
set search_path = ''
as $$
  select 2 * 6371000 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2)
    + cos(radians(lat1)) * cos(radians(lat2))
      * power(sin(radians(lon2 - lon1) / 2), 2)
  ));
$$;

create or replace function public.check_in_to_activity(
  requested_activity_id uuid,
  user_latitude double precision,
  user_longitude double precision
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  check_in_radius_meters constant double precision := 200;
  current_user_id uuid := auth.uid();
  selected_activity public.activities%rowtype;
  participant_status text;
  previous_check_in timestamptz;
  distance double precision;
  checked_in timestamptz;
begin
  if current_user_id is null then raise exception 'You must be signed in.'; end if;

  select * into selected_activity from public.activities where id = requested_activity_id;
  if not found then
    return jsonb_build_object('result', 'not_found', 'message', 'This activity was not found.');
  end if;

  if selected_activity.host_id = current_user_id then
    return jsonb_build_object('result', 'host', 'message', 'Hosts do not need to check in.');
  end if;

  select status, checked_in_at into participant_status, previous_check_in
    from public.activity_participants
    where activity_id = requested_activity_id and user_id = current_user_id
    for update;
  if participant_status is distinct from 'joined' then
    return jsonb_build_object('result', 'not_participating',
      'message', 'Only members of this activity can check in.');
  end if;

  if previous_check_in is not null then
    return jsonb_build_object('result', 'already_checked_in',
      'checked_in_at', previous_check_in, 'message', 'You have already checked in.');
  end if;

  if now() < selected_activity.starts_at then
    return jsonb_build_object('result', 'not_started',
      'message', 'Check-in opens when the activity starts.');
  end if;
  if now() >= coalesce(selected_activity.ends_at, selected_activity.starts_at + interval '2 hours') then
    return jsonb_build_object('result', 'ended', 'message', 'This activity has ended.');
  end if;

  if selected_activity.latitude is null or selected_activity.longitude is null then
    return jsonb_build_object('result', 'no_location',
      'message', 'This activity has no location to check in at.');
  end if;

  if user_latitude is null or user_longitude is null
      or user_latitude not between -90 and 90
      or user_longitude not between -180 and 180 then
    return jsonb_build_object('result', 'invalid_location', 'message', 'Your location is invalid.');
  end if;

  distance := public.distance_meters(user_latitude, user_longitude,
    selected_activity.latitude, selected_activity.longitude);

  if distance > check_in_radius_meters then
    return jsonb_build_object('result', 'too_far',
      'distance_meters', round(distance)::int,
      'radius_meters', check_in_radius_meters::int,
      'message', 'You need to be at the activity location to check in.');
  end if;

  update public.activity_participants
    set checked_in_at = now()
    where activity_id = requested_activity_id and user_id = current_user_id
    returning checked_in_at into checked_in;

  return jsonb_build_object('result', 'checked_in', 'checked_in_at', checked_in,
    'distance_meters', round(distance)::int, 'message', 'You are checked in.');
end;
$$;
revoke all on function public.check_in_to_activity(uuid, double precision, double precision) from public, anon;
grant execute on function public.check_in_to_activity(uuid, double precision, double precision) to authenticated;

-- When the signed-in user checked in to an activity, or null.
create or replace function public.get_my_activity_check_in(requested_activity_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select checked_in_at from public.activity_participants
  where activity_id = requested_activity_id and user_id = auth.uid();
$$;
revoke all on function public.get_my_activity_check_in(uuid) from public, anon;
grant execute on function public.get_my_activity_check_in(uuid) to authenticated;
