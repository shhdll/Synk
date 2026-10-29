-- Notify every joined participant, including the host, when an activity fills.
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
  recipient record;
  function_url text;
  webhook_secret text;
begin
  select activity.host_id, activity.title, activity.max_participants
  into host_user_id, activity_title, capacity
  from public.activities as activity
  where activity.id = requested_activity_id;

  if host_user_id is null or activity_title is null or capacity is null then
    return;
  end if;

  select count(*) into joined_count
  from public.activity_participants as participant
  where participant.activity_id = requested_activity_id
    and participant.status = 'joined'
    and participant.user_id <> host_user_id;

  if 1 + joined_count < capacity then
    return;
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
      user_id, activity_id, activity_title
    )
    select recipients.user_id, requested_activity_id, activity_title
    from recipients
    on conflict (activity_id, user_id) do nothing
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
      -- Joining and capacity changes must succeed if push delivery is unavailable.
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
  if tg_op = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;
  perform public.enqueue_activity_full_notifications(new.activity_id);
  return new;
end;
$$;

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
