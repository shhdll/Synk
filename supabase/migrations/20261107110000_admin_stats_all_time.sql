-- Admin overview: an "all time" period, and categories counted the way the
-- app shows them. Most activities don't store a category, so the app
-- matches keywords in the title and description
-- (lib/core/constants/activity_categories.dart). This copies that list;
-- keep the two in step.

begin;

create or replace function private.activity_category(
  p_label text,
  p_title text,
  p_description text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    nullif(btrim(p_label), ''),
    (
      select c.name
      from (values
        (1, 'Padel', array['padel']),
        (2, 'Tennis', array['tennis', 'squash']),
        (3, 'Badminton', array['badminton']),
        (4, 'Table Tennis', array['table tennis', 'ping pong']),
        (5, 'Football', array['football', 'soccer', 'futsal']),
        (6, 'Basketball', array['basketball']),
        (7, 'Volleyball', array['volleyball']),
        (8, 'Golf', array['golf']),
        (9, 'Bowling', array['bowling']),
        (10, 'Karting', array['karting', 'kart', 'drift', 'car meet']),
        (11, 'Martial Arts', array['martial art', 'boxing', 'kickboxing', 'mma', 'karate', 'taekwondo', 'jiu jitsu', 'bjj', 'muay thai', 'judo']),
        (12, 'Paintball', array['paintball', 'laser tag', 'archery', 'axe throwing']),
        (13, 'Cycling', array['cycling', 'bike', 'biking']),
        (14, 'Running', array['run', 'jog', 'marathon']),
        (15, 'Hiking', array['hike', 'hiking', 'trail', 'walk']),
        (16, 'Climbing', array['climb', 'bouldering']),
        (17, 'Camping', array['camp']),
        (18, 'Desert Trips', array['desert', 'dune', 'safari', 'sandboard', 'stargaz']),
        (19, 'Picnic', array['picnic', 'park', 'bbq', 'barbecue', 'grill']),
        (20, 'Fitness', array['gym', 'workout', 'fitness', 'crossfit', 'training']),
        (21, 'Yoga', array['yoga', 'pilates', 'meditation', 'stretch']),
        (22, 'Swimming', array['swim']),
        (23, 'Diving', array['dive', 'diving', 'snorkel', 'scuba']),
        (24, 'Skating', array['skate', 'skating', 'skateboard']),
        (25, 'Dance', array['dance', 'dancing', 'zumba']),
        (26, 'Coffee', array['coffee', 'cafe', 'café', 'chat', 'karak', 'matcha']),
        (27, 'Cooking', array['cook', 'baking']),
        (28, 'Food', array['dinner', 'brunch', 'lunch', 'breakfast', 'food', 'pizza', 'burger', 'sushi', 'restaurant', 'dessert', 'ice cream']),
        (29, 'Board Games', array['board game', 'cards', 'puzzle']),
        (30, 'Chess', array['chess']),
        (31, 'Escape Room', array['escape room']),
        (32, 'Trivia', array['trivia', 'quiz']),
        (33, 'Gaming', array['gaming', 'video game', 'playstation', 'fifa']),
        (34, 'Movies', array['movie', 'cinema', 'film']),
        (35, 'Comedy', array['comedy', 'stand up', 'theater', 'theatre']),
        (36, 'Karaoke', array['karaoke', 'sing']),
        (37, 'Music', array['music', 'concert']),
        (38, 'Art', array['art', 'paint', 'draw', 'craft']),
        (39, 'Pottery', array['pottery', 'ceramic']),
        (40, 'Museums', array['museum', 'exhibition', 'gallery']),
        (41, 'Books', array['book', 'reading']),
        (42, 'Photography', array['photo']),
        (43, 'Learning', array['study', 'coding', 'hackathon', 'workshop', 'language']),
        (44, 'Volunteering', array['volunteer', 'charity']),
        (45, 'Shopping', array['shopping', 'mall'])
      ) as c(ord, name, keywords)
      where exists (
        select 1 from unnest(c.keywords) as k
        where lower(coalesce(p_title, '') || ' ' || coalesce(p_description, '')) ~ ('\m' || k)
      )
      order by c.ord
      limit 1
    ),
    'Other'
  );
$$;

revoke all on function private.activity_category(text, text, text)
  from public, anon, authenticated;

-- p_days null means all time. Long periods are counted per week.
drop function if exists public.admin_stats(integer);

create or replace function public.admin_stats(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  today date := (now() at time zone 'Asia/Riyadh')::date;
  first_day date;
  days integer;
  weekly boolean;
begin
  perform private.require_admin();

  if p_days is null then
    select least(
      (select min(created_at) from public.users),
      (select min(created_at) from public.activities)
    ) at time zone 'Asia/Riyadh'
    into first_day;
    first_day := coalesce(first_day, today);
  else
    first_day := today - (least(greatest(p_days, 7), 366) - 1);
  end if;
  days := today - first_day + 1;
  weekly := days > 120;

  return jsonb_build_object(
    'days', case when p_days is null then null else days end,
    'bucket', case when weekly then 'week' else 'day' end,
    'users', (select count(*) from public.users),
    'users_in_period', (select count(*) from public.users
      where (created_at at time zone 'Asia/Riyadh')::date >= first_day),
    'signed_in_in_period', (select count(*) from auth.users
      where (last_sign_in_at at time zone 'Asia/Riyadh')::date >= first_day),
    'suspended', (select count(*) from private.user_suspensions),
    'activities', (select count(*) from public.activities),
    'activities_in_period', (select count(*) from public.activities
      where (created_at at time zone 'Asia/Riyadh')::date >= first_day),
    'upcoming_activities', (select count(*) from public.activities where starts_at > now()),
    'joins_in_period', (select count(*) from public.activity_participants
      where status = 'joined'
        and (created_at at time zone 'Asia/Riyadh')::date >= first_day),
    'open_tickets', (select count(*) from public.support_tickets where status = 'open'),
    'open_reports',
      (select count(*) from public.user_reports where status in ('open', 'reviewing'))
      + (select count(*) from public.activity_reports where status in ('open', 'reviewing')),
    'daily', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'day', b.day,
        'users', (select count(*) from public.users u
          where (u.created_at at time zone 'Asia/Riyadh')::date >= b.day
            and (u.created_at at time zone 'Asia/Riyadh')::date < b.next_day),
        'activities', (select count(*) from public.activities a
          where (a.created_at at time zone 'Asia/Riyadh')::date >= b.day
            and (a.created_at at time zone 'Asia/Riyadh')::date < b.next_day)
      ) order by b.day), '[]'::jsonb)
      from (
        select s::date as day,
          (s + case when weekly then interval '7 days' else interval '1 day' end)::date as next_day
        from generate_series(first_day::timestamp, today::timestamp,
          case when weekly then interval '7 days' else interval '1 day' end) s
      ) b
    ),
    'categories', (
      select coalesce(jsonb_agg(c order by c.count desc, c.label), '[]'::jsonb)
      from (
        select private.activity_category(category_label, title, description) as label,
          count(*) as count
        from public.activities
        where (created_at at time zone 'Asia/Riyadh')::date >= first_day
        group by 1
        order by 2 desc, 1
        limit 10
      ) c
    )
  );
end;
$$;

revoke all on function public.admin_stats(integer) from public, anon;
grant execute on function public.admin_stats(integer) to authenticated;

commit;
