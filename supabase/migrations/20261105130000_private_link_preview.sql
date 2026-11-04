-- A private activity's link page only shows its title and photo.
-- Otherwise unchanged from 20261105110000_activity_link_preview.sql.

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
  select case
    when a.is_public then jsonb_build_object(
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
    else jsonb_build_object(
      'title', a.title,
      'photo_url', a.photo_url,
      'category_emoji', a.category_emoji
    )
  end
  from public.activities a
  where a.id = target_activity_id
    and a.starts_at > now()
    and (
      a.is_public
      or (entered_code is not null and a.activity_code = entered_code)
    );
$$;

commit;
