-- Per-user push notification switches, plus activity reminders sent about
-- an hour before a joined activity starts.
begin;

create table if not exists public.notification_preferences (
  user_id uuid primary key references public.users(id) on delete cascade,
  waitlist boolean not null default true,
  join_requests boolean not null default true,
  activity_updates boolean not null default true,
  reminders boolean not null default true,
  friend_requests boolean not null default true,
  marketing boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

drop policy if exists "Users read their own notification preferences"
  on public.notification_preferences;
create policy "Users read their own notification preferences"
  on public.notification_preferences for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users add their own notification preferences"
  on public.notification_preferences;
create policy "Users add their own notification preferences"
  on public.notification_preferences for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users change their own notification preferences"
  on public.notification_preferences;
create policy "Users change their own notification preferences"
  on public.notification_preferences for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

revoke all on public.notification_preferences from public, anon;
grant select, insert, update on public.notification_preferences to authenticated;
grant select on public.notification_preferences to service_role;

-- Activity reminders
create table if not exists public.activity_reminder_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  activity_title text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  unique (activity_id, user_id)
);

alter table public.activity_reminder_notification_outbox enable row level security;
revoke all on public.activity_reminder_notification_outbox
  from public, anon, authenticated;
grant select, update on public.activity_reminder_notification_outbox to service_role;

create or replace function public.enqueue_activity_reminder_notification()
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
    raise warning 'Activity reminder endpoint or webhook secret is not configured.';
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
        'event_type', 'activity_reminder'
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'Could not queue activity reminder: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists activity_reminder_push
  on public.activity_reminder_notification_outbox;
create trigger activity_reminder_push
after insert on public.activity_reminder_notification_outbox
for each row
execute function public.enqueue_activity_reminder_notification();

revoke all on function public.enqueue_activity_reminder_notification()
  from public, anon, authenticated;

-- Queues one reminder per joined participant for activities starting
-- within the next hour.
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
    user_id, activity_id, activity_title
  )
  select participation.user_id, activity.id, activity.title
  from public.activities as activity
  join public.activity_participants as participation
    on participation.activity_id = activity.id
  where participation.status = 'joined'
    and activity.starts_at > now()
    and activity.starts_at <= now() + interval '60 minutes'
  on conflict (activity_id, user_id) do nothing;

  get diagnostics v_queued = row_count;
  return v_queued;
end;
$$;

revoke execute on function public.queue_activity_reminders()
  from public, anon, authenticated;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'queue-activity-reminders') then
    perform cron.unschedule('queue-activity-reminders');
  end if;
end $$;

-- Every 5 minutes
select cron.schedule(
  'queue-activity-reminders',
  '*/5 * * * *',
  $cron$select public.queue_activity_reminders();$cron$
);

commit;
