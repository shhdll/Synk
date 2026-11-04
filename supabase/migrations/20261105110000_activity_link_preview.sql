-- What synk.cc/activity.html shows about a shared activity, before the app
-- opens. Anyone with the link can call it, signed in or not, so it only
-- gives the basics: no host, members, address or coordinates.
--   * a public activity: by its id
--   * a private one: only with its code, which the shared link carries
--   * nothing once it has started
--
-- Safe to run again.

begin;

create or replace function public.get_activity_preview(
  target_activity_id uuid,
  entered_code text default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'title', a.title,
    'starts_at', a.starts_at,
    'location_name', a.location_name,
    'photo_url', a.photo_url,
    'category_label', a.category_label,
    'category_emoji', a.category_emoji,
    'max_participants', a.max_participants,
    -- The host counts as the first participant.
    'participants_count', 1 + (
      select count(*)
      from public.activity_participants ap
      where ap.activity_id = a.id
        and ap.status = 'joined'
    )
  )
  from public.activities a
  where a.id = target_activity_id
    and a.starts_at > now()
    and (
      a.is_public
      or (entered_code is not null and a.activity_code = entered_code)
    );
$$;

revoke all on function public.get_activity_preview(uuid, text) from public;
grant execute on function public.get_activity_preview(uuid, text) to anon, authenticated;

commit;
