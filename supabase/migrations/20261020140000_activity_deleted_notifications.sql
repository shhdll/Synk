-- Preserve deletion events independently of the activity row they describe.
-- This lets joined participants receive a push after the activity is removed.
create table if not exists public.activity_deleted_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null,
  activity_title text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.activity_deleted_notification_outbox enable row level security;
revoke all on public.activity_deleted_notification_outbox
  from public, anon, authenticated;
grant select, update on public.activity_deleted_notification_outbox to service_role;

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
    where participant.activity_id = old.id
      and participant.status = 'joined'
      and participant.user_id <> old.host_id
  loop
    insert into public.activity_deleted_notification_outbox (
      user_id, activity_id, activity_title
    ) values (
      recipient.user_id, old.id, old.title
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
      -- A push transport failure must not prevent the host from deleting.
      raise warning 'Could not queue activity deletion notification: %', sqlerrm;
    end;
  end loop;

  return old;
end;
$$;

drop trigger if exists activity_deleted_push on public.activities;
create trigger activity_deleted_push
before delete on public.activities
for each row
execute function public.enqueue_activity_deleted_notifications();
