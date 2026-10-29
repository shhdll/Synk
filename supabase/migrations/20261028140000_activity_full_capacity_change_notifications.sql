-- Also notify the host when lowering the participant limit makes an already
-- occupied activity full.
create or replace function public.enqueue_activity_full_notification_for_capacity_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  notification_id uuid;
  joined_count integer;
  function_url text;
  webhook_secret text;
begin
  if new.max_participants is not distinct from old.max_participants then
    return new;
  end if;

  select count(*) into joined_count
  from public.activity_participants as participant
  where participant.activity_id = new.id
    and participant.status = 'joined'
    and participant.user_id <> new.host_id;

  if new.host_id is null or new.title is null
    or 1 + joined_count < new.max_participants then
    return new;
  end if;

  insert into public.activity_full_notification_outbox (
    user_id, activity_id, activity_title
  ) values (
    new.host_id, new.id, new.title
  )
  on conflict (activity_id, user_id) do nothing
  returning id into notification_id;

  if notification_id is null then
    return new;
  end if;

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
        'event_id', notification_id,
        'event_type', 'activity_full'
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'Could not queue activity full notification: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists activity_full_capacity_change_push on public.activities;
create trigger activity_full_capacity_change_push
after update of max_participants on public.activities
for each row
when (new.max_participants is distinct from old.max_participants)
execute function public.enqueue_activity_full_notification_for_capacity_change();

revoke all on function public.enqueue_activity_full_notification_for_capacity_change()
  from public, anon, authenticated;
