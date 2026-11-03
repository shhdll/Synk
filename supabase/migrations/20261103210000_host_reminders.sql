-- Activity reminders for the host too, and again after the time changes.
--
-- The host isn't in activity_participants, so they never got a reminder.
-- Reminders were also one per person per activity, so moving the start
-- time after a reminder went out meant no reminder for the new time.

begin;

alter table public.activity_reminder_notification_outbox
  add column if not exists starts_at timestamptz;

-- Reminders already sent count for the time they were sent for.
update public.activity_reminder_notification_outbox as reminder
set starts_at = activity.starts_at
from public.activities as activity
where reminder.activity_id = activity.id
  and reminder.starts_at is null;

alter table public.activity_reminder_notification_outbox
  drop constraint if exists activity_reminder_notification_outbox_activity_id_user_id_key;

create unique index if not exists activity_reminder_outbox_once_per_start
  on public.activity_reminder_notification_outbox (activity_id, user_id, starts_at);

create or replace function public.queue_activity_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_queued integer;
begin
  insert into public.activity_reminder_notification_outbox (
    user_id, activity_id, activity_title, starts_at
  )
  select people.user_id, activity.id, activity.title, activity.starts_at
  from public.activities as activity
  cross join lateral (
    select activity.host_id as user_id
    where activity.host_id is not null
    union
    select participation.user_id
    from public.activity_participants as participation
    where participation.activity_id = activity.id
      and participation.status = 'joined'
  ) as people
  where activity.starts_at > now()
    and activity.starts_at <= now() + interval '60 minutes'
  on conflict (activity_id, user_id, starts_at) do nothing;

  get diagnostics v_queued = row_count;
  return v_queued;
end;
$$;

revoke execute on function public.queue_activity_reminders()
  from public, anon, authenticated;

commit;
