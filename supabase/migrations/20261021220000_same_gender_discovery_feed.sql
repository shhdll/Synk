-- Home discovery feed: same-gender visibility.
-- Activities are only returned to viewers whose profile gender matches the
-- host's gender: activities hosted by men are shown to men only, and
-- activities hosted by women are shown to women only.
-- Hosts or viewers without a gender on their profile see / are seen by no one.
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
  order by a.starts_at asc
  limit least(greatest(coalesce(p_limit, 60), 1), 200);
$$;

revoke execute on function public.get_discovery_feed(integer) from anon, public;
grant execute on function public.get_discovery_feed(integer) to authenticated;
