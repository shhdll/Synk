-- Notify the host when their activity reaches its participant limit. The host
-- counts as the first participant, so the activity is full once
-- 1 + joined participants reaches max_participants. Each host is told at most
-- once per activity, so a leave followed by a waitlist promotion does not
-- send it again.
create table if not exists public.activity_full_notification_outbox (
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

alter table public.activity_full_notification_outbox enable row level security;
revoke all on public.activity_full_notification_outbox
  from public, anon, authenticated;
grant select, update on public.activity_full_notification_outbox
  to service_role;

create or replace function public.enqueue_activity_full_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  notification_id uuid;
  host_user_id uuid;
  activity_title text;
  capacity integer;
  joined_count integer;
  function_url text;
  webhook_secret text;
begin
  if tg_op = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;

  select activity.host_id, activity.title, activity.max_participants
  into host_user_id, activity_title, capacity
  from public.activities as activity
  where activity.id = new.activity_id;

  if host_user_id is null or activity_title is null or capacity is null then
    return new;
  end if;

  select count(*) into joined_count
  from public.activity_participants as participant
  where participant.activity_id = new.activity_id
    and participant.status = 'joined'
    and participant.user_id <> host_user_id;

  if 1 + joined_count < capacity then
    return new;
  end if;

  insert into public.activity_full_notification_outbox (
    user_id, activity_id, activity_title
  ) values (
    host_user_id, new.activity_id, activity_title
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
    -- The join must succeed even when push delivery is unavailable.
    raise warning 'Could not queue activity full notification: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists activity_full_push on public.activity_participants;
create trigger activity_full_push
after insert or update of status on public.activity_participants
for each row
when (new.status = 'joined')
execute function public.enqueue_activity_full_notification();

-- List the new notification in the notification center.
CREATE OR REPLACE FUNCTION public.get_my_notifications(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  kind text,
  activity_id uuid,
  activity_title text,
  created_at timestamptz,
  is_unread boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH me AS (
    SELECT auth.uid() AS user_id,
      coalesce(
        (SELECT u.notifications_seen_at FROM public.users u WHERE u.id = auth.uid()),
        '-infinity'::timestamptz
      ) AS seen_at
  ),
  items AS (
    SELECT o.id, 'waitlist_promotion' AS kind, o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.waitlist_promotion_notification_outbox o
    UNION ALL
    SELECT o.id, 'activity_updated', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.activity_update_notification_outbox o
    UNION ALL
    SELECT o.id, 'activity_deleted', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.activity_deleted_notification_outbox o
    UNION ALL
    SELECT o.id, 'join_request_accepted', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.join_request_accepted_notification_outbox o
    UNION ALL
    SELECT o.id, 'join_request_rejected', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.join_request_rejected_notification_outbox o
    UNION ALL
    SELECT o.id, 'join_request_received', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.join_request_received_notification_outbox o
    UNION ALL
    SELECT o.id, 'host_assigned', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.host_transfer_notification_outbox o
    UNION ALL
    SELECT o.id, 'activity_conflict', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.activity_conflict_notification_outbox o
      WHERE o.status <> 'cancelled'
    UNION ALL
    SELECT o.id, 'activity_full', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.activity_full_notification_outbox o
  )
  SELECT i.id, i.kind, i.activity_id, i.activity_title, i.created_at,
    i.created_at > me.seen_at AS is_unread
  FROM items i, me
  WHERE i.user_id = me.user_id
    AND i.created_at > now() - interval '30 days'
  ORDER BY i.created_at DESC
  LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
$$;
