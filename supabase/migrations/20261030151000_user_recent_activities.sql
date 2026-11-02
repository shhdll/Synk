-- A user's ended activities (hosted or joined), for their profile.
-- Visible to the user and to their friends, never across a block.
-- A friend sees a public activity only under the discovery feed's
-- same-gender rule, and a private one only if they attended it too.
-- Locations and activity codes are never returned.

begin;

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

revoke all on function public.get_user_recent_activities(uuid, integer, integer)
  from public, anon;
grant execute
on function public.get_user_recent_activities(uuid, integer, integer)
  to authenticated;

commit;
