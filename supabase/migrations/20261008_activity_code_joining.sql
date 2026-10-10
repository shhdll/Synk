-- Adds a unique six-digit code to every activity.

-- Add the activity_code column.
-- It is nullable temporarily so existing activities can be updated safely.
alter table public.activities
add column if not exists activity_code text;

-- Generates a random six-digit numeric code.
-- The loop makes sure the generated code is not already used.
create or replace function public.generate_activity_code()
returns text
language plpgsql
volatile
set search_path = public
as $$
declare
  new_code text;
begin
  loop
    -- Generate a number between 100000 and 999999.
    new_code :=
      floor(random() * 900000 + 100000)::integer::text;

    -- Stop only when the code is unique.
    exit when not exists (
      select 1
      from public.activities
      where activity_code = new_code
    );
  end loop;

  return new_code;
end;
$$;

-- Prevent two activities from having the same code.
-- PostgreSQL allows multiple null values temporarily.
create unique index if not exists activities_activity_code_key
on public.activities (activity_code);

-- Generate codes for activities that were created before this migration.
do $$
declare
  activity_row record;
begin
  for activity_row in
    select id
    from public.activities
    where activity_code is null
  loop
    update public.activities
    set activity_code = public.generate_activity_code()
    where id = activity_row.id;
  end loop;
end;
$$;

-- Automatically generate a code whenever a new activity is created.
alter table public.activities
alter column activity_code
set default public.generate_activity_code();

-- Every activity must have a code after existing rows are updated.
alter table public.activities
alter column activity_code
set not null;

-- Ensure the stored code contains exactly six digits.
do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'activities_activity_code_six_digits'
  ) then
    alter table public.activities
    add constraint activities_activity_code_six_digits
    check (activity_code ~ '^[0-9]{6}$');
  end if;
end;
$$;


-- Stores activity participants, private join requests, and waitlist entries.
create table if not exists public.activity_participants (
  -- Unique identifier for each participation record.
  id uuid primary key default gen_random_uuid(),

  -- The activity the user wants to join.
  -- The participation record is deleted if the activity is deleted.
  activity_id uuid not null
    references public.activities(id)
    on delete cascade,

  -- The user associated with this participation record.
  -- The record is deleted if the authentication account is deleted.
  user_id uuid not null
    references auth.users(id)
    on delete cascade,

  -- joined: The user is an activity participant.
  -- pending: The private activity request is waiting for host approval.
  -- waitlisted: The activity is full.
  -- rejected: The host rejected the private activity request.
  status text not null
    check (
      status in (
        'joined',
        'pending',
        'waitlisted',
        'rejected'
      )
    ),

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- A user can only have one record for the same activity.
  unique (activity_id, user_id)
);

-- Improve queries that load all participants or requests for an activity.
create index if not exists activity_participants_activity_id_idx
on public.activity_participants (activity_id);

-- Improve queries that load all activities associated with a user.
create index if not exists activity_participants_user_id_idx
on public.activity_participants (user_id);

-- Improve queries that filter joined, pending, or waitlisted users.
create index if not exists activity_participants_status_idx
on public.activity_participants (status);

-- Protect participation records using Row Level Security.
alter table public.activity_participants
enable row level security;


-- Checks whether the signed-in user is the host of an activity.
-- Security definer avoids recursive RLS checks between related tables.
create or replace function public.is_activity_host(
  requested_activity_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.activities
    where id = requested_activity_id
      and host_id = auth.uid()
  );
$$;

-- Checks whether the signed-in user has joined an activity.
create or replace function public.is_joined_activity(
  requested_activity_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select exists (
    select 1
    from public.activity_participants
    where activity_id = requested_activity_id
      and user_id = auth.uid()
      and status = 'joined'
  );
$$;

-- Do not allow anonymous users to call the security helper functions.
revoke all
on function public.is_activity_host(uuid)
from public;

revoke all
on function public.is_joined_activity(uuid)
from public;

-- Signed-in users may use the helper functions.
grant execute
on function public.is_activity_host(uuid)
to authenticated;

grant execute
on function public.is_joined_activity(uuid)
to authenticated;

-- Remove old versions of the policies if the migration is rerun.
drop policy if exists
"Users and hosts can view participation records"
on public.activity_participants;

-- A user can view their own participation record.
-- A host can view all requests and participants for their activities.
create policy
"Users and hosts can view participation records"
on public.activity_participants
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_activity_host(activity_id)
);

-- Make sure RLS protection is active on the activities table.
alter table public.activities
enable row level security;

drop policy if exists
"Joined users can view private activities"
on public.activities;

-- An accepted participant can view a private activity.
-- Existing public and host policies remain active alongside this policy.
create policy
"Joined users can view private activities"
on public.activities
for select
to authenticated
using (
  public.is_joined_activity(id)
);


-- Joins an activity using its six-digit code.
-- Public activities allow immediate joining when a place is available.
-- Private activities create a pending request for the host.
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
  -- Only authenticated users can join activities.
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  -- Reject empty codes or values that are not exactly six digits.
  if entered_code is null
    or trim(entered_code) !~ '^[0-9]{6}$' then
    return jsonb_build_object(
      'result', 'invalid_code',
      'message', 'Enter a valid six-digit activity code.'
    );
  end if;

  -- Lock the activity while checking capacity.
  -- This prevents two users from taking the final place simultaneously.
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

  -- Users cannot join after the activity start time.
if selected_activity.starts_at <= now() then
  return jsonb_build_object(
    'result', 'activity_started',
    'activity_id', selected_activity.id,
    'activity_title', selected_activity.title,
    'message', 'This activity is no longer available to join.'
  );
end if;

  -- The host is already counted as a participant.
  if selected_activity.host_id = current_user_id then
    return jsonb_build_object(
      'result', 'host',
      'activity_id', selected_activity.id,
      'activity_title', selected_activity.title,
      'message', 'You are the host of this activity.'
    );
  end if;

  -- Prevent duplicate participation and duplicate private requests.
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
      'message',
        case existing_status
          when 'joined' then
            'You have already joined this activity.'
          when 'pending' then
            'Your request is waiting for host approval.'
          when 'waitlisted' then
            'You are already on the waitlist.'
          when 'rejected' then
            'Your request was rejected by the host.'
        end
    );
  end if;

  if selected_activity.is_public then
    -- The host counts as the first participant.
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
    -- Private activities always require host approval.
    resulting_status := 'pending';
  end if;

  insert into public.activity_participants (
    activity_id,
    user_id,
    status
  )
  values (
    selected_activity.id,
    current_user_id,
    resulting_status
  );

  return jsonb_build_object(
    'result', resulting_status,
    'activity_id', selected_activity.id,
    'activity_title', selected_activity.title,
    'is_public', selected_activity.is_public,
    'message',
      case resulting_status
        when 'joined' then
          'You joined the activity successfully.'
        when 'pending' then
          'Your request was sent to the host.'
        when 'waitlisted' then
          'The activity is full. You were added to the waitlist.'
      end
  );
end;
$$;

-- Prevent anonymous or public access to the join function.
revoke all
on function public.join_activity_by_code(text)
from public;

-- Allow signed-in users to join using an activity code.
grant execute
on function public.join_activity_by_code(text)
to authenticated;

-- Allows the activity host to accept or reject a private join request.
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
  selected_request record;
  joined_participants integer;
  resulting_status text;
begin
  -- Only authenticated users can review requests.
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  -- Load and lock both the request and its activity.
  -- The lock keeps capacity checks correct when requests are reviewed quickly.
  select
    participant.id as request_id,
    participant.activity_id,
    participant.status,
    activity.host_id,
    activity.title,
    activity.is_public,
    activity.max_participants
  into selected_request
  from public.activity_participants participant
  join public.activities activity
    on activity.id = participant.activity_id
  where participant.id = participation_id
  for update of participant, activity;

  if not found then
    return jsonb_build_object(
      'result', 'not_found',
      'message', 'The join request was not found.'
    );
  end if;

  -- Only the activity host can accept or reject its requests.
  if selected_request.host_id <> current_user_id then
    return jsonb_build_object(
      'result', 'not_host',
      'message', 'Only the activity host can review this request.'
    );
  end if;

  -- Public activities do not use host approval.
  if selected_request.is_public then
    return jsonb_build_object(
      'result', 'invalid_request',
      'message', 'Public activities do not require host approval.'
    );
  end if;

  -- Prevent reviewing the same request more than once.
  if selected_request.status <> 'pending' then
    return jsonb_build_object(
      'result', 'already_reviewed',
      'status', selected_request.status,
      'message', 'This request has already been reviewed.'
    );
  end if;

  if not accept_request then
    -- Reject the private activity request.
    resulting_status := 'rejected';
  else
    -- The host counts as the first participant.
    select 1 + count(*)
    into joined_participants
    from public.activity_participants
    where activity_id = selected_request.activity_id
      and status = 'joined';

    if joined_participants >= selected_request.max_participants then
      -- If the activity became full, move the user to the waitlist.
      resulting_status := 'waitlisted';
    else
      resulting_status := 'joined';
    end if;
  end if;

  update public.activity_participants
  set
    status = resulting_status,
    updated_at = now()
  where id = participation_id;

  return jsonb_build_object(
    'result', resulting_status,
    'activity_id', selected_request.activity_id,
    'activity_title', selected_request.title,
    'message',
      case resulting_status
        when 'joined' then
          'The request was accepted.'
        when 'rejected' then
          'The request was rejected.'
        when 'waitlisted' then
          'The activity is full. The user was moved to the waitlist.'
      end
  );
end;
$$;

-- Prevent anonymous access to the request-review function.
revoke all
on function public.review_activity_join_request(uuid, boolean)
from public;

-- Allow signed-in users to call it.
-- The function itself verifies that the caller is the activity host.
grant execute
on function public.review_activity_join_request(uuid, boolean)
to authenticated;

-- Returns pending private activity requests for activities hosted by the
-- signed-in user.
create or replace function public.get_pending_activity_requests()
returns table (
  participation_id uuid,
  activity_id uuid,
  activity_title text,
  requester_id uuid,
  requester_name text,
  requester_username text,
  requested_at timestamptz
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    participant.id as participation_id,
    participant.activity_id,
    activity.title as activity_title,
    participant.user_id as requester_id,

    -- Use a fallback when the user's full name is missing.
    coalesce(
      nullif(trim(app_user.full_name), ''),
      'Synk user'
    ) as requester_name,

    app_user.username as requester_username,
    participant.created_at as requested_at

  from public.activity_participants participant

  join public.activities activity
    on activity.id = participant.activity_id

  left join public.users app_user
    on app_user.id = participant.user_id

  where activity.host_id = auth.uid()
    and activity.is_public = false
    and participant.status = 'pending'

  -- Show the oldest request first.
  order by participant.created_at asc;
$$;

-- Prevent anonymous users from reading private join requests.
revoke all
on function public.get_pending_activity_requests()
from public;

-- Allow signed-in users to request the list.
-- The function only returns activities hosted by the caller.
grant execute
on function public.get_pending_activity_requests()
to authenticated;