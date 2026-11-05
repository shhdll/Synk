-- Activity codes only find activities hosted by the same gender, like the
-- discovery feed. For anyone else the code acts as if it doesn't exist:
--   * resolve_activity_code (the title preview while typing) finds nothing
--   * join_activity_by_code answers 'invalid_code', "No activity was found
--     with this code.", before anything about the activity is returned
-- Public joins from the details sheet go through join_activity_by_code too
-- (join_public_activity), so they follow the same rule. A trigger on
-- activity_participants also refuses any other new other-gender row.
-- Someone without a gender on their profile matches no one.
--
-- Needs private.same_gender from 20261108100000_same_gender_friends.sql.
-- Otherwise unchanged from 20261104170000_block_activities.sql. Safe to run
-- again.

begin;

create or replace function public.resolve_activity_code(entered_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  selected_activity public.activities%rowtype;
begin
  if auth.uid() is null then raise exception 'You must be signed in.'; end if;
  if entered_code is null or trim(entered_code) !~ '^[0-9]{6}$' then
    return jsonb_build_object('found', false);
  end if;
  select * into selected_activity from public.activities
    where activity_code = trim(entered_code);
  if not found or selected_activity.starts_at <= now()
      or selected_activity.host_id = auth.uid()
      or not private.same_gender(auth.uid(), selected_activity.host_id)
      or public.users_blocked_either_way(auth.uid(), selected_activity.host_id) then
    return jsonb_build_object('found', false);
  end if;
  return jsonb_build_object(
    'found', true,
    'activity', to_jsonb(selected_activity) - 'activity_code'
  );
end;
$$;

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
  -- Another gender's activity is answered as if the code didn't exist.
  if not found
      or (selected_activity.host_id <> current_user_id
        and not private.same_gender(current_user_id, selected_activity.host_id)) then
    return jsonb_build_object('result','invalid_code','message','No activity was found with this code.');
  end if;
  if public.users_blocked_either_way(current_user_id, selected_activity.host_id) then
    return jsonb_build_object('result','unavailable','message','This activity is unavailable.');
  end if;
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

-- Safety net on the table, for any other way a row could be added, like
-- prevent_blocked_activity_join from 20261104170000_block_activities.sql.
-- Only new rows: places from before this rule stay.
create or replace function public.prevent_other_gender_activity_join()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.activities a
    where a.id = new.activity_id
      and a.host_id <> new.user_id
      and not private.same_gender(new.user_id, a.host_id)
  ) then
    raise exception 'No activity was found with this code.';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_other_gender_activity_join() from public, anon, authenticated;

drop trigger if exists prevent_other_gender_activity_join on public.activity_participants;
create trigger prevent_other_gender_activity_join
  before insert on public.activity_participants
  for each row
  execute function public.prevent_other_gender_activity_join();

-- Places taken before this rule in upcoming activities of the other gender
-- are removed, as when leaving: the chat sync trigger takes them out of the
-- group chat, and a freed confirmed spot goes to the waitlist. Past
-- activities, and the ratings that go with them, stay as they are.
with removed as (
  delete from public.activity_participants p
  using public.activities a
  where a.id = p.activity_id
    and a.ends_at > now()
    and a.host_id <> p.user_id
    and p.status in ('joined', 'pending', 'waitlisted')
    and not private.same_gender(p.user_id, a.host_id)
  returning p.activity_id, p.status
)
select public.promote_eligible_waitlist(freed.activity_id)
from (
  select distinct activity_id from removed where status = 'joined'
) as freed;

revoke all on function public.resolve_activity_code(text) from public, anon;
grant execute on function public.resolve_activity_code(text) to authenticated;
revoke all on function public.join_activity_by_code(text) from public;
grant execute on function public.join_activity_by_code(text) to authenticated;

commit;
