-- Notify affected participants when a host edit creates a schedule conflict.
-- A user hosting the other activity can still be a participant in the edited
-- activity, so only suppress the person who hosts the activity being edited.
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
    select 1 from public.activities changed_activity
    where changed_activity.id = new.changed_activity_id
      and changed_activity.host_id = new.user_id
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

  select decrypted_secret into function_url
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_function_url' limit 1;
  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
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
      body := jsonb_build_object(
        'event_id', event_id,
        'event_type', 'activity_conflict'
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'Could not queue schedule conflict notification: %', sqlerrm;
  end;
  return new;
end;
$$;

revoke all on function public.enqueue_activity_conflict_notification() from public;
