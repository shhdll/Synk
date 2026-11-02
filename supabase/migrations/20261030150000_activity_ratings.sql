-- Star ratings between people who attended the same activity.
-- Attendees are the host and joined participants. Ratings are optional,
-- final, 0.5 to 5 stars in half steps, and allowed only after the activity
-- has ended. Each user's average across all ratings received is kept on
-- public.users so existing profile screens can show it.

begin;

-- Server-maintained rating summary; null until the first rating.
alter table public.users
  add column if not exists rating numeric(3,2),
  add column if not exists rating_count integer not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'users_rating_range'
      and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
      add constraint users_rating_range
      check (rating is null or rating between 0.5 and 5);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'users_rating_count_not_negative'
      and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
      add constraint users_rating_count_not_negative
      check (rating_count >= 0);
  end if;
end;
$$;

-- App users cannot set their own rating; only server functions can.
create or replace function public.protect_user_rating()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user not in ('authenticated', 'anon') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.rating := null;
    new.rating_count := 0;
  elsif new.rating is distinct from old.rating
    or new.rating_count is distinct from old.rating_count then
    raise exception 'Ratings are calculated by the server.'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists users_protect_rating on public.users;
create trigger users_protect_rating
before insert or update on public.users
for each row
execute function public.protect_user_rating();

create table if not exists public.activity_ratings (
  id uuid primary key default gen_random_uuid(),
  activity_id uuid not null
    references public.activities (id) on delete cascade,
  rater_id uuid not null references public.users (id) on delete cascade,
  rated_user_id uuid not null references public.users (id) on delete cascade,
  -- Half stars: 1 = 0.5 stars, 10 = 5 stars.
  score_halves smallint not null,
  created_at timestamptz not null default now(),
  constraint activity_ratings_score_range
    check (score_halves between 1 and 10),
  constraint activity_ratings_not_self check (rater_id <> rated_user_id),
  constraint activity_ratings_unique
    unique (activity_id, rater_id, rated_user_id)
);

create index if not exists activity_ratings_rated_user_idx
  on public.activity_ratings (rated_user_id);

alter table public.activity_ratings enable row level security;

revoke all on table public.activity_ratings from public, anon, authenticated;
grant select on table public.activity_ratings to authenticated;

-- Raters see their own ratings; recipients never see who rated them.
drop policy if exists "Users can read ratings they gave"
  on public.activity_ratings;
create policy "Users can read ratings they gave"
on public.activity_ratings
for select
to authenticated
using (rater_id = (select auth.uid()));

-- A skipped rating prompt, so it is not offered again on any device.
create table if not exists public.activity_rating_dismissals (
  user_id uuid not null references public.users (id) on delete cascade,
  activity_id uuid not null
    references public.activities (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, activity_id)
);

alter table public.activity_rating_dismissals enable row level security;

revoke all on table public.activity_rating_dismissals
  from public, anon, authenticated;

-- The host and joined participants attended the activity.
create or replace function public.is_activity_attendee(
  target_activity_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.activities as activity
    where activity.id = target_activity_id
      and activity.host_id = target_user_id
  )
  or exists (
    select 1
    from public.activity_participants as participant
    where participant.activity_id = target_activity_id
      and participant.user_id = target_user_id
      and participant.status = 'joined'
  );
$$;

create or replace function public.users_blocked_either_way(
  first_user_id uuid,
  second_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_blocks as block
    where (block.blocker_id = first_user_id
        and block.blocked_id = second_user_id)
      or (block.blocker_id = second_user_id
        and block.blocked_id = first_user_id)
  );
$$;

revoke all on function public.is_activity_attendee(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.users_blocked_either_way(uuid, uuid)
  from public, anon, authenticated;

-- Keeps the recipient's average and count in step with their ratings.
create or replace function public.refresh_user_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_user_id uuid := coalesce(new.rated_user_id, old.rated_user_id);
begin
  update public.users as profile
  set
    rating = summary.average_rating,
    rating_count = summary.rating_count
  from (
    select
      round(avg(rating.score_halves) / 2.0, 2) as average_rating,
      count(*)::integer as rating_count
    from public.activity_ratings as rating
    where rating.rated_user_id = target_user_id
  ) as summary
  where profile.id = target_user_id;

  return null;
end;
$$;

revoke all on function public.refresh_user_rating()
  from public, anon, authenticated;

drop trigger if exists activity_ratings_refresh_user_rating
  on public.activity_ratings;
create trigger activity_ratings_refresh_user_rating
after insert or delete on public.activity_ratings
for each row
execute function public.refresh_user_rating();

-- Saves one or more ratings for an ended activity, all or nothing.
-- ratings: [{"user_id": "<uuid>", "stars": 4.5}, ...]
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

  if exists (
    select 1
    from public.activity_ratings as rating
    join jsonb_array_elements(ratings) as entry
      on (entry.value ->> 'user_id')::uuid = rating.rated_user_id
    where rating.activity_id = selected_activity.id
      and rating.rater_id = current_user_id
  ) then
    return jsonb_build_object('result', 'already_rated');
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
  from jsonb_array_elements(ratings) as entry;

  get diagnostics saved_count = row_count;

  -- Unrated attendees stay in the prompt until rated or skipped.
  return jsonb_build_object('result', 'rated', 'count', saved_count);
exception
  when unique_violation then
    return jsonb_build_object('result', 'already_rated');
end;
$$;

-- Skips the rating prompt for an activity.
create or replace function public.dismiss_activity_rating(
  requested_activity_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'You must be signed in.';
  end if;

  if not public.is_activity_attendee(requested_activity_id, current_user_id) then
    return jsonb_build_object('result', 'not_eligible');
  end if;

  insert into public.activity_rating_dismissals (user_id, activity_id)
  values (current_user_id, requested_activity_id)
  on conflict do nothing;

  return jsonb_build_object('result', 'dismissed');
end;
$$;

-- Activities that ended in the last 14 days which the viewer can still rate,
-- each with the attendees the viewer has not rated yet. An activity drops
-- out once everyone is rated or the viewer skips it.
create or replace function public.get_pending_activity_ratings()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with mine as (
    select activity.*
    from public.activities as activity
    where activity.ends_at <= now()
      and activity.ends_at > now() - interval '14 days'
      and public.is_activity_attendee(activity.id, auth.uid())
      and not exists (
        select 1
        from public.activity_rating_dismissals as dismissal
        where dismissal.user_id = auth.uid()
          and dismissal.activity_id = activity.id
      )
  ),
  candidates as (
    select
      mine.id as activity_id,
      attendee.user_id,
      attendee.user_id = mine.host_id as is_host
    from mine
    cross join lateral (
      select mine.host_id as user_id
      union
      select participant.user_id
      from public.activity_participants as participant
      where participant.activity_id = mine.id
        and participant.status = 'joined'
    ) as attendee
    where attendee.user_id is not null
      and attendee.user_id <> auth.uid()
      and not public.users_blocked_either_way(auth.uid(), attendee.user_id)
      and not exists (
        select 1
        from public.activity_ratings as rating
        where rating.activity_id = mine.id
          and rating.rater_id = auth.uid()
          and rating.rated_user_id = attendee.user_id
      )
  )
  select coalesce(
    jsonb_agg(entry.activity order by entry.ends_at desc),
    '[]'::jsonb
  )
  from (
    select
      mine.ends_at,
      jsonb_build_object(
        'id', mine.id,
        'title', mine.title,
        'starts_at', mine.starts_at,
        'ends_at', mine.ends_at,
        'is_public', mine.is_public,
        'host_id', mine.host_id,
        'photo_url', mine.photo_url,
        'category_emoji', mine.category_emoji,
        'category_label', mine.category_label,
        'participants', (
          select jsonb_agg(
            jsonb_build_object(
              'user_id', profile.id,
              'full_name', profile.full_name,
              'username', profile.username,
              'avatar_url', profile.avatar_url,
              'gender', profile.gender,
              'is_host', candidate.is_host
            )
            order by candidate.is_host desc, profile.full_name
          )
          from candidates as candidate
          join public.users as profile on profile.id = candidate.user_id
          where candidate.activity_id = mine.id
        )
      ) as activity
    from mine
    where exists (
      select 1 from candidates where candidates.activity_id = mine.id
    )
    order by mine.ends_at desc
    limit 10
  ) as entry;
$$;

revoke all on function public.submit_activity_ratings(uuid, jsonb)
  from public, anon;
revoke all on function public.dismiss_activity_rating(uuid)
  from public, anon;
revoke all on function public.get_pending_activity_ratings()
  from public, anon;

grant execute on function public.submit_activity_ratings(uuid, jsonb)
  to authenticated;
grant execute on function public.dismiss_activity_rating(uuid)
  to authenticated;
grant execute on function public.get_pending_activity_ratings()
  to authenticated;

commit;
