-- Keep private-request approval conflict checks aligned with activity joining.
-- Another activity on the same date is allowed when its start time differs.
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
    -- Only a simultaneous activity conflicts. Same-day activities at other
    -- times are valid; this matches join_activity_by_code.
    if exists (
      select 1
      from public.activities other_activity
      where other_activity.id <> selected_request.activity_id
        and other_activity.starts_at = selected_request.starts_at
        and (
          other_activity.host_id = selected_request.user_id
          or exists (
            select 1
            from public.activity_participants other_participant
            where other_participant.activity_id = other_activity.id
              and other_participant.user_id = selected_request.user_id
              and other_participant.status = 'joined'
          )
        )
    ) then
      return jsonb_build_object(
        'result', 'time_conflict',
        'activity_id', selected_request.activity_id,
        'activity_title', selected_request.title,
        'message', 'The user is already hosting or has joined an activity at this start time.'
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
