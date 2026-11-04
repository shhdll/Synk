-- Ratings can be seen and changed from a past activity.
--
--   * get_activity_rating: an ended activity the user was in, with everyone
--     they can rate and the stars they gave each one before (my_halves,
--     null if not rated yet)
--   * submit_activity_ratings replaces an earlier rating instead of
--     refusing it, and the user's average follows the change
--
-- Safe to run again.

begin;

-- Otherwise unchanged from 20261030150000_activity_ratings.sql.
create or replace function public.submit_activity_ratings(
  requested_activity_id uuid,
  ratings jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_activity public.activities%rowtype;
  item jsonb;
  recipient_id uuid;
  stars numeric;
  saved_count integer;
begin
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  select *
  into selected_activity
  from public.activities
  where id = requested_activity_id
  for share;

  if not found then
    return jsonb_build_object('result', 'not_found');
  end if;

  if selected_activity.ends_at > now() then
    return jsonb_build_object('result', 'not_ended');
  end if;

  if not public.is_activity_attendee(selected_activity.id, current_user_id) then
    return jsonb_build_object('result', 'not_eligible');
  end if;

  if ratings is null
    or jsonb_typeof(ratings) <> 'array'
    or jsonb_array_length(ratings) = 0
    or jsonb_array_length(ratings) > 50 then
    return jsonb_build_object('result', 'invalid_rating');
  end if;

  -- Validate every rating before saving any.
  for item in select value from jsonb_array_elements(ratings)
  loop
    begin
      recipient_id := (item ->> 'user_id')::uuid;
      stars := (item ->> 'stars')::numeric;
    exception when others then
      return jsonb_build_object('result', 'invalid_rating');
    end;

    if recipient_id is null
      or stars is null
      or stars < 0.5
      or stars > 5
      or stars * 2 <> trunc(stars * 2) then
      return jsonb_build_object('result', 'invalid_rating');
    end if;

    if recipient_id = current_user_id
      or not public.is_activity_attendee(selected_activity.id, recipient_id)
      or public.users_blocked_either_way(current_user_id, recipient_id) then
      return jsonb_build_object('result', 'not_eligible');
    end if;
  end loop;

  if (
    select count(distinct value ->> 'user_id')
    from jsonb_array_elements(ratings)
  ) <> jsonb_array_length(ratings) then
    return jsonb_build_object('result', 'invalid_rating');
  end if;

  insert into public.activity_ratings (
    activity_id,
    rater_id,
    rated_user_id,
    score_halves
  )
  select
    selected_activity.id,
    current_user_id,
    (entry.value ->> 'user_id')::uuid,
    ((entry.value ->> 'stars')::numeric * 2)::smallint
  from jsonb_array_elements(ratings) as entry
  on conflict (activity_id, rater_id, rated_user_id)
  do update set score_halves = excluded.score_halves;

  get diagnostics saved_count = row_count;

  -- Unrated attendees stay in the prompt until rated or skipped.
  return jsonb_build_object('result', 'rated', 'count', saved_count);
end;
$$;

-- The average also follows a changed rating.
drop trigger if exists activity_ratings_refresh_user_rating
  on public.activity_ratings;
create trigger activity_ratings_refresh_user_rating
after insert or update or delete on public.activity_ratings
for each row
execute function public.refresh_user_rating();

-- Same shape as an entry of get_pending_activity_ratings, but with every
-- attendee and the viewer's earlier stars.
create or replace function public.get_activity_rating(
  requested_activity_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', activity.id,
    'title', activity.title,
    'starts_at', activity.starts_at,
    'ends_at', activity.ends_at,
    'is_public', activity.is_public,
    'host_id', activity.host_id,
    'photo_url', activity.photo_url,
    'category_emoji', activity.category_emoji,
    'category_label', activity.category_label,
    'participants', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'user_id', profile.id,
          'full_name', profile.full_name,
          'username', profile.username,
          'avatar_url', profile.avatar_url,
          'gender', profile.gender,
          'is_host', attendee.user_id = activity.host_id,
          'my_halves', rating.score_halves
        )
        order by attendee.user_id = activity.host_id desc, profile.full_name
      )
      from (
        select activity.host_id as user_id
        union
        select participant.user_id
        from public.activity_participants as participant
        where participant.activity_id = activity.id
          and participant.status = 'joined'
      ) as attendee
      join public.users as profile on profile.id = attendee.user_id
      left join public.activity_ratings as rating
        on rating.activity_id = activity.id
       and rating.rater_id = auth.uid()
       and rating.rated_user_id = attendee.user_id
      where attendee.user_id <> auth.uid()
        and not public.users_blocked_either_way(auth.uid(), attendee.user_id)
    ), '[]'::jsonb)
  )
  from public.activities as activity
  where activity.id = requested_activity_id
    and activity.ends_at <= now()
    and public.is_activity_attendee(activity.id, auth.uid());
$$;

revoke all on function public.get_activity_rating(uuid) from public, anon;
grant execute on function public.get_activity_rating(uuid) to authenticated;

commit;
