-- ==============================================================================
-- Migration: Activity Discovery and Public Participants
-- ==============================================================================

-- 1. Allow authenticated users to view joined participants for public activities
do $$
begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'activity_participants'
      and policyname = 'Authenticated users can view participants of public activities'
  ) then
    create policy "Authenticated users can view participants of public activities"
    on public.activity_participants
    for select
    to authenticated
    using (
      status = 'joined'
      and exists (
        select 1 from public.activities
        where activities.id = activity_participants.activity_id
          and activities.is_public = true
      )
    );
  end if;
end $$;

-- 2. Returns the joined participants list for an activity with host & user profiles
create or replace function public.get_activity_participants_list(p_activity_id uuid)
returns table (
  user_id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text,
  status text
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    u.id as user_id,
    coalesce(nullif(trim(u.full_name), ''), 'Synk member') as full_name,
    u.username,
    u.avatar_url,
    u.gender,
    ap.status
  from public.activity_participants ap
  join public.users u on u.id = ap.user_id
  where ap.activity_id = p_activity_id
    and ap.status = 'joined'
  order by ap.created_at asc;
$$;

-- Grant execution to authenticated users
grant execute on function public.get_activity_participants_list(uuid) to authenticated;

-- 3. Home discovery feed.
-- Upcoming public activities hosted by other users, with host profile and
-- joined count. Activities hosted by female users are only returned to
-- viewers whose profile gender is 'Female'.
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
  left join public.users h on h.id = a.host_id
  where auth.uid() is not null
    and a.is_public = true
    and a.starts_at > now()
    and a.host_id is distinct from auth.uid()
    and (
      coalesce(lower(trim(h.gender)), '') <> 'female'
      or exists (
        select 1 from public.users v
        where v.id = auth.uid()
          and lower(trim(v.gender)) = 'female'
      )
    )
  order by a.starts_at asc
  limit least(greatest(coalesce(p_limit, 60), 1), 200);
$$;

revoke execute on function public.get_discovery_feed(integer) from anon, public;
grant execute on function public.get_discovery_feed(integer) to authenticated;
