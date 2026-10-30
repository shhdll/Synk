-- Notify the sender when their friend request is accepted. Both ways of
-- accepting (responding to the request, or sending one back) create the
-- friendship as the accepting user, so the other user in the pair is the
-- one who asked.
create table if not exists public.friend_request_accepted_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  friend_id uuid not null references public.users(id) on delete cascade,
  activity_id uuid,
  -- The new friend's name, shown like an activity title.
  activity_title text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

alter table public.friend_request_accepted_notification_outbox enable row level security;
revoke all on public.friend_request_accepted_notification_outbox
  from public, anon, authenticated;
grant select, update on public.friend_request_accepted_notification_outbox to service_role;

create or replace function public.enqueue_friend_request_accepted_notification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  accepter_id uuid := auth.uid();
  recipient_id uuid;
  accepter_name text;
  notification_id uuid;
  function_url text;
  webhook_secret text;
begin
  if accepter_id is null or accepter_id not in (new.user_a, new.user_b) then
    return new;
  end if;

  recipient_id := case when new.user_a = accepter_id then new.user_b else new.user_a end;

  select coalesce(nullif(btrim(u.full_name), ''), nullif(btrim(u.username), ''), 'Someone')
    into accepter_name
  from public.users as u
  where u.id = accepter_id;

  if accepter_name is null then
    accepter_name := 'Someone';
  end if;

  insert into public.friend_request_accepted_notification_outbox (
    user_id, friend_id, activity_title
  ) values (
    recipient_id, accepter_id, accepter_name
  )
  returning id into notification_id;

  select decrypted_secret into function_url
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_function_url'
  limit 1;

  select decrypted_secret into webhook_secret
  from vault.decrypted_secrets
  where name = 'waitlist_promotion_webhook_secret'
  limit 1;

  if function_url is null or webhook_secret is null then
    raise warning 'Friend request accepted notification endpoint or webhook secret is not configured.';
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
        'event_type', 'friend_request_accepted'
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'Could not queue friend request accepted notification: %', sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists friend_request_accepted_push on public.friendships;
create trigger friend_request_accepted_push
after insert on public.friendships
for each row
execute function public.enqueue_friend_request_accepted_notification();

revoke all on function public.enqueue_friend_request_accepted_notification()
  from public, anon, authenticated;

-- Include accepted friend requests in the signed-in user's notification center.
create or replace function public.get_my_notifications(p_limit integer default 50)
returns table (
  id uuid,
  kind text,
  activity_id uuid,
  activity_title text,
  created_at timestamptz,
  is_unread boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with me as (
    select auth.uid() as user_id,
      coalesce(
        (select u.notifications_seen_at from public.users u where u.id = auth.uid()),
        '-infinity'::timestamptz
      ) as seen_at
  ),
  items as (
    select o.id, 'waitlist_promotion' as kind, o.activity_id, o.activity_title, o.created_at, o.user_id
      from public.waitlist_promotion_notification_outbox o
    union all
    select o.id, 'activity_updated', o.activity_id, o.activity_title, o.created_at, o.user_id
      from public.activity_update_notification_outbox o
    union all
    select o.id, 'activity_deleted', o.activity_id, o.activity_title, o.created_at, o.user_id
      from public.activity_deleted_notification_outbox o
    union all
    select o.id, 'join_request_accepted', o.activity_id, o.activity_title, o.created_at, o.user_id
      from public.join_request_accepted_notification_outbox o
    union all
    select o.id, 'join_request_rejected', o.activity_id, o.activity_title, o.created_at, o.user_id
      from public.join_request_rejected_notification_outbox o
    union all
    select o.id, 'join_request_received', o.activity_id, o.activity_title, o.created_at, o.user_id
      from public.join_request_received_notification_outbox o
    union all
    select o.id, 'host_assigned', o.activity_id, o.activity_title, o.created_at, o.user_id
      from public.host_transfer_notification_outbox o
    union all
    select o.id, 'activity_conflict', o.activity_id, o.activity_title, o.created_at, o.user_id
      from public.activity_conflict_notification_outbox o
      where o.status <> 'cancelled'
    union all
    select o.id, 'activity_full', o.activity_id, o.activity_title, o.created_at, o.user_id
      from public.activity_full_notification_outbox o
    union all
    select o.id, 'friend_request_received', null::uuid, o.activity_title, o.created_at, o.user_id
      from public.friend_request_notification_outbox o
    union all
    select o.id, 'friend_request_accepted', null::uuid, o.activity_title, o.created_at, o.user_id
      from public.friend_request_accepted_notification_outbox o
  )
  select i.id, i.kind, i.activity_id, i.activity_title, i.created_at,
    i.created_at > me.seen_at as is_unread
  from items i, me
  where i.user_id = me.user_id
    and i.created_at > now() - interval '30 days'
  order by i.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;
