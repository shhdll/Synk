-- Gentle marketing pushes ("Settings > Notifications > marketing"):
--
-- * nice_weather: on an evening with pleasant weather where the user is,
--   "It's 24° this evening, a great time to get out". Checked daily at
--   16:00 Saudi time by the push function (task 'nice_weather_check'),
--   which asks Open-Meteo about each user's rough location.
-- * streak_ending: Friday 10:00 Saudi time, when the weekly streak breaks
--   unless the user goes to something by Saturday night. Same rule as the
--   app's "fading" streak (WeeklyStreak.isFading): a streak of 1+ weeks,
--   nothing attended this week, nothing booked for the rest of it.
--
-- Never too much: at most one marketing push a day, each kind at most once
-- a week, and nothing when the marketing switch is off.
--
-- Rough locations are kept in user_weather_spots, rounded to 0.1° (about
-- 10 km), only for the weather nudge. The app saves the user's own row.
--
-- Weeks run Sunday to Saturday in Saudi time (Asia/Riyadh).
-- Safe to run again.

begin;

-- ---- Rough locations ------------------------------------------------------------

create table if not exists public.user_weather_spots (
  user_id uuid primary key references public.users (id) on delete cascade,
  latitude numeric(4, 1) not null check (latitude between -90 and 90),
  longitude numeric(4, 1) not null check (longitude between -180 and 180),
  updated_at timestamptz not null default now()
);

create index if not exists user_weather_spots_place_idx
  on public.user_weather_spots (latitude, longitude);

alter table public.user_weather_spots enable row level security;

drop policy if exists "user_weather_spots: own row" on public.user_weather_spots;
create policy "user_weather_spots: own row"
on public.user_weather_spots for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

revoke all on public.user_weather_spots from public, anon;
grant select, insert, update, delete on public.user_weather_spots to authenticated;

-- ---- Outbox -----------------------------------------------------------------------

create table if not exists public.marketing_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('nice_weather', 'streak_ending')),
  -- The push function reads this column for every kind; unused here.
  activity_title text not null default '',
  temperature integer,
  streak_weeks integer,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists marketing_notification_outbox_user_idx
  on public.marketing_notification_outbox (user_id, created_at desc);

alter table public.marketing_notification_outbox enable row level security;
revoke all on public.marketing_notification_outbox from public, anon, authenticated;
grant select, update on public.marketing_notification_outbox to service_role;

create or replace function public.enqueue_marketing_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  function_url text;
  webhook_secret text;
begin
  select decrypted_secret into function_url
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_function_url'
  limit 1;

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_webhook_secret'
  limit 1;

  if function_url is null or webhook_secret is null then
    raise warning 'Marketing notification endpoint or webhook secret is not configured.';
    return new;
  end if;

  begin
    perform net.http_post(
      url := function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-waitlist-push-secret', webhook_secret
      ),
      body := jsonb_build_object(
        'event_id', new.id,
        'event_type', 'marketing'
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'Could not queue marketing notification: %', sqlerrm;
  end;

  return new;
end;
$$;

revoke all on function public.enqueue_marketing_notification()
  from public, anon, authenticated;

drop trigger if exists marketing_push on public.marketing_notification_outbox;
create trigger marketing_push
after insert on public.marketing_notification_outbox
for each row
execute function public.enqueue_marketing_notification();

-- ---- Not too much -------------------------------------------------------------------

-- Whether [target] may get a [kind] nudge now: the marketing switch is on
-- (no row means on), nothing from us in the last 20 hours, and not this
-- kind within [cooldown].
create or replace function public.can_send_marketing(
  target uuid,
  kind text,
  cooldown interval
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
      (select p.marketing from public.notification_preferences p where p.user_id = target),
      true
    )
    and not exists (
      select 1 from public.marketing_notification_outbox o
      where o.user_id = target and o.created_at > now() - interval '20 hours'
    )
    and not exists (
      select 1 from public.marketing_notification_outbox o
      where o.user_id = target
        and o.kind = can_send_marketing.kind
        and o.created_at > now() - cooldown
    );
$$;

revoke all on function public.can_send_marketing(uuid, text, interval)
  from public, anon, authenticated;

-- ---- Streak ending ------------------------------------------------------------------

create or replace function public.queue_streak_nudges()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_queued integer;
begin
  with today as (
    select (now() at time zone 'Asia/Riyadh')::date as d
  ),
  this_week as (
    -- Sunday of the current week.
    select d - extract(dow from d)::int as ws, d from today
  ),
  -- Hosted, or joined and accepted, whose start has passed.
  attended as (
    select a.host_id as user_id, a.starts_at
    from public.activities a
    where a.starts_at <= now()
    union all
    select p.user_id, a.starts_at
    from public.activity_participants p
    join public.activities a on a.id = p.activity_id
    where p.status = 'joined' and a.starts_at <= now()
  ),
  weeks as (
    select distinct
      x.user_id,
      ((x.starts_at at time zone 'Asia/Riyadh')::date
        - extract(dow from (x.starts_at at time zone 'Asia/Riyadh')::date)::int) as ws
    from attended x
  ),
  -- Runs of weeks in a row before this one ("gaps and islands").
  islands as (
    select w.user_id, w.ws,
      w.ws - (row_number() over (partition by w.user_id order by w.ws) * 7)::int as island
    from weeks w, this_week t
    where w.ws < t.ws
  ),
  streaks as (
    select i.user_id, count(*)::int as weeks
    from islands i
    join islands last_week
      on last_week.user_id = i.user_id
     and last_week.island = i.island
    cross join this_week t
    where last_week.ws = t.ws - 7
    group by i.user_id
  )
  insert into public.marketing_notification_outbox (user_id, kind, streak_weeks)
  select s.user_id, 'streak_ending', s.weeks
  from streaks s
  cross join this_week t
  -- Still has to keep it alive: nothing attended this week...
  where not exists (
      select 1 from weeks w where w.user_id = s.user_id and w.ws = t.ws
    )
    -- ...and nothing booked before the week ends (Saturday night).
    and not exists (
      select 1 from public.activities a
      left join public.activity_participants p
        on p.activity_id = a.id and p.user_id = s.user_id and p.status = 'joined'
      where (a.host_id = s.user_id or p.user_id is not null)
        and a.starts_at > now()
        and (a.starts_at at time zone 'Asia/Riyadh')::date < t.ws + 7
    )
    and exists (select 1 from auth.users u where u.id = s.user_id)
    and public.can_send_marketing(s.user_id, 'streak_ending', interval '6 days');

  get diagnostics v_queued = row_count;
  return v_queued;
end;
$$;

revoke all on function public.queue_streak_nudges() from public, anon, authenticated;

-- ---- Nice weather -------------------------------------------------------------------

-- The rough locations worth checking today: people who could get the nudge.
create or replace function public.marketing_weather_spots()
returns table (latitude numeric, longitude numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct s.latitude, s.longitude
  from public.user_weather_spots s
  where s.updated_at > now() - interval '30 days'
    and public.can_send_marketing(s.user_id, 'nice_weather', interval '6 days')
  limit 1000;
$$;

revoke all on function public.marketing_weather_spots() from public, anon, authenticated;
grant execute on function public.marketing_weather_spots() to service_role;

-- [spots]: [{"latitude": 24.7, "longitude": 46.7, "temperature": 24}, ...],
-- the places where this evening looks nice.
create or replace function public.queue_nice_weather_nudges(spots jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_queued integer;
begin
  insert into public.marketing_notification_outbox (user_id, kind, temperature)
  select distinct on (s.user_id) s.user_id, 'nice_weather', (x ->> 'temperature')::int
  from jsonb_array_elements(coalesce(spots, '[]'::jsonb)) x
  join public.user_weather_spots s
    on s.latitude = (x ->> 'latitude')::numeric
   and s.longitude = (x ->> 'longitude')::numeric
  where s.updated_at > now() - interval '30 days'
    and exists (select 1 from auth.users u where u.id = s.user_id)
    and public.can_send_marketing(s.user_id, 'nice_weather', interval '6 days');

  get diagnostics v_queued = row_count;
  return v_queued;
end;
$$;

revoke all on function public.queue_nice_weather_nudges(jsonb) from public, anon, authenticated;
grant execute on function public.queue_nice_weather_nudges(jsonb) to service_role;

-- Asks the push function to check this evening's weather.
create or replace function public.request_nice_weather_check()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  function_url text;
  webhook_secret text;
begin
  select decrypted_secret into function_url
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_function_url'
  limit 1;

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_webhook_secret'
  limit 1;

  if function_url is null or webhook_secret is null then
    raise warning 'Weather check endpoint or webhook secret is not configured.';
    return;
  end if;

  perform net.http_post(
    url := function_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-waitlist-push-secret', webhook_secret
    ),
    body := jsonb_build_object('task', 'nice_weather_check'),
    timeout_milliseconds := 60000
  );
end;
$$;

revoke all on function public.request_nice_weather_check() from public, anon, authenticated;

-- ---- Schedule (UTC; Saudi time is UTC+3) ----------------------------------------

do $$
begin
  if exists (select 1 from cron.job where jobname = 'marketing-streak-nudges') then
    perform cron.unschedule('marketing-streak-nudges');
  end if;
  if exists (select 1 from cron.job where jobname = 'marketing-weather-check') then
    perform cron.unschedule('marketing-weather-check');
  end if;
end $$;

-- Fridays 10:00 Saudi time.
select cron.schedule(
  'marketing-streak-nudges',
  '0 7 * * 5',
  $cron$select public.queue_streak_nudges();$cron$
);

-- Every day 16:00 Saudi time, for the evening.
select cron.schedule(
  'marketing-weather-check',
  '0 13 * * *',
  $cron$select public.request_nice_weather_check();$cron$
);

commit;
