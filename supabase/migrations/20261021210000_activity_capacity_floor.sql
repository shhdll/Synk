-- Keep edits from lowering an activity's capacity below the host plus its
-- currently confirmed participants. The row update lock serializes this check
-- with the join RPCs, which lock the activity row before confirming a join.
create or replace function public.enforce_activity_capacity_floor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  confirmed_count integer;
begin
  select 1 + count(*) into confirmed_count
  from public.activity_participants participant
  where participant.activity_id = old.id
    and participant.status = 'joined';

  if new.max_participants < confirmed_count then
    raise exception 'Capacity cannot be lower than the current number of participants (% confirmed).',
      confirmed_count
      using errcode = '23514',
        constraint = 'activities_capacity_not_below_confirmed';
  end if;
  return new;
end;
$$;

drop trigger if exists activities_capacity_floor_guard on public.activities;
create trigger activities_capacity_floor_guard
before update of max_participants on public.activities
for each row
when (new.max_participants is distinct from old.max_participants)
execute function public.enforce_activity_capacity_floor();

revoke all on function public.enforce_activity_capacity_floor() from public;
