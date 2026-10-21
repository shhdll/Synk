-- Check the current activity rows for an exact start-time conflict.
-- A separate activity later on the same day should not block a join.
create or replace function public.join_activity_by_code(
  entered_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  selected_activity public.activities%rowtype;
  existing_status text;
  resulting_status text;
  joined_participants integer;
begin
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  if entered_code is null or trim(entered_code) !~ '^[0-9]{6}$' then
    return jsonb_build_object(
      'result', 'invalid_code',
      'message', 'Enter a valid six-digit activity code.'
    );
  end if;

  -- Serialize this user's joins so concurrent requests see the same state.
  perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 0));

  select *
  into selected_activity
  from public.activities
  where activity_code = trim(entered_code)
  for update;

  if not found then
    return jsonb_build_object(
      'result', 'invalid_code',
      'message', 'No activity was found with this code.'
    );
  end if;

  if selected_activity.starts_at <= now() then
    return jsonb_build_object(
      'result', 'activity_started',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'This activity is no longer available to join.'
    );
  end if;

  if selected_activity.host_id = current_user_id then
    return jsonb_build_object(
      'result', 'host',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'You are the host of this activity.'
    );
  end if;

  select status
  into existing_status
  from public.activity_participants
  where activity_id = selected_activity.id
    and user_id = current_user_id;

  if existing_status is not null then
    return jsonb_build_object(
      'result', existing_status,
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'is_public', selected_activity.is_public,
      'message', case existing_status
        when 'joined' then 'You have already joined this activity.'
        when 'pending' then 'Your request is waiting for host approval.'
        when 'waitlisted' then 'You are already on the waitlist.'
        when 'rejected' then 'Your request was rejected by the host.'
      end
    );
  end if;

  -- Use the current start times. A host or joined participant is blocked
  -- only when the existing activity starts at the same time.
  if exists (
    select 1
    from public.activities as other_activity
    where other_activity.id <> selected_activity.id
      and other_activity.starts_at = selected_activity.starts_at
      and (
        other_activity.host_id = current_user_id
        or exists (
          select 1
          from public.activity_participants as participant
          where participant.activity_id = other_activity.id
            and participant.user_id = current_user_id
            and participant.status = 'joined'
        )
      )
  ) then
    return jsonb_build_object(
      'result', 'time_conflict',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'You are already hosting or have joined an activity at this start time.'
    );
  end if;

  if selected_activity.is_public then
    select 1 + count(*)
    into joined_participants
    from public.activity_participants
    where activity_id = selected_activity.id
      and status = 'joined';

    if joined_participants >= selected_activity.max_participants then
      resulting_status := 'waitlisted';
    else
      resulting_status := 'joined';
    end if;
  else
    resulting_status := 'pending';
  end if;

  insert into public.activity_participants (activity_id, user_id, status)
  values (selected_activity.id, current_user_id, resulting_status);

  return jsonb_build_object(
    'result', resulting_status,
    'activity_id', selected_activity.id,
    'activity_title', selected_activity.title,
    'is_public', selected_activity.is_public,
    'message', case resulting_status
      when 'joined' then 'You joined the activity successfully.'
      when 'pending' then 'Your request was sent to the host.'
      when 'waitlisted' then 'The activity is full. You were added to the waitlist.'
    end
  );
end;
$$;

revoke all on function public.join_activity_by_code(text) from public;
grant execute on function public.join_activity_by_code(text) to authenticated;
