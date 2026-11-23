-- Hosts check in too, by the same rules as members: while the activity is
-- running and within 200 m of its location. The host has no
-- activity_participants row, so their time is kept on the activity.
--
-- Hosts can update their activity and the check-in columns must only be
-- set by check_in_to_activity, so a trigger keeps them unchanged on any
-- other write.

alter table public.activities
  add column if not exists host_checked_in_at timestamptz;

-- Leaves check-in times as they were unless check_in_to_activity is the
-- one writing them.
create or replace function private.protect_check_in_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  allowed boolean := current_setting('synk.check_in', true) = 'on';
begin
  if allowed then return new; end if;

  if tg_table_name = 'activities' then
    new.host_checked_in_at := case when tg_op = 'INSERT' then null else old.host_checked_in_at end;
  else
    new.checked_in_at := case when tg_op = 'INSERT' then null else old.checked_in_at end;
  end if;
  return new;
end;
$$;
revoke all on function private.protect_check_in_columns() from public, anon, authenticated;

drop trigger if exists activities_protect_check_in on public.activities;
create trigger activities_protect_check_in
  before insert or update on public.activities
  for each row execute function private.protect_check_in_columns();

drop trigger if exists activity_participants_protect_check_in on public.activity_participants;
create trigger activity_participants_protect_check_in
  before insert or update on public.activity_participants
  for each row execute function private.protect_check_in_columns();

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
  is_host boolean;
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

  is_host := selected_activity.host_id = current_user_id;

  if is_host then
    select host_checked_in_at into previous_check_in
      from public.activities where id = requested_activity_id for update;
  else
    select status, checked_in_at into participant_status, previous_check_in
      from public.activity_participants
      where activity_id = requested_activity_id and user_id = current_user_id
      for update;
    if participant_status is distinct from 'joined' then
      return jsonb_build_object('result', 'not_participating',
        'message', 'Only members of this activity can check in.');
    end if;
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

  -- Lets protect_check_in_columns accept this write, for this transaction only.
  perform set_config('synk.check_in', 'on', true);

  if is_host then
    update public.activities
      set host_checked_in_at = now()
      where id = requested_activity_id
      returning host_checked_in_at into checked_in;
  else
    update public.activity_participants
      set checked_in_at = now()
      where activity_id = requested_activity_id and user_id = current_user_id
      returning checked_in_at into checked_in;
  end if;

  perform set_config('synk.check_in', 'off', true);

  return jsonb_build_object('result', 'checked_in', 'checked_in_at', checked_in,
    'distance_meters', round(distance)::int, 'message', 'You are checked in.');
end;
$$;
revoke all on function public.check_in_to_activity(uuid, double precision, double precision) from public, anon;
grant execute on function public.check_in_to_activity(uuid, double precision, double precision) to authenticated;

-- When the signed-in user checked in to an activity, as host or member,
-- or null.
create or replace function public.get_my_activity_check_in(requested_activity_id uuid)
returns timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select host_checked_in_at from public.activities
      where id = requested_activity_id and host_id = auth.uid()),
    (select checked_in_at from public.activity_participants
      where activity_id = requested_activity_id and user_id = auth.uid())
  );
$$;
revoke all on function public.get_my_activity_check_in(uuid) from public, anon;
grant execute on function public.get_my_activity_check_in(uuid) to authenticated;
