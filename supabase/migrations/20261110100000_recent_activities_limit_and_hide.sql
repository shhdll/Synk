-- Recent activities on a profile:
--   * only the newest 12 are ever returned, to friends and to the user
--   * a user can hide any of their ended activities from it
--
-- Safe to run again.

begin;

create table if not exists public.hidden_recent_activities (
  user_id uuid not null references public.users (id) on delete cascade,
  activity_id uuid not null references public.activities (id)
    on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, activity_id)
);

alter table public.hidden_recent_activities enable row level security;

drop policy if exists hidden_recent_activities_own
  on public.hidden_recent_activities;
create policy hidden_recent_activities_own
  on public.hidden_recent_activities
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select, insert, delete on public.hidden_recent_activities
  to authenticated;

-- Same as 20261104170000_block_activities.sql, plus the cap and hidden rows.
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
  max_shown constant integer := 12;
  current_user_id uuid := auth.uid();
  page_offset integer := greatest(coalesce(p_offset, 0), 0);
  page_size integer := least(
    greatest(coalesce(p_limit, 10), 1),
    max_shown - page_offset
  );
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

  if page_size <= 0 then
    return jsonb_build_object(
      'allowed', true,
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
      and not exists (
        select 1
        from public.hidden_recent_activities as hidden
        where hidden.user_id = target_user_id
          and hidden.activity_id = activity.id
      )
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
      and page_offset + page_size < max_shown
  );
end;
$$;

commit;
