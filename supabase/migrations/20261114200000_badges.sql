-- Badges. The list and names live in the app (lib/core/constants/badges.dart);
-- here we only work out which ones a user has earned.
--
-- Attended means hosted or joined, and started, the same as the completed
-- count. Hosting only counts when someone else joined. Times are Riyadh time.
-- Categories come from private.activity_category, like the admin dashboard.
--
-- Badges are given by triggers on friendships and ratings, a cron job after
-- activities start, and get_my_badges when the app opens.
begin;

create table if not exists public.user_badges (
  user_id uuid not null references public.users (id) on delete cascade,
  badge_id text not null check (char_length(badge_id) between 1 and 64),
  earned_at timestamptz not null default now(),
  -- Null until the "you earned it" popup was shown.
  seen_at timestamptz,
  primary key (user_id, badge_id)
);

alter table public.user_badges enable row level security;
revoke all on table public.user_badges from public, anon, authenticated;

alter table public.notification_preferences
  add column if not exists badges boolean not null default true;

-- One push per batch of new badges. badge_id is the first one, badge_count
-- how many came together.
create table if not exists public.badge_earned_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  badge_id text not null,
  badge_count integer not null default 1,
  activity_title text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.badge_earned_notification_outbox enable row level security;
revoke all on public.badge_earned_notification_outbox
  from public, anon, authenticated;
grant select, update on public.badge_earned_notification_outbox to service_role;

-- Everything the badge rules need for one user.
create or replace function private.badge_stats(p_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with attended as (
    select a.id, a.host_id, a.max_participants,
      a.starts_at at time zone 'Asia/Riyadh' as local_start,
      private.activity_category(a.category_label, a.title, a.description) as category
    from public.activities as a
    where a.starts_at < now()
      and a.host_id = p_user
    union
    select a.id, a.host_id, a.max_participants,
      a.starts_at at time zone 'Asia/Riyadh',
      private.activity_category(a.category_label, a.title, a.description)
    from public.activities as a
    join public.activity_participants as p on p.activity_id = a.id
    where a.starts_at < now()
      and p.user_id = p_user
      and p.status = 'joined'
  ),
  others as (
    select at.id, count(p.user_id)::integer as joined
    from attended as at
    left join public.activity_participants as p
      on p.activity_id = at.id
     and p.status = 'joined'
     and p.user_id <> at.host_id
    group by at.id
  ),
  hosted as (
    select at.*, o.joined
    from attended as at
    join others as o on o.id = at.id
    where at.host_id = p_user
      and o.joined > 0
  ),
  categories as (
    select at.category, count(*)::integer as n
    from attended as at
    where at.category <> 'Other'
    group by at.category
  ),
  weeks as (
    select distinct div(at.local_start::date - date '1970-01-04', 7) as w
    from attended as at
  ),
  runs as (
    select count(*)::integer as length
    from (select w, w - row_number() over (order by w) as grp from weeks) as r
    group by r.grp
  ),
  received as (
    select count(*)::integer as n,
      coalesce(avg(r.score_halves) / 2.0, 0) as average,
      count(*) filter (where r.score_halves = 10)::integer as five_stars
    from public.activity_ratings as r
    where r.rated_user_id = p_user
  )
  select jsonb_build_object(
    'attended', (select count(*) from attended),
    'hosted', (select count(*) from hosted),
    'full_house', exists (
      select 1 from hosted as h
      where h.max_participants >= 4
        and 1 + h.joined >= h.max_participants
    ),
    'categories', (select count(*) from categories),
    'category_counts', coalesce(
      (select jsonb_object_agg(c.category, c.n) from categories as c),
      '{}'::jsonb
    ),
    'friends', (
      select count(*) from public.friendships as f
      where f.user_a = p_user or f.user_b = p_user
    ),
    'together', (
      select count(*) from attended as at
      where exists (
        select 1
        from (
          select at.host_id as person
          union all
          select p.user_id from public.activity_participants as p
          where p.activity_id = at.id and p.status = 'joined'
        ) as people
        join public.friendships as f
          on f.user_a = least(p_user, people.person)
         and f.user_b = greatest(p_user, people.person)
        where people.person <> p_user
      )
    ),
    'best_streak', coalesce((select max(length) from runs), 0),
    'rating_count', (select n from received),
    'rating_average', (select round(average, 2) from received),
    'five_stars', (select five_stars from received),
    'rated_activities', (
      select count(distinct r.activity_id) from public.activity_ratings as r
      where r.rater_id = p_user
    ),
    'early_bird', exists (
      select 1 from attended as at
      where extract(hour from at.local_start) between 4 and 6
    ),
    'night_owl', exists (
      select 1 from attended as at
      where extract(hour from at.local_start) >= 23
         or extract(hour from at.local_start) < 4
    ),
    'lucky_spot', exists (
      select 1
      from public.waitlist_promotion_notification_outbox as o
      join attended as at on at.id = o.activity_id
      where o.user_id = p_user
    ),
    'weekend', exists (
      select 1
      from attended as fri
      join attended as sat
        on sat.local_start::date = fri.local_start::date + 1
      where extract(isodow from fri.local_start) = 5
    )
  );
$$;

-- Which badges the stats add up to. Category ids are 'fan:<Category>'.
create or replace function private.badges_from_stats(s jsonb)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select array_remove(array[
    case when (s->>'attended')::int >= 1 then 'attend_1' end,
    case when (s->>'attended')::int >= 10 then 'attend_10' end,
    case when (s->>'attended')::int >= 25 then 'attend_25' end,
    case when (s->>'attended')::int >= 50 then 'attend_50' end,
    case when (s->>'hosted')::int >= 1 then 'host_1' end,
    case when (s->>'hosted')::int >= 10 then 'host_10' end,
    case when (s->>'full_house')::boolean then 'full_house' end,
    case when (s->>'categories')::int >= 5 then 'variety_5' end,
    case when (s->>'categories')::int >= 10 then 'variety_10' end,
    case when (s->>'categories')::int >= 20 then 'variety_20' end,
    case when (s->>'friends')::int >= 5 then 'friends_5' end,
    case when (s->>'friends')::int >= 15 then 'friends_15' end,
    case when (s->>'friends')::int >= 30 then 'friends_30' end,
    case when (s->>'together')::int >= 5 then 'together_5' end,
    case when (s->>'best_streak')::int >= 3 then 'streak_3' end,
    case when (s->>'best_streak')::int >= 8 then 'streak_8' end,
    case when (s->>'best_streak')::int >= 20 then 'streak_20' end,
    case when (s->>'five_stars')::int >= 1 then 'five_star' end,
    case when (s->>'rating_count')::int >= 10
      and (s->>'rating_average')::numeric >= 4.5 then 'rated_4_5' end,
    case when (s->>'rating_count')::int >= 25
      and (s->>'rating_average')::numeric >= 4.8 then 'rated_4_8' end,
    case when (s->>'rated_activities')::int >= 10 then 'rater_10' end,
    case when (s->>'early_bird')::boolean then 'early_bird' end,
    case when (s->>'night_owl')::boolean then 'night_owl' end,
    case when (s->>'lucky_spot')::boolean then 'lucky_spot' end,
    case when (s->>'weekend')::boolean then 'weekend' end
  ], null)
  || coalesce(
    (
      select array_agg('fan:' || c.key order by c.key)
      from jsonb_each_text(s->'category_counts') as c
      where c.value::int >= 5
    ),
    '{}'
  );
$$;

create or replace function private.queue_badge_push(p_user uuid, p_badges text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  notification_id uuid;
  function_url text;
  webhook_secret text;
begin
  insert into public.badge_earned_notification_outbox (user_id, badge_id, badge_count)
  values (p_user, p_badges[1], cardinality(p_badges))
  returning id into notification_id;

  select decrypted_secret into function_url
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_function_url'
  limit 1;

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_webhook_secret'
  limit 1;

  if function_url is null or webhook_secret is null then
    raise warning 'Badge notification endpoint or webhook secret is not configured.';
    return;
  end if;

  begin
    perform net.http_post(
      url := function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-waitlist-push-secret', webhook_secret
      ),
      body := jsonb_build_object(
        'event_id', notification_id,
        'event_type', 'badge_earned'
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'Could not queue badge notification: %', sqlerrm;
  end;
end;
$$;

-- Adds the badges a user has earned but doesn't have yet. p_push sends a
-- push for them; p_seen skips the popup (for the first fill).
create or replace function private.award_badges(
  p_user uuid,
  p_push boolean default true,
  p_seen boolean default false
)
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  added text[];
begin
  if p_user is null
    or not exists (select 1 from public.users as u where u.id = p_user) then
    return '{}';
  end if;

  with inserted as (
    insert into public.user_badges (user_id, badge_id, seen_at)
    select p_user, b, case when p_seen then now() end
    from unnest(private.badges_from_stats(private.badge_stats(p_user))) as b
    on conflict (user_id, badge_id) do nothing
    returning badge_id
  )
  select array_agg(badge_id) into added from inserted;

  if added is null then
    return '{}';
  end if;
  if p_push then
    perform private.queue_badge_push(p_user, added);
  end if;
  return added;
end;
$$;

-- A failed badge check never blocks the friendship or rating itself.
create or replace function private.award_badges_after_friendship()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    perform private.award_badges(new.user_a);
    perform private.award_badges(new.user_b);
  exception when others then
    raise warning 'Could not award badges: %', sqlerrm;
  end;
  return null;
end;
$$;

drop trigger if exists friendships_award_badges on public.friendships;
create trigger friendships_award_badges
after insert on public.friendships
for each row
execute function private.award_badges_after_friendship();

create or replace function private.award_badges_after_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    perform private.award_badges(new.rater_id);
    perform private.award_badges(new.rated_user_id);
  exception when others then
    raise warning 'Could not award badges: %', sqlerrm;
  end;
  return null;
end;
$$;

drop trigger if exists activity_ratings_award_badges on public.activity_ratings;
create trigger activity_ratings_award_badges
after insert on public.activity_ratings
for each row
execute function private.award_badges_after_rating();

-- Everyone in an activity that just started.
create or replace function private.award_badges_for_started_activities()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  person uuid;
  checked integer := 0;
begin
  for person in
    select a.host_id
    from public.activities as a
    where a.starts_at > now() - interval '20 minutes'
      and a.starts_at <= now()
    union
    select p.user_id
    from public.activities as a
    join public.activity_participants as p on p.activity_id = a.id
    where a.starts_at > now() - interval '20 minutes'
      and a.starts_at <= now()
      and p.status = 'joined'
  loop
    begin
      perform private.award_badges(person);
    exception when others then
      raise warning 'Could not award badges: %', sqlerrm;
    end;
    checked := checked + 1;
  end loop;
  return checked;
end;
$$;

revoke all on function private.badge_stats(uuid) from public, anon, authenticated;
revoke all on function private.badges_from_stats(jsonb) from public, anon, authenticated;
revoke all on function private.queue_badge_push(uuid, text[]) from public, anon, authenticated;
revoke all on function private.award_badges(uuid, boolean, boolean) from public, anon, authenticated;
revoke all on function private.award_badges_after_friendship() from public, anon, authenticated;
revoke all on function private.award_badges_after_rating() from public, anon, authenticated;
revoke all on function private.award_badges_for_started_activities() from public, anon, authenticated;

-- The signed-in user's badges and progress. Catches up on anything the
-- triggers and cron missed; those show as new in the popup, with no push.
create or replace function public.get_my_badges()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
  stats jsonb;
begin
  if me is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  stats := private.badge_stats(me);
  perform private.award_badges(me, false, false);

  return jsonb_build_object(
    'stats', stats,
    'badges', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', b.badge_id,
            'earned_at', b.earned_at,
            'seen', b.seen_at is not null
          )
          order by b.earned_at desc, b.badge_id
        )
        from public.user_badges as b
        where b.user_id = me
      ),
      '[]'::jsonb
    )
  );
end;
$$;

-- Someone's earned badges, newest first. Nothing across a block, a
-- suspension or the other gender.
create or replace function public.get_user_badges(target_user_id uuid)
returns table (badge_id text, earned_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select b.badge_id, b.earned_at
  from public.user_badges as b
  where auth.uid() is not null
    and b.user_id = target_user_id
    and (
      target_user_id = auth.uid()
      or not public.users_blocked_either_way(auth.uid(), target_user_id)
    )
  order by b.earned_at desc, b.badge_id;
$$;

create or replace function public.mark_badges_seen()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.user_badges
  set seen_at = now()
  where user_id = auth.uid()
    and seen_at is null;
$$;

revoke all on function public.get_my_badges() from public, anon;
revoke all on function public.get_user_badges(uuid) from public, anon;
revoke all on function public.mark_badges_seen() from public, anon;
grant execute on function public.get_my_badges() to authenticated;
grant execute on function public.get_user_badges(uuid) to authenticated;
grant execute on function public.mark_badges_seen() to authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'award-badges') then
    perform cron.unschedule('award-badges');
  end if;
end $$;

-- Every 15 minutes
select cron.schedule(
  'award-badges',
  '*/15 * * * *',
  $cron$select private.award_badges_for_started_activities();$cron$
);

-- Existing users get what they already earned, with no push or popup.
select private.award_badges(u.id, false, true) from public.users as u;

commit;
