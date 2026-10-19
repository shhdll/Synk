-- Prevent a user from joining when they host another activity at the exact
-- same time, or already joined another activity on the same Riyadh calendar day.
-- Serialize joins per user so concurrent requests cannot both pass the check.
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

  -- Different activity rows can be joined concurrently, so lock by user too.
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

  -- Hosting blocks only the exact same start time. An existing joined
  -- participation blocks any other activity on that calendar date.
  if exists (
    select 1
    from public.activities other_activity
    where other_activity.id <> selected_activity.id
      and (
        (other_activity.host_id = current_user_id
          and other_activity.starts_at = selected_activity.starts_at)
        or exists (
          select 1
          from public.activity_participants participant
          where participant.activity_id = other_activity.id
            and participant.user_id = current_user_id
            and participant.status = 'joined'
            and (other_activity.starts_at at time zone 'Asia/Riyadh')::date =
                (selected_activity.starts_at at time zone 'Asia/Riyadh')::date
        )
      )
  ) then
    return jsonb_build_object(
      'result', 'time_conflict',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'You are already hosting an activity at this time or have joined another activity on this date.'
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

-- Apply the same rule when a host accepts a private activity request.
create or replace function public.review_activity_join_request(
  participation_id uuid,
  accept_request boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  current_user_id uuid := auth.uid();
  requester_id uuid;
  selected_request record;
  joined_participants integer;
  resulting_status text;
begin
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  -- Take the per-user lock before row locks, matching join_activity_by_code.
  select user_id
  into requester_id
  from public.activity_participants
  where id = participation_id;

  if not found then
    return jsonb_build_object('result', 'not_found', 'message', 'The join request was not found.');
  end if;

  perform pg_advisory_xact_lock(hashtextextended(requester_id::text, 0));

  select
    participant.id as request_id,
    participant.activity_id,
    participant.user_id,
    participant.status,
    activity.host_id,
    activity.title,
    activity.starts_at,
    activity.is_public,
    activity.max_participants
  into selected_request
  from public.activity_participants participant
  join public.activities activity on activity.id = participant.activity_id
  where participant.id = participation_id
  for update of participant, activity;

  if not found then
    return jsonb_build_object('result', 'not_found', 'message', 'The join request was not found.');
  end if;

  if selected_request.host_id <> current_user_id then
    return jsonb_build_object('result', 'not_host', 'message', 'Only the activity host can review this request.');
  end if;

  if selected_request.is_public then
    return jsonb_build_object('result', 'invalid_request', 'message', 'Public activities do not require host approval.');
  end if;

  if selected_request.status <> 'pending' then
    return jsonb_build_object(
      'result', 'already_reviewed',
      'status', selected_request.status,
      'message', 'This request has already been reviewed.'
    );
  end if;

  if not accept_request then
    resulting_status := 'rejected';
  else
    if exists (
      select 1
      from public.activities other_activity
      where other_activity.id <> selected_request.activity_id
        and (
          (other_activity.host_id = selected_request.user_id
            and other_activity.starts_at = selected_request.starts_at)
          or exists (
            select 1
            from public.activity_participants other_participant
            where other_participant.activity_id = other_activity.id
              and other_participant.user_id = selected_request.user_id
              and other_participant.status = 'joined'
              and (other_activity.starts_at at time zone 'Asia/Riyadh')::date =
                  (selected_request.starts_at at time zone 'Asia/Riyadh')::date
          )
        )
    ) then
      return jsonb_build_object(
        'result', 'time_conflict',
        'activity_id', selected_request.activity_id,
        'activity_title', selected_request.title,
        'message', 'The user is already hosting an activity at this time or has joined another activity on this date.'
      );
    end if;

    select 1 + count(*)
    into joined_participants
    from public.activity_participants
    where activity_id = selected_request.activity_id
      and status = 'joined';

    if joined_participants >= selected_request.max_participants then
      resulting_status := 'waitlisted';
    else
      resulting_status := 'joined';
    end if;
  end if;

  update public.activity_participants
  set status = resulting_status, updated_at = now()
  where id = participation_id;

  return jsonb_build_object(
    'result', resulting_status,
    'activity_id', selected_request.activity_id,
    'activity_title', selected_request.title,
    'message', case resulting_status
      when 'joined' then 'The request was accepted.'
      when 'rejected' then 'The request was rejected.'
      when 'waitlisted' then 'The activity is full. The user was moved to the waitlist.'
    end
  );
end;
$$;

revoke all on function public.review_activity_join_request(uuid, boolean) from public;
grant execute on function public.review_activity_join_request(uuid, boolean) to authenticated;
