-- Blocking across activities and profiles.
--
-- A block applies both ways for visibility and interaction, whoever made it:
--   * activities hosted by either person are hidden from the other, and
--     neither can join the other's activities ("This activity is unavailable.");
--   * in an activity hosted by someone else, both stay in it and in the
--     count. The person who blocked sees the other marked as blocked; the
--     person who was blocked sees an anonymous participant, and the server
--     never sends them the blocker's name, username, photo or id. Neither
--     gets the other's real photo, only the default avatar for their gender;
--   * the blocker's profile row is not readable by the person they blocked.
-- Group chats get the same treatment in 20261104180000_block_chats.sql.
-- Participation rows are never deleted, so unblocking restores everything.
--
-- Safe to run again (replaces an earlier version of this file).

begin;

-- ---- Helpers ------------------------------------------------------------------
-- In a schema the API does not expose, so RLS policies can call them but
-- the app cannot ask "did this person block me?" directly. Both build on
-- public.users_blocked_either_way from 20261030150000_activity_ratings.sql.

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

-- A block between the signed-in user and other_user_id, either direction.
create or replace function private.has_block_with(other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.users_blocked_either_way(auth.uid(), other_user_id);
$$;

-- Only the direction where other_user_id blocked the signed-in user.
create or replace function private.blocked_me(other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_blocks b
    where b.blocker_id = other_user_id and b.blocked_id = auth.uid()
  );
$$;

-- The only part of gender used for a restricted user: which default avatar.
create or replace function private.avatar_gender(raw_gender text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case lower(trim(coalesce(raw_gender, '')))
    when 'female' then 'female'
    when 'male' then 'male'
  end;
$$;

revoke all on function private.has_block_with(uuid) from public, anon;
revoke all on function private.blocked_me(uuid) from public, anon;
grant execute on function private.has_block_with(uuid) to authenticated;
grant execute on function private.blocked_me(uuid) to authenticated;
revoke all on function private.avatar_gender(text) from public, anon;
grant execute on function private.avatar_gender(text) to authenticated;

-- The earlier version of this file used a public helper, callable from the
-- app. Its policy goes first, since it depends on it.
drop policy if exists "Hide activities between blocked users" on public.activities;
drop function if exists public.has_block_with(uuid);

-- ---- 1. Hide hosted activities --------------------------------------------------

-- Restrictive, so it applies on top of every existing select policy: Map,
-- lists and any direct read.
create policy "Hide activities between blocked users"
  on public.activities
  as restrictive
  for select
  to authenticated
  using (host_id = auth.uid() or not private.has_block_with(host_id));

-- Functions below read as their owner, so each needs the same rule.

-- Home feed. Otherwise unchanged from 20261021220000_same_gender_discovery_feed.sql.
create or replace function public.get_discovery_feed(p_limit integer default 60)
returns setof jsonb
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    to_jsonb(a) || jsonb_build_object(
      'host_name', h.full_name,
      'host_username', h.username,
      'host_avatar_url', h.avatar_url,
      'host_gender', h.gender,
      -- The host counts as the first participant.
      'participants_count', 1 + (
        select count(*)
        from public.activity_participants ap
        where ap.activity_id = a.id
          and ap.status = 'joined'
      )
    )
  from public.activities a
  join public.users h on h.id = a.host_id
  join public.users v on v.id = auth.uid()
  where a.is_public = true
    and a.starts_at > now()
    and a.host_id is distinct from auth.uid()
    and coalesce(lower(trim(h.gender)), '') <> ''
    and lower(trim(h.gender)) = lower(trim(v.gender))
    and not public.users_blocked_either_way(auth.uid(), a.host_id)
  order by a.starts_at asc
  limit least(greatest(coalesce(p_limit, 60), 1), 200);
$$;

revoke execute on function public.get_discovery_feed(integer) from anon, public;
grant execute on function public.get_discovery_feed(integer) to authenticated;

-- The user's own joined, pending and waitlisted activities. The rows stay;
-- a blocked host's activity just isn't listed. Otherwise unchanged from
-- 20261018000100_participants_see_activity_code.sql.
create or replace function public.get_my_activity_participations()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    jsonb_agg(
      to_jsonb(activity)
      ||
      jsonb_build_object(
        'participation_id',
        participation.id,
        'participation_status',
        participation.status,
        -- host counts as one
        'participants_count',
        1 + (
          select count(*)
          from public.activity_participants as member
          where member.activity_id = activity.id
            and member.status = 'joined'
        )
      )
      order by activity.starts_at
    ),
    '[]'::jsonb
  )
  from public.activity_participants as participation
  join public.activities as activity
    on activity.id = participation.activity_id
  where participation.user_id = auth.uid()
    and participation.status in (
      'joined',
      'pending',
      'waitlisted'
    )
    and not public.users_blocked_either_way(auth.uid(), activity.host_id);
$$;

-- Code preview before joining: a blocked host's activity looks like an
-- unknown code. Otherwise unchanged from 20261022100000_resolve_activity_code.sql.
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
      or public.users_blocked_either_way(auth.uid(), selected_activity.host_id) then
    return jsonb_build_object('found', false);
  end if;
  return jsonb_build_object(
    'found', true,
    'activity', to_jsonb(selected_activity) - 'activity_code'
  );
end;
$$;

-- Activities shared in chat. Otherwise unchanged from
-- 20261030140000_share_activities_and_locations.sql.
create or replace function public.can_see_activity(target_activity_id uuid, viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.activities a
    left join public.users h on h.id = a.host_id
    left join public.users v on v.id = viewer
    where a.id = target_activity_id
      and (
        a.host_id = viewer
        or not public.users_blocked_either_way(viewer, a.host_id)
      )
      and (
        a.host_id = viewer
        or exists (
          select 1 from public.activity_participants ap
          where ap.activity_id = a.id
            and ap.user_id = viewer
            and ap.status in ('joined', 'waitlisted')
        )
        or (
          a.is_public
          and coalesce(lower(trim(h.gender)), '') <> ''
          and lower(trim(h.gender)) = lower(trim(v.gender))
        )
      )
  );
$$;

-- A friend's past activities on their profile: also leave out ones hosted
-- by someone the viewer is blocked with. Otherwise unchanged from
-- 20261030151000_user_recent_activities.sql.
create or replace function public.get_user_recent_activities(
  target_user_id uuid,
  p_limit integer default 10,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  page_size integer := least(greatest(coalesce(p_limit, 10), 1), 50);
  page_offset integer := greatest(coalesce(p_offset, 0), 0);
  viewer_gender text;
  page jsonb;
  fetched_count integer;
begin
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  if target_user_id is null then
    return jsonb_build_object(
      'allowed', false,
      'activities', '[]'::jsonb,
      'has_more', false
    );
  end if;

  if current_user_id <> target_user_id and (
    not exists (
      select 1
      from public.friendships as friendship
      where friendship.user_a = least(current_user_id, target_user_id)
        and friendship.user_b = greatest(current_user_id, target_user_id)
    )
    or public.users_blocked_either_way(current_user_id, target_user_id)
  ) then
    return jsonb_build_object(
      'allowed', false,
      'activities', '[]'::jsonb,
      'has_more', false
    );
  end if;

  select nullif(trim(profile.gender), '')
  into viewer_gender
  from public.users as profile
  where profile.id = current_user_id;

  -- One extra row tells the app whether another page exists.
  select
    coalesce(jsonb_agg(visible.item order by visible.starts_at desc,
      visible.id), '[]'::jsonb),
    count(*)
  into page, fetched_count
  from (
    select
      activity.id,
      activity.starts_at,
      jsonb_build_object(
        'id', activity.id,
        'host_id', activity.host_id,
        'title', activity.title,
        'starts_at', activity.starts_at,
        'ends_at', activity.ends_at,
        'is_public', activity.is_public,
        'photo_url', activity.photo_url,
        'category_emoji', activity.category_emoji,
        'category_label', activity.category_label
      ) as item
    from public.activities as activity
    left join public.users as host on host.id = activity.host_id
    where activity.ends_at <= now()
      and public.is_activity_attendee(activity.id, target_user_id)
      and not public.users_blocked_either_way(current_user_id, activity.host_id)
      and (
        public.is_activity_attendee(activity.id, current_user_id)
        or (
          activity.is_public
          and viewer_gender is not null
          and nullif(trim(host.gender), '') = viewer_gender
        )
      )
    order by activity.starts_at desc, activity.id
    limit page_size + 1
    offset page_offset
  ) as visible;

  if fetched_count > page_size then
    page := page - page_size;
  end if;

  return jsonb_build_object(
    'allowed', true,
    'activities', page,
    'has_more', fetched_count > page_size
  );
end;
$$;

-- ---- 2. No joins between blocked users ----------------------------------------

-- Join by code; public joins pass through here too (join_public_activity).
-- The block check comes before anything about the activity is returned, and
-- the answer is the same whoever made the block. Otherwise unchanged from
-- 20261021150000_activity_interval_conflicts.sql.
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

revoke all on function public.join_activity_by_code(text) from public;
grant execute on function public.join_activity_by_code(text) to authenticated;

-- Safety net on the table, for any other way a row could be added (a later
-- join function, a host approving an old request). Same generic message.
create or replace function public.prevent_blocked_activity_join()
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
      and public.users_blocked_either_way(new.user_id, a.host_id)
  ) then
    raise exception 'This activity is unavailable.';
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_blocked_activity_join() from public, anon, authenticated;

drop trigger if exists prevent_blocked_activity_join on public.activity_participants;
create trigger prevent_blocked_activity_join
  before insert on public.activity_participants
  for each row
  execute function public.prevent_blocked_activity_join();

-- ---- 3. Blocked people in someone else's activity -------------------------------

-- Every joined participant is still returned, so the count stays right.
--   is_hidden:     they blocked the viewer. Id, name, username and photo
--                  are left out, so nothing identifies them.
--   blocked_by_me: the viewer blocked them; real name, marked as blocked.
-- Either way the real photo is never sent: gender comes back only as
-- 'female', 'male' or null, for the matching default avatar.
-- When both blocked each other, is_hidden wins and blocked_by_me is false.
-- Two new columns, so the function is dropped and made again. Otherwise the
-- same rules as 20261014100100_participants_list_authorization.sql.
drop function if exists public.get_activity_participants_list(uuid);

create function public.get_activity_participants_list(
  p_activity_id uuid
)
returns table (
  user_id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text,
  status text,
  is_hidden boolean,
  blocked_by_me boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    case when x.hidden then null else u.id end as user_id,
    case when x.hidden then null
      else coalesce(nullif(trim(u.full_name), ''), 'Synk member') end as full_name,
    case when x.hidden then null else u.username end as username,
    case when x.hidden or x.blocked_by_me then null else u.avatar_url end as avatar_url,
    case when x.hidden or x.blocked_by_me then private.avatar_gender(u.gender)
      else u.gender end as gender,
    ap.status,
    x.hidden as is_hidden,
    x.blocked_by_me and not x.hidden as blocked_by_me
  from public.activity_participants ap
  join public.users u
    on u.id = ap.user_id
  cross join lateral (
    select
      exists (
        select 1 from public.user_blocks b
        where b.blocker_id = u.id and b.blocked_id = auth.uid()
      ) as hidden,
      exists (
        select 1 from public.user_blocks b
        where b.blocker_id = auth.uid() and b.blocked_id = u.id
      ) as blocked_by_me
  ) x
  where ap.activity_id = p_activity_id
    and ap.status = 'joined'
    and auth.uid() is not null
    and exists (
      select 1
      from public.activities a
      where a.id = p_activity_id
        and (
          a.is_public
          or a.host_id = auth.uid()
          or exists (
            select 1
            from public.activity_participants viewer
            where viewer.activity_id = a.id
              and viewer.user_id = auth.uid()
              and viewer.status in ('joined', 'waitlisted')
          )
        )
    )
  order by ap.created_at asc;
$$;

revoke all on function public.get_activity_participants_list(uuid) from public;
revoke all on function public.get_activity_participants_list(uuid) from anon;
grant execute on function public.get_activity_participants_list(uuid) to authenticated;

-- ---- 4. Profiles ------------------------------------------------------------------

-- The person who was blocked can't read the blocker's profile row, from any
-- screen, old link or notification. The blocker can still read theirs, for
-- the blocked list and the Unblock button.
drop policy if exists "Hide profiles from users they blocked" on public.users;
create policy "Hide profiles from users they blocked"
  on public.users
  as restrictive
  for select
  to authenticated
  using (id = auth.uid() or not private.blocked_me(id));

commit;
