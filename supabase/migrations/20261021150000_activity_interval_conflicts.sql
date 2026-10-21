-- Store complete activity intervals. Existing activities have no end time, so
-- preserve them with a two-hour end until hosts can edit their schedules.
alter table public.activities add column if not exists ends_at timestamptz;

update public.activities
set ends_at = starts_at + interval '2 hours'
where ends_at is null;

alter table public.activities alter column ends_at set not null;

alter table public.activities drop constraint if exists activities_valid_interval;
alter table public.activities add constraint activities_valid_interval
  check (ends_at > starts_at);

create or replace function public.activity_intervals_overlap(
  first_start timestamptz,
  first_end timestamptz,
  second_start timestamptz,
  second_end timestamptz
)
returns boolean
language sql
immutable
parallel safe
as $$
  select first_start < second_end and second_start < first_end;
$$;

revoke all on function public.activity_intervals_overlap(timestamptz, timestamptz, timestamptz, timestamptz) from public;
grant execute on function public.activity_intervals_overlap(timestamptz, timestamptz, timestamptz, timestamptz) to authenticated;

-- Shared authoritative conflict query used by create/edit and Flutter's
-- preflight check. Pending requests and waitlist entries are not commitments.
create or replace function public.activity_schedule_conflicts(
  target_user_id uuid,
  proposed_start timestamptz,
  proposed_end timestamptz,
  excluded_activity_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.activities activity
    where activity.id is distinct from excluded_activity_id
      and activity.ends_at > now()
      and public.activity_intervals_overlap(
        activity.starts_at, activity.ends_at, proposed_start, proposed_end
      )
      and (
        activity.host_id = target_user_id
        or exists (
          select 1
          from public.activity_participants participant
          where participant.activity_id = activity.id
            and participant.user_id = target_user_id
            and participant.status = 'joined'
        )
      )
  );
$$;

revoke all on function public.activity_schedule_conflicts(uuid, timestamptz, timestamptz, uuid) from public;
revoke all on function public.activity_schedule_conflicts(uuid, timestamptz, timestamptz, uuid) from anon, authenticated;

create or replace function public.check_activity_schedule(
  proposed_start timestamptz,
  proposed_end timestamptz,
  excluded_activity_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;
  if proposed_start is null or proposed_end is null or proposed_end <= proposed_start then
    return jsonb_build_object('result', 'invalid_interval', 'conflict', true,
      'message', 'The activity end time must be after its start time.');
  end if;
  return jsonb_build_object(
    'result', case when public.activity_schedule_conflicts(
      current_user_id, proposed_start, proposed_end, excluded_activity_id
    ) then 'time_conflict' else 'available' end,
    'conflict', public.activity_schedule_conflicts(
      current_user_id, proposed_start, proposed_end, excluded_activity_id
    ),
    'message', case when public.activity_schedule_conflicts(
      current_user_id, proposed_start, proposed_end, excluded_activity_id
    ) then 'You already have an activity scheduled during this time. Please choose a different date or time.'
    else 'This time is available.' end
  );
end;
$$;

revoke all on function public.check_activity_schedule(timestamptz, timestamptz, uuid) from public;
grant execute on function public.check_activity_schedule(timestamptz, timestamptz, uuid) to authenticated;

-- Validate host commitments, end time, and participant capacity for every
-- insert and schedule/capacity update, including direct API writes.
create or replace function public.validate_activity_schedule_and_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  confirmed_count integer;
begin
  if new.ends_at is null then
    new.ends_at := new.starts_at + interval '2 hours';
  end if;
  if new.starts_at is null or new.ends_at <= new.starts_at then
    raise exception 'The activity end time must be after its start time.'
      using errcode = '23514';
  end if;

  if new.host_id is not null then
    perform pg_advisory_xact_lock(hashtextextended(new.host_id::text, 0));
    if new.ends_at > now() and public.activity_schedule_conflicts(
      new.host_id, new.starts_at, new.ends_at,
      case when tg_op = 'UPDATE' then old.id else null end
    ) then
      raise exception 'You already have an activity scheduled during this time. Please choose a different date or time.'
        using errcode = '23P01';
    end if;
  end if;

  if tg_op = 'UPDATE' and new.max_participants is distinct from old.max_participants then
    select 1 + count(*) into confirmed_count
    from public.activity_participants
    where activity_id = old.id and status = 'joined';
    if new.max_participants < confirmed_count then
      raise exception 'Capacity cannot be lower than the current number of participants.'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists activities_prevent_host_same_time on public.activities;
drop function if exists public.prevent_host_same_time_activities();
drop trigger if exists activities_validate_schedule_capacity on public.activities;
create trigger activities_validate_schedule_capacity
before insert or update of host_id, starts_at, ends_at, max_participants
on public.activities
for each row execute function public.validate_activity_schedule_and_capacity();

-- After any confirmed transition, remove only overlapping pending requests and
-- waitlist entries. The transaction that confirms the membership also commits
-- these cleanups, so a failed confirmation cannot leave partial changes.
create or replace function public.cleanup_conflicting_unconfirmed_participation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  confirmed_activity public.activities%rowtype;
begin
  if tg_op = 'UPDATE' then
    if new.status <> 'joined' or old.status = 'joined' then return new; end if;
  elsif new.status <> 'joined' then
    return new;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(new.user_id::text, 0));
  select * into confirmed_activity from public.activities where id = new.activity_id;
  if not found then return new; end if;

  delete from public.activity_participants other_participant
  using public.activities other_activity
  where other_participant.activity_id = other_activity.id
    and other_participant.user_id = new.user_id
    and other_participant.status in ('pending', 'waitlisted')
    and other_activity.id <> confirmed_activity.id
    and public.activity_intervals_overlap(
      confirmed_activity.starts_at, confirmed_activity.ends_at,
      other_activity.starts_at, other_activity.ends_at
    );
  return new;
end;
$$;

drop trigger if exists activity_participant_cleanup_conflicts on public.activity_participants;
create trigger activity_participant_cleanup_conflicts
after insert or update of status on public.activity_participants
for each row execute function public.cleanup_conflicting_unconfirmed_participation();

create or replace function public.cleanup_after_activity_creation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_participants participant
  using public.activities other_activity
  where participant.activity_id = other_activity.id
    and participant.user_id = new.host_id
    and participant.status in ('pending', 'waitlisted')
    and other_activity.id <> new.id
    and public.activity_intervals_overlap(
      new.starts_at, new.ends_at, other_activity.starts_at, other_activity.ends_at
    );
  return new;
end;
$$;

drop trigger if exists activity_cleanup_pending_after_create on public.activities;
create trigger activity_cleanup_pending_after_create
after insert on public.activities
for each row execute function public.cleanup_after_activity_creation();

-- Promote the first eligible waitlisted users, skipping candidates who became
-- unavailable because of a confirmed overlapping commitment elsewhere.
create or replace function public.promote_eligible_waitlist(requested_activity_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_activity public.activities%rowtype;
  candidate record;
  confirmed_count integer;
  promoted_count integer := 0;
begin
  select * into selected_activity from public.activities
    where id = requested_activity_id for update;
  if not found then return 0; end if;

  loop
    select 1 + count(*) into confirmed_count from public.activity_participants
      where activity_id = requested_activity_id and status = 'joined';
    exit when confirmed_count >= selected_activity.max_participants;

    select * into candidate from public.activity_participants
      where activity_id = requested_activity_id and status = 'waitlisted'
      order by updated_at asc, created_at asc, id asc limit 1;
    exit when not found;

    perform pg_advisory_xact_lock(hashtextextended(candidate.user_id::text, 0));
    select * into candidate from public.activity_participants
      where id = candidate.id and status = 'waitlisted' for update;
    if not found then continue; end if;
    if public.activity_schedule_conflicts(candidate.user_id,
        selected_activity.starts_at, selected_activity.ends_at, selected_activity.id) then
      delete from public.activity_participants where id = candidate.id;
    else
      update public.activity_participants set status = 'joined', updated_at = now()
        where id = candidate.id;
      promoted_count := promoted_count + 1;
    end if;
  end loop;
  return promoted_count;
end;
$$;

-- Replace the joining RPC with interval-aware checks. User locks serialize
-- joins to different activities; activity locks serialize capacity changes.
create or replace function public.join_activity_by_code(entered_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_activity public.activities%rowtype;
  existing_status text;
  resulting_status text;
  joined_participants integer;
begin
  if current_user_id is null then raise exception 'You must be signed in.'; end if;
  if entered_code is null or trim(entered_code) !~ '^[0-9]{6}$' then
    return jsonb_build_object('result','invalid_code','message','Enter a valid six-digit activity code.');
  end if;
  perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 0));
  select * into selected_activity from public.activities
  where activity_code = trim(entered_code) for update;
  if not found then return jsonb_build_object('result','invalid_code','message','No activity was found with this code.'); end if;
  if selected_activity.starts_at <= now() then
    return jsonb_build_object('result','activity_started','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','This activity is no longer available to join.');
  end if;
  if selected_activity.host_id = current_user_id then
    return jsonb_build_object('result','host','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','You are the host of this activity.');
  end if;
  select status into existing_status from public.activity_participants
  where activity_id = selected_activity.id and user_id = current_user_id;
  if existing_status is not null then
    return jsonb_build_object('result',existing_status,'activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'is_public',selected_activity.is_public,
      'message',case existing_status when 'joined' then 'You have already joined this activity.'
        when 'pending' then 'Your request is waiting for host approval.'
        when 'waitlisted' then 'You are already on the waitlist.'
        else 'Your request was rejected by the host.' end);
  end if;
  if public.activity_schedule_conflicts(current_user_id, selected_activity.starts_at,
      selected_activity.ends_at, selected_activity.id) then
    return jsonb_build_object('result','time_conflict','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,
      'message','You already have an activity scheduled during this time. Please choose a different date or time.');
  end if;
  if selected_activity.is_public then
    select 1 + count(*) into joined_participants from public.activity_participants
      where activity_id = selected_activity.id and status = 'joined';
    resulting_status := case when joined_participants >= selected_activity.max_participants
      then 'waitlisted' else 'joined' end;
  else
    resulting_status := 'pending';
  end if;
  insert into public.activity_participants(activity_id,user_id,status)
  values(selected_activity.id,current_user_id,resulting_status);
  return jsonb_build_object('result',resulting_status,'activity_id',selected_activity.id,
    'activity_title',selected_activity.title,'is_public',selected_activity.is_public,
    'message',case resulting_status when 'joined' then 'You joined the activity successfully.'
      when 'pending' then 'Your request was sent to the host.'
      else 'The activity is full. You were added to the waitlist.' end);
end;
$$;

revoke all on function public.join_activity_by_code(text) from public;
grant execute on function public.join_activity_by_code(text) to authenticated;

-- Pending requests can overlap, but a confirmed conflict blocks acceptance.
-- The user advisory lock makes simultaneous acceptances mutually exclusive.
create or replace function public.review_activity_join_request(
  participation_id uuid, accept_request boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  requester_id uuid;
  selected_request record;
  joined_participants integer;
  resulting_status text;
begin
  if current_user_id is null then raise exception 'You must be signed in.'; end if;
  select user_id into requester_id from public.activity_participants where id = participation_id;
  if not found then return jsonb_build_object('result','not_found','message','The join request was not found.'); end if;
  perform pg_advisory_xact_lock(hashtextextended(requester_id::text, 0));
  select p.id as request_id,p.activity_id,p.user_id,p.status,a.host_id,a.title,
      a.starts_at,a.ends_at,a.is_public,a.max_participants
    into selected_request
    from public.activity_participants p join public.activities a on a.id=p.activity_id
    where p.id=participation_id for update of p,a;
  if not found then return jsonb_build_object('result','not_found','message','The join request was not found.'); end if;
  if selected_request.host_id <> current_user_id then
    return jsonb_build_object('result','not_host','message','Only the activity host can review this request.');
  end if;
  if selected_request.is_public or selected_request.status <> 'pending' then
    return jsonb_build_object('result','already_reviewed','status',selected_request.status,
      'message','This request is no longer pending.');
  end if;
  if not accept_request then
    update public.activity_participants set status='rejected',updated_at=now() where id=participation_id;
    return jsonb_build_object('result','rejected','status','rejected','activity_id',selected_request.activity_id,
      'activity_title',selected_request.title,'message','The request was rejected.');
  end if;
  if public.activity_schedule_conflicts(requester_id,selected_request.starts_at,
      selected_request.ends_at,selected_request.activity_id) then
    return jsonb_build_object('result','time_conflict','activity_id',selected_request.activity_id,
      'activity_title',selected_request.title,
      'message','The user has another confirmed activity scheduled during this time.');
  end if;
  select 1 + count(*) into joined_participants from public.activity_participants
    where activity_id=selected_request.activity_id and status='joined';
  resulting_status := case when joined_participants >= selected_request.max_participants
    then 'waitlisted' else 'joined' end;
  update public.activity_participants set status=resulting_status,updated_at=now() where id=participation_id;
  return jsonb_build_object('result',resulting_status,'status',resulting_status,
    'activity_id',selected_request.activity_id,'activity_title',selected_request.title,
    'message',case resulting_status when 'joined' then 'The request was accepted.'
      else 'The activity is full. The user was moved to the waitlist.' end);
end;
$$;

revoke all on function public.review_activity_join_request(uuid, boolean) from public;
grant execute on function public.review_activity_join_request(uuid, boolean) to authenticated;

-- Keep leave and host transfer atomic while routing vacancies through the same
-- conflict-aware waitlist promotion logic.
create or replace function public.leave_activity(requested_activity_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_activity public.activities%rowtype;
  previous_status text;
begin
  if current_user_id is null then raise exception 'You must be signed in.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 0));
  select * into selected_activity from public.activities where id=requested_activity_id for update;
  if not found then return jsonb_build_object('result','not_found','message','This activity was not found.'); end if;
  if selected_activity.host_id=current_user_id then
    return jsonb_build_object('result','host','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','Hosts cannot leave their own activity.');
  end if;
  if selected_activity.starts_at<=now() then
    return jsonb_build_object('result','activity_started','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','This activity has already started.');
  end if;
  select status into previous_status from public.activity_participants
    where activity_id=requested_activity_id and user_id=current_user_id for update;
  if previous_status is null or previous_status='rejected' then
    return jsonb_build_object('result','not_participating','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','You are no longer part of this activity.');
  end if;
  delete from public.activity_participants where activity_id=requested_activity_id
    and user_id=current_user_id and status in ('joined','pending','waitlisted');
  if previous_status='joined' then perform public.promote_eligible_waitlist(requested_activity_id); end if;
  return jsonb_build_object('result',case previous_status when 'joined' then 'left'
      when 'waitlisted' then 'left_waitlist' else 'cancelled' end,
    'activity_id',selected_activity.id,'activity_title',selected_activity.title,
    'message',case previous_status when 'joined' then 'You have successfully left this activity.'
      when 'waitlisted' then 'You have been removed from the waitlist.'
      else 'Your join request has been cancelled.' end);
end;
$$;
revoke all on function public.leave_activity(uuid) from public, anon;
grant execute on function public.leave_activity(uuid) to authenticated;

create or replace function public.transfer_host_and_leave(
  requested_activity_id uuid, new_host_user_id uuid
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
begin
  if current_user_id is null then raise exception 'You must be signed in.'; end if;
  if new_host_user_id is not null then
    if current_user_id < new_host_user_id then
      perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 0));
      perform pg_advisory_xact_lock(hashtextextended(new_host_user_id::text, 0));
    else
      perform pg_advisory_xact_lock(hashtextextended(new_host_user_id::text, 0));
      perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 0));
    end if;
  end if;
  select * into selected_activity from public.activities where id=requested_activity_id for update;
  if not found then return jsonb_build_object('result','not_found','message','This activity was not found.'); end if;
  if selected_activity.host_id is distinct from current_user_id then
    return jsonb_build_object('result','not_host','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','Only the host can transfer this activity.');
  end if;
  if selected_activity.starts_at<=now() then
    return jsonb_build_object('result','activity_started','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','This activity has already started.');
  end if;
  if new_host_user_id is null or new_host_user_id=current_user_id then
    return jsonb_build_object('result','invalid_new_host','message','Choose another participant to become the host.');
  end if;
  select status into new_host_status from public.activity_participants
    where activity_id=requested_activity_id and user_id=new_host_user_id for update;
  if new_host_status is distinct from 'joined' then
    return jsonb_build_object('result','not_eligible','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','The selected participant is no longer in this activity.');
  end if;
  if public.activity_schedule_conflicts(new_host_user_id,selected_activity.starts_at,
      selected_activity.ends_at,selected_activity.id) then
    return jsonb_build_object('result','time_conflict','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','The selected participant has another activity scheduled during this time.');
  end if;
  delete from public.activity_participants where activity_id=requested_activity_id and user_id=new_host_user_id;
  update public.activities set host_id=new_host_user_id where id=requested_activity_id;
  delete from public.activity_participants participant
    using public.activities other_activity
    where participant.activity_id=other_activity.id
      and participant.user_id=new_host_user_id
      and participant.status in ('pending','waitlisted')
      and other_activity.id<>selected_activity.id
      and public.activity_intervals_overlap(selected_activity.starts_at,
        selected_activity.ends_at,other_activity.starts_at,other_activity.ends_at);
  perform public.promote_eligible_waitlist(requested_activity_id);
  return jsonb_build_object('result','transferred','activity_id',selected_activity.id,
    'activity_title',selected_activity.title,'new_host_id',new_host_user_id,
    'message','You left the activity and transferred hosting.');
end;
$$;
revoke all on function public.transfer_host_and_leave(uuid, uuid) from public, anon;
grant execute on function public.transfer_host_and_leave(uuid, uuid) to authenticated;
