-- Activities can be scheduled no more than three Riyadh calendar months ahead.
create or replace function public.enforce_activity_schedule_window()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  latest_allowed_date date := (
    (now() at time zone 'Asia/Riyadh')::date + interval '3 months'
  )::date;
begin
  if (new.starts_at at time zone 'Asia/Riyadh')::date > latest_allowed_date then
    raise exception 'Activities can only be scheduled up to 3 months in advance.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists activities_schedule_window on public.activities;
create trigger activities_schedule_window
before insert or update of starts_at on public.activities
for each row
execute function public.enforce_activity_schedule_window();
