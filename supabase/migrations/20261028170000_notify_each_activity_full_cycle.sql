-- Allow a new full notification each time an activity transitions from not
-- full to full, while still preventing duplicate notifications in one cycle.
alter table public.activity_full_notification_outbox
  add column if not exists full_cycle_id uuid not null default gen_random_uuid();

alter table public.activity_full_notification_outbox
  drop constraint if exists activity_full_notification_outbox_activity_id_user_id_key;

create unique index if not exists activity_full_notification_outbox_cycle_user_key
  on public.activity_full_notification_outbox(activity_id, user_id, full_cycle_id);

create table if not exists public.activity_full_notification_state (
  activity_id uuid primary key references public.activities(id) on delete cascade,
  is_full boolean not null default false,
  full_cycle_id uuid,
  updated_at timestamptz not null default now()
);

alter table public.activity_full_notification_state enable row level security;
revoke all on public.activity_full_notification_state
  from public, anon, authenticated;

-- Seed current fullness so deploying this migration does not create a duplicate
-- event for an activity that was already full. Existing outbox rows represent
-- the current cycle; future not-full to full transitions get a fresh cycle ID.
insert into public.activity_full_notification_state (
  activity_id, is_full, full_cycle_id
)
select activity.id,
  1 + (
    select count(*)
    from public.activity_participants as participant
    where participant.activity_id = activity.id
      and participant.status = 'joined'
      and participant.user_id <> activity.host_id
  ) >= activity.max_participants,
  case when 1 + (
    select count(*)
    from public.activity_participants as participant
    where participant.activity_id = activity.id
      and participant.status = 'joined'
      and participant.user_id <> activity.host_id
  ) >= activity.max_participants then gen_random_uuid() end
from public.activities as activity
on conflict (activity_id) do nothing;

create or replace function public.enqueue_activity_full_notifications(
  requested_activity_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  activity_title text;
  host_user_id uuid;
  capacity integer;
  joined_count integer;
  currently_full boolean;
  was_full boolean;
  cycle_id uuid;
  recipient record;
  function_url text;
  webhook_secret text;
begin
  -- Serialize fullness transitions for the same activity.
  select activity.host_id, activity.title, activity.max_participants
  into host_user_id, activity_title, capacity
  from public.activities as activity
  where activity.id = requested_activity_id
  for update;

  if not found or host_user_id is null or activity_title is null or capacity is null then
    return;
  end if;

  select count(*) into joined_count
  from public.activity_participants as participant
  where participant.activity_id = requested_activity_id
    and participant.status = 'joined'
    and participant.user_id <> host_user_id;

  currently_full := 1 + joined_count >= capacity;

  insert into public.activity_full_notification_state (
    activity_id, is_full, full_cycle_id
  ) values (requested_activity_id, false, null)
  on conflict (activity_id) do nothing;

  select state.is_full into was_full
  from public.activity_full_notification_state as state
  where state.activity_id = requested_activity_id
  for update;

  if not currently_full then
    update public.activity_full_notification_state
    set is_full = false, full_cycle_id = null, updated_at = now()
    where activity_id = requested_activity_id;
    return;
  end if;

  if was_full then
    return;
  end if;

  cycle_id := gen_random_uuid();
  update public.activity_full_notification_state
  set is_full = true, full_cycle_id = cycle_id, updated_at = now()
  where activity_id = requested_activity_id;

  select decrypted_secret into function_url
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_function_url'
  limit 1;

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_webhook_secret'
  limit 1;

  if function_url is null or webhook_secret is null then
    raise warning 'Activity full notification endpoint or webhook secret is not configured.';
  end if;

  for recipient in
    with recipients as (
      select host_user_id as user_id
      union
      select participant.user_id
      from public.activity_participants as participant
      where participant.activity_id = requested_activity_id
        and participant.status = 'joined'
    )
    insert into public.activity_full_notification_outbox (
      user_id, activity_id, activity_title, full_cycle_id
    )
    select recipients.user_id, requested_activity_id, activity_title, cycle_id
    from recipients
    on conflict (activity_id, user_id, full_cycle_id) do nothing
    returning id
  loop
    if function_url is null or webhook_secret is null then
      continue;
    end if;
    begin
      perform net.http_post(
        url := function_url,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-waitlist-push-secret', webhook_secret
        ),
        body := jsonb_build_object(
          'event_id', recipient.id,
          'event_type', 'activity_full'
        ),
        timeout_milliseconds := 5000
      );
    exception when others then
      raise warning 'Could not queue activity full notification: %', sqlerrm;
    end;
  end loop;
end;
$$;

create or replace function public.enqueue_activity_full_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform public.enqueue_activity_full_notifications(old.activity_id);
    return old;
  end if;

  if tg_op = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;

  perform public.enqueue_activity_full_notifications(new.activity_id);
  return new;
end;
$$;

drop trigger if exists activity_full_push on public.activity_participants;
create trigger activity_full_push
after insert or update of status or delete on public.activity_participants
for each row
execute function public.enqueue_activity_full_notification();

create or replace function public.enqueue_activity_full_notification_for_capacity_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.max_participants is distinct from old.max_participants then
    perform public.enqueue_activity_full_notifications(new.id);
  end if;
  return new;
end;
$$;

revoke all on function public.enqueue_activity_full_notifications(uuid)
  from public, anon, authenticated;
revoke all on function public.enqueue_activity_full_notification()
  from public, anon, authenticated;
revoke all on function public.enqueue_activity_full_notification_for_capacity_change()
  from public, anon, authenticated;
