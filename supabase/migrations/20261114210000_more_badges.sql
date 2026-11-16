-- A fourth level for hosting, variety and streaks, so every row has four.
begin;

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
    case when (s->>'hosted')::int >= 25 then 'host_25' end,
    case when (s->>'full_house')::boolean then 'full_house' end,
    case when (s->>'categories')::int >= 5 then 'variety_5' end,
    case when (s->>'categories')::int >= 10 then 'variety_10' end,
    case when (s->>'categories')::int >= 20 then 'variety_20' end,
    case when (s->>'categories')::int >= 30 then 'variety_30' end,
    case when (s->>'friends')::int >= 5 then 'friends_5' end,
    case when (s->>'friends')::int >= 15 then 'friends_15' end,
    case when (s->>'friends')::int >= 30 then 'friends_30' end,
    case when (s->>'together')::int >= 5 then 'together_5' end,
    case when (s->>'best_streak')::int >= 3 then 'streak_3' end,
    case when (s->>'best_streak')::int >= 8 then 'streak_8' end,
    case when (s->>'best_streak')::int >= 20 then 'streak_20' end,
    case when (s->>'best_streak')::int >= 52 then 'streak_52' end,
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

revoke all on function private.badges_from_stats(jsonb) from public, anon, authenticated;

-- Anyone already there gets it quietly.
select private.award_badges(u.id, false, true) from public.users as u;

commit;
