-- Adds leave_activity() and makes it the only way to withdraw from an activity.

begin;

create or replace function public.leave_activity(
  requested_activity_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_activity public.activities%rowtype;
  previous_status text;
  joined_participants integer;
begin
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  -- Lock the activity first, matching join_activity_by_code.
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

  if selected_activity.host_id = current_user_id then
    return jsonb_build_object(
      'result', 'host',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'Hosts cannot leave their own activity.'
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

  select status
  into previous_status
  from public.activity_participants
  where activity_id = selected_activity.id
    and user_id = current_user_id
  for update;

  -- Rejected records are kept so the user cannot request again.
  if previous_status is null or previous_status = 'rejected' then
    return jsonb_build_object(
      'result', 'not_participating',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'You are no longer part of this activity.'
    );
  end if;

  delete from public.activity_participants
  where activity_id = selected_activity.id
    and user_id = current_user_id
    and status in ('joined', 'pending', 'waitlisted');

  if previous_status = 'joined' then
    -- The host counts as the first participant.
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
  end if;

  return jsonb_build_object(
    'result',
      case previous_status
        when 'joined' then 'left'
        when 'waitlisted' then 'left_waitlist'
        else 'cancelled'
      end,
    'activity_id', selected_activity.id,
    'activity_title', selected_activity.title,
    'message',
      case previous_status
        when 'joined' then 'You have successfully left this activity.'
        when 'waitlisted' then 'You have been removed from the waitlist.'
        else 'Your join request has been cancelled.'
      end
  );
end;
$$;

revoke all on function public.leave_activity(uuid) from public;
revoke all on function public.leave_activity(uuid) from anon;
grant execute on function public.leave_activity(uuid) to authenticated;

-- Withdrawals must go through leave_activity().
drop policy if exists "Users can delete own participation record"
  on public.activity_participants;

revoke delete on table public.activity_participants from anon, authenticated;

commit;
