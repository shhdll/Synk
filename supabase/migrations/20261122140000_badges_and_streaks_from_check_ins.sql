-- Badges and weekly streaks now count only activities the user checked in
-- to (as host or joined member), like the profile's activities count
-- (20261122130000_completed_count_from_check_ins.sql). Before, any hosted or
-- joined activity that had started counted.
--
-- * private.badge_stats: "attended" means checked in. "Together" needs the
--   friend to have checked in too. Hosting still needs someone else to have
--   joined, as before.
-- * Badges are given right when someone checks in, by triggers, since the
--   start-time cron no longer has anything new to give.
-- * get_user_streak_times: check-in times' activities, for own and friends'
--   streaks.
--
-- Badges already earned are kept.
begin;

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
    where a.host_id = p_user
      and a.host_checked_in_at is not null
    union
    select a.id, a.host_id, a.max_participants,
      a.starts_at at time zone 'Asia/Riyadh',
      private.activity_category(a.category_label, a.title, a.description)
    from public.activities as a
    join public.activity_participants as p on p.activity_id = a.id
    where p.user_id = p_user
      and p.status = 'joined'
      and p.checked_in_at is not null
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
          select a.host_id as person
          from public.activities as a
          where a.id = at.id and a.host_checked_in_at is not null
          union all
          select p.user_id from public.activity_participants as p
          where p.activity_id = at.id and p.status = 'joined'
            and p.checked_in_at is not null
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

revoke all on function private.badge_stats(uuid) from public, anon, authenticated;

-- A failed badge check never blocks the check-in itself.
create or replace function private.award_badges_after_check_in()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  begin
    perform private.award_badges(
      case when tg_table_name = 'activities' then new.host_id else new.user_id end
    );
  exception when others then
    raise warning 'Could not award badges: %', sqlerrm;
  end;
  return null;
end;
$$;
revoke all on function private.award_badges_after_check_in() from public, anon, authenticated;

drop trigger if exists award_badges_after_member_check_in on public.activity_participants;
create trigger award_badges_after_member_check_in
after update of checked_in_at on public.activity_participants
for each row
when (old.checked_in_at is null and new.checked_in_at is not null)
execute function private.award_badges_after_check_in();

drop trigger if exists award_badges_after_host_check_in on public.activities;
create trigger award_badges_after_host_check_in
after update of host_checked_in_at on public.activities
for each row
when (old.host_checked_in_at is null and new.host_checked_in_at is not null)
execute function private.award_badges_after_check_in();

-- Start times of the activities a user checked in to, so they and their
-- friends can see their weekly streak. Only times, nothing about the
-- activities. Never across a block.
create or replace function public.get_user_streak_times(target_user_id uuid)
returns setof timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select activity.starts_at
  from public.activities as activity
  where auth.uid() is not null
    and target_user_id is not null
    and (
      auth.uid() = target_user_id
      or (
        exists (
          select 1
          from public.friendships as friendship
          where friendship.user_a = least(auth.uid(), target_user_id)
            and friendship.user_b = greatest(auth.uid(), target_user_id)
        )
        and not public.users_blocked_either_way(auth.uid(), target_user_id)
      )
    )
    and activity.starts_at > now() - interval '2 years'
    and (
      (activity.host_id = target_user_id and activity.host_checked_in_at is not null)
      or exists (
        select 1 from public.activity_participants as participation
        where participation.activity_id = activity.id
          and participation.user_id = target_user_id
          and participation.status = 'joined'
          and participation.checked_in_at is not null
      )
    );
$$;

revoke all on function public.get_user_streak_times(uuid) from public, anon;
grant execute on function public.get_user_streak_times(uuid) to authenticated;

commit;
