-- Queue a push notification for every accepted participant when activity
-- details change. Pending requests and waitlisted users are not participants.
create table if not exists public.activity_update_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  activity_title text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.activity_update_notification_outbox enable row level security;
revoke all on public.activity_update_notification_outbox
  from public, anon, authenticated;
grant select, update on public.activity_update_notification_outbox to service_role;

create or replace function public.enqueue_activity_update_notifications()
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
  if old.title is not distinct from new.title
    and old.description is not distinct from new.description
    and old.starts_at is not distinct from new.starts_at
    and old.location_name is not distinct from new.location_name
    and old.location_address is not distinct from new.location_address
    and old.latitude is not distinct from new.latitude
    and old.longitude is not distinct from new.longitude
    and old.max_participants is not distinct from new.max_participants
    and old.is_public is not distinct from new.is_public
    and old.photo_url is not distinct from new.photo_url then
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

  for recipient in
    select participant.user_id
    from public.activity_participants as participant
    where participant.activity_id = new.id
      and participant.status = 'joined'
      and participant.user_id <> new.host_id
  loop
    insert into public.activity_update_notification_outbox (
      user_id, activity_id, activity_title
    ) values (
      recipient.user_id, new.id, new.title
    ) returning id into notification_id;

    if function_url is null or webhook_secret is null then
      raise warning 'Activity update push endpoint or webhook secret is not configured.';
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
          'event_type', 'activity_updated'
        ),
        timeout_milliseconds := 5000
      );
    exception when others then
      -- The activity edit must succeed even when push delivery is unavailable.
      raise warning 'Could not queue activity update notification: %', sqlerrm;
    end;
  end loop;

  return new;
end;
$$;

drop trigger if exists activity_update_push on public.activities;
create trigger activity_update_push
after update of title, description, starts_at, location_name, location_address,
  latitude, longitude, max_participants, is_public, photo_url
on public.activities
for each row
execute function public.enqueue_activity_update_notifications();
