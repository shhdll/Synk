-- Lets the host leave by handing the activity to a chosen joined participant.

begin;

create or replace function public.transfer_host_and_leave(
  requested_activity_id uuid,
  new_host_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_activity public.activities%rowtype;
  new_host_status text;
  joined_participants integer;
begin
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  -- Lock the activity first, matching join_activity_by_code and leave_activity.
  select *
  into selected_activity
  from public.activities
  where id = requested_activity_id
  for update;

  if not found then
    return jsonb_build_object(
      'result', 'not_found',
      'message', 'This activity was not found.'
    );
  end if;

  if selected_activity.host_id is distinct from current_user_id then
    return jsonb_build_object(
      'result', 'not_host',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'Only the host can transfer this activity.'
    );
  end if;

  if selected_activity.starts_at <= now() then
    return jsonb_build_object(
      'result', 'activity_started',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'This activity has already started.'
    );
  end if;

  if new_host_user_id is null or new_host_user_id = current_user_id then
    return jsonb_build_object(
      'result', 'invalid_new_host',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'Choose another participant to become the host.'
    );
  end if;

  select status
  into new_host_status
  from public.activity_participants
  where activity_id = selected_activity.id
    and user_id = new_host_user_id
  for update;

  if new_host_status is distinct from 'joined' then
    return jsonb_build_object(
      'result', 'not_eligible',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'The selected participant is no longer in this activity.'
    );
  end if;

  -- The new host is counted as the host, not as a joined participant.
  delete from public.activity_participants
  where activity_id = selected_activity.id
    and user_id = new_host_user_id;

  -- Only host_id is written; joined_count is maintained by its triggers.
  update public.activities
  set host_id = new_host_user_id
  where id = selected_activity.id;

  -- The previous host's place is filled from the waitlist.
  select 1 + count(*)
  into joined_participants
  from public.activity_participants
  where activity_id = selected_activity.id
    and status = 'joined';

  update public.activity_participants
  set status = 'joined',
      updated_at = now()
  where id in (
    select id
    from public.activity_participants
    where activity_id = selected_activity.id
      and status = 'waitlisted'
    order by updated_at asc, created_at asc, id asc
    limit greatest(selected_activity.max_participants - joined_participants, 0)
    for update
  );

  return jsonb_build_object(
    'result', 'transferred',
    'activity_id', selected_activity.id,
    'activity_title', selected_activity.title,
    'new_host_id', new_host_user_id,
    'message', 'You left the activity and transferred hosting.'
  );
end;
$$;

alter function public.transfer_host_and_leave(uuid, uuid) owner to postgres;

revoke all on function public.transfer_host_and_leave(uuid, uuid) from public;
revoke all on function public.transfer_host_and_leave(uuid, uuid) from anon;
grant execute on function public.transfer_host_and_leave(uuid, uuid) to authenticated;

commit;
