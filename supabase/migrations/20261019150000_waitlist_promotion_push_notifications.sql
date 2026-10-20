-- Stores one FCM token per device. RLS keeps tokens scoped to their owner.
create table if not exists public.push_device_tokens (
  fcm_token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'android' check (platform = 'android'),
  updated_at timestamptz not null default now()
);

alter table public.push_device_tokens enable row level security;

do $$
declare
  existing_policy record;
begin
  select cmd, roles, qual, with_check
  into existing_policy
  from pg_policies
  where schemaname = 'public'
    and tablename = 'push_device_tokens'
    and policyname = 'Users manage their own push tokens';

  if found then
    -- Keep an existing waitlist policy, but fail closed if the same name was
    -- used for a policy that does not scope reads and writes to the owner.
    if existing_policy.cmd <> 'ALL'
      or not ('authenticated' = any(existing_policy.roles))
      or position('auth.uid' in lower(coalesce(existing_policy.qual, ''))) = 0
      or position('user_id' in lower(coalesce(existing_policy.qual, ''))) = 0
      or position('auth.uid' in lower(coalesce(existing_policy.with_check, ''))) = 0
      or position('user_id' in lower(coalesce(existing_policy.with_check, ''))) = 0 then
      raise exception 'Existing push token policy is not the expected owner-scoped policy.';
    end if;
  else
    create policy "Users manage their own push tokens"
    on public.push_device_tokens
    for all
    to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id);
  end if;
end;
$$;

grant select, insert, update, delete
on public.push_device_tokens to authenticated;

-- An outbox row is created only for a waitlisted -> joined transition.
-- The event id is used by the Edge Function as an idempotency key.
create table if not exists public.waitlist_promotion_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  participation_id uuid not null references public.activity_participants(id)
    on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  activity_title text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.waitlist_promotion_notification_outbox
  enable row level security;

revoke all on public.waitlist_promotion_notification_outbox
  from public, anon, authenticated;
grant select, update on public.waitlist_promotion_notification_outbox
  to service_role;
grant select, delete on public.push_device_tokens to service_role;

-- pg_net creates its own `net` schema. The notification triggers below use
-- net.http_post, so do not request the unrelated `extensions` schema here.
create extension if not exists pg_net;

create or replace function public.enqueue_waitlist_promotion_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  notification_id uuid;
  function_url text;
  webhook_secret text;
begin
  if old.status is distinct from 'waitlisted'
    or new.status is distinct from 'joined' then
    return new;
  end if;

  insert into public.waitlist_promotion_notification_outbox (
    participation_id,
    user_id,
    activity_id,
    activity_title
  )
  select
    new.id,
    new.user_id,
    activity.id,
    activity.title
  from public.activities as activity
  where activity.id = new.activity_id
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

  -- Keep promotion successful if the notification endpoint is not configured
  -- yet. The outbox row remains available for inspection.
  if function_url is null or webhook_secret is null then
    raise warning 'Waitlist push endpoint or webhook secret is not configured.';
    return new;
  end if;

  begin
    perform net.http_post(
      url := function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-waitlist-push-secret', webhook_secret
      ),
      body := jsonb_build_object('event_id', notification_id),
      timeout_milliseconds := 5000
    );
  exception when others then
    -- Notification transport must not roll back the already completed
    -- waitlist promotion. The outbox event remains recorded.
    raise warning 'Could not queue waitlist promotion notification: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists activity_participant_waitlist_push
  on public.activity_participants;

create trigger activity_participant_waitlist_push
after update of status on public.activity_participants
for each row
when (old.status = 'waitlisted' and new.status = 'joined')
execute function public.enqueue_waitlist_promotion_notification();
