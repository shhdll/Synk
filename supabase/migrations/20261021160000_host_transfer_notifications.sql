create table if not exists public.host_transfer_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  activity_title text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.host_transfer_notification_outbox enable row level security;
revoke all on public.host_transfer_notification_outbox from public, anon, authenticated;
grant select, update on public.host_transfer_notification_outbox to service_role;

create or replace function public.enqueue_host_transfer_notification()
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
  if old.host_id is not distinct from new.host_id then return new; end if;
  insert into public.host_transfer_notification_outbox(user_id, activity_id, activity_title)
  values(new.host_id, new.id, new.title)
  returning id into event_id;

  select decrypted_secret into function_url from vault.decrypted_secrets
    where name = 'waitlist_promotion_function_url' limit 1;
  select decrypted_secret into webhook_secret from vault.decrypted_secrets
    where name = 'waitlist_promotion_webhook_secret' limit 1;
  if function_url is null or webhook_secret is null then
    raise warning 'Host transfer push endpoint or webhook secret is not configured.';
    return new;
  end if;
  begin
    perform net.http_post(
      url := function_url,
      headers := jsonb_build_object('Content-Type','application/json',
        'x-waitlist-push-secret',webhook_secret),
      body := jsonb_build_object('event_id',event_id,'event_type','host_assigned'),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'Could not queue host transfer notification: %', sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists activity_host_transfer_push on public.activities;
create trigger activity_host_transfer_push
after update of host_id on public.activities
for each row when (old.host_id is distinct from new.host_id)
execute function public.enqueue_host_transfer_notification();
