-- Retain the activity host on deletion events so delivery can never send the
-- host a push about their own activity being deleted.
alter table public.activity_deleted_notification_outbox
  add column if not exists host_id uuid;

create or replace function public.enqueue_activity_deleted_notifications()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient record;
  notification_id uuid;
  function_url text;
  webhook_secret text;
begin
  select decrypted_secret into function_url from vault.decrypted_secrets
    where name = 'waitlist_promotion_function_url' limit 1;
  select decrypted_secret into webhook_secret from vault.decrypted_secrets
    where name = 'waitlist_promotion_webhook_secret' limit 1;

  for recipient in
    select distinct participant.user_id
    from public.activity_participants participant
    where participant.activity_id = old.id
      and participant.status = 'joined'
      and participant.user_id <> old.host_id
  loop
    insert into public.activity_deleted_notification_outbox (
      user_id, activity_id, activity_title, host_id
    ) values (
      recipient.user_id, old.id, old.title, old.host_id
    ) returning id into notification_id;

    if function_url is null or webhook_secret is null then
      raise warning 'Activity deletion push endpoint or webhook secret is not configured.';
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
          'event_id', notification_id,
          'event_type', 'activity_deleted'
        ),
        timeout_milliseconds := 5000
      );
    exception when others then
      raise warning 'Could not queue activity deletion notification: %', sqlerrm;
    end;
  end loop;
  return old;
end;
$$;

drop trigger if exists activity_deleted_push on public.activities;
create trigger activity_deleted_push
before delete on public.activities
for each row execute function public.enqueue_activity_deleted_notifications();

-- Conflict pushes are for affected participants, never for either activity's
-- host. Host-owned conflicts remain visible in the app's conflict list.
create or replace function public.enqueue_activity_conflict_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_id uuid;
  function_url text;
  webhook_secret text;
begin
  if new.status <> 'unresolved' then return new; end if;
  if tg_op = 'UPDATE' and new.updated_at = old.updated_at then return new; end if;

  if exists (
    select 1 from public.activities activity
    where activity.id in (new.first_activity_id, new.second_activity_id)
      and activity.host_id = new.user_id
  ) then
    return new;
  end if;

  if not exists (
    select 1 from public.activity_participants participant
    where participant.user_id = new.user_id
      and participant.status = 'joined'
      and participant.activity_id in (new.first_activity_id, new.second_activity_id)
  ) then
    return new;
  end if;

  insert into public.activity_conflict_notification_outbox(
    conflict_id, user_id, activity_id, activity_title
  )
  select new.id, new.user_id, activity.id, activity.title
  from public.activities activity
  where activity.id = new.changed_activity_id
  returning id into event_id;
  if event_id is null then return new; end if;

  select decrypted_secret into function_url from vault.decrypted_secrets
    where name = 'waitlist_promotion_function_url' limit 1;
  select decrypted_secret into webhook_secret from vault.decrypted_secrets
    where name = 'waitlist_promotion_webhook_secret' limit 1;
  if function_url is null or webhook_secret is null then
    raise warning 'Schedule conflict push endpoint or webhook secret is not configured.';
    return new;
  end if;
  begin
    perform net.http_post(
      url := function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-waitlist-push-secret', webhook_secret
      ),
      body := jsonb_build_object('event_id', event_id, 'event_type', 'activity_conflict'),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'Could not queue schedule conflict notification: %', sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists activity_conflict_push on public.activity_schedule_conflicts;
create trigger activity_conflict_push
after insert or update of status, updated_at on public.activity_schedule_conflicts
for each row execute function public.enqueue_activity_conflict_notification();

revoke all on function public.enqueue_activity_deleted_notifications() from public;
revoke all on function public.enqueue_activity_conflict_notification() from public;
