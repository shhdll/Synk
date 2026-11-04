-- Lets top picks learn from what the user does.
--
--   * activity_swipes also saves 'skip' (a For you card swiped away)
--   * get_my_for_you_history: activities the user hosted or joined in the
--     last 180 days, and cards they opened or skipped in the last 90
--
-- Safe to run again.

begin;

alter table public.activity_swipes
  drop constraint if exists activity_swipes_action_check;
alter table public.activity_swipes
  add constraint activity_swipes_action_check
  check (action in ('join', 'open_details', 'skip'));

create or replace function public.get_my_for_you_history()
returns table (
  activity_id uuid,
  title text,
  description text,
  category_label text,
  signal text,
  happened_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select *
  from (
    select a.id, a.title, a.description, a.category_label,
      'joined', least(a.starts_at, now())
    from public.activities a
    where a.host_id = auth.uid()
      and a.starts_at > now() - interval '180 days'

    union all

    select a.id, a.title, a.description, a.category_label,
      'joined', p.created_at
    from public.activity_participants p
    join public.activities a on a.id = p.activity_id
    where p.user_id = auth.uid()
      and p.status = 'joined'
      and p.created_at > now() - interval '180 days'

    -- Joins from the deck are already in activity_participants.
    union all

    select a.id, a.title, a.description, a.category_label,
      case s.action when 'skip' then 'skipped' else 'opened' end,
      s.created_at
    from public.activity_swipes s
    join public.activities a on a.id = s.activity_id
    where s.user_id = auth.uid()
      and s.action in ('open_details', 'skip')
      and s.created_at > now() - interval '90 days'
  ) history
  order by 6 desc
  limit 300;
$$;

revoke all on function public.get_my_for_you_history() from public, anon;
grant execute on function public.get_my_for_you_history() to authenticated;

commit;
