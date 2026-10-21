-- Notify the activity host when someone requests to join a private activity.
create table if not exists public.join_request_received_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null,
  activity_title text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.join_request_received_notification_outbox enable row level security;
revoke all on public.join_request_received_notification_outbox
  from public, anon, authenticated;
grant select, update on public.join_request_received_notification_outbox
  to service_role;

create or replace function public.enqueue_join_request_received_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  notification_id uuid;
  host_user_id uuid;
  activity_title text;
  function_url text;
  webhook_secret text;
begin
  if new.status is distinct from 'pending' then
    return new;
  end if;

  select activity.host_id, activity.title
  into host_user_id, activity_title
  from public.activities as activity
  where activity.id = new.activity_id
    and activity.is_public = false;

  if host_user_id is null or host_user_id = new.user_id
    or activity_title is null then
    return new;
  end if;

  insert into public.join_request_received_notification_outbox (
    user_id, activity_id, activity_title
  ) values (
    host_user_id, new.activity_id, activity_title
  ) returning id into notification_id;

  select decrypted_secret into function_url
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_function_url'
  limit 1;

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_webhook_secret'
  limit 1;

  if function_url is null or webhook_secret is null then
    raise warning 'Join request received notification endpoint or webhook secret is not configured.';
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
        'event_type', 'join_request_received'
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'Could not queue join request received notification: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists activity_join_request_received_push
  on public.activity_participants;
create trigger activity_join_request_received_push
after insert on public.activity_participants
for each row
when (new.status = 'pending')
execute function public.enqueue_join_request_received_notification();
