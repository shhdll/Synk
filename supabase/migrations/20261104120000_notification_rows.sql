-- Notification rows show the activity photo and let the host accept or
-- decline a join request right from the list.
begin;

-- Which request a "join request received" notification is about.
alter table public.join_request_received_notification_outbox
  add column if not exists participation_id uuid;

-- Older rows: the notification is written in the same transaction as the
-- request, so their times match. Only filled in when exactly one request
-- matches, so Accept never acts on the wrong person.
update public.join_request_received_notification_outbox o
set participation_id = m.id
from (
  select o2.id as notification_id, min(p.id::text)::uuid as id
  from public.join_request_received_notification_outbox o2
  join public.activity_participants p
    on p.activity_id = o2.activity_id
   and abs(extract(epoch from (p.created_at - o2.created_at))) < 5
  where o2.participation_id is null
  group by o2.id
  having count(*) = 1
) m
where o.id = m.notification_id;

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
    user_id, activity_id, activity_title, participation_id
  ) values (
    host_user_id, new.activity_id, activity_title, new.id
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

-- Same list, plus the activity photo and category, and for join requests
-- the request and whether it still waits for an answer.
drop function if exists public.get_my_notifications(integer);

create function public.get_my_notifications(p_limit integer default 50)
returns table (
  id uuid,
  kind text,
  activity_id uuid,
  activity_title text,
  created_at timestamptz,
  is_unread boolean,
  activity_photo_url text,
  activity_category_label text,
  participation_id uuid,
  request_pending boolean
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
    select o.id, 'waitlist_promotion' as kind, o.activity_id, o.activity_title, o.created_at, o.user_id, null::uuid as participation_id
      from public.waitlist_promotion_notification_outbox o
    union all
    select o.id, 'activity_updated', o.activity_id, o.activity_title, o.created_at, o.user_id, null
      from public.activity_update_notification_outbox o
    union all
    select o.id, 'activity_deleted', o.activity_id, o.activity_title, o.created_at, o.user_id, null
      from public.activity_deleted_notification_outbox o
    union all
    select o.id, 'join_request_accepted', o.activity_id, o.activity_title, o.created_at, o.user_id, null
      from public.join_request_accepted_notification_outbox o
    union all
    select o.id, 'join_request_rejected', o.activity_id, o.activity_title, o.created_at, o.user_id, null
      from public.join_request_rejected_notification_outbox o
    union all
    select o.id, 'join_request_received', o.activity_id, o.activity_title, o.created_at, o.user_id, o.participation_id
      from public.join_request_received_notification_outbox o
    union all
    select o.id, 'host_assigned', o.activity_id, o.activity_title, o.created_at, o.user_id, null
      from public.host_transfer_notification_outbox o
    union all
    select o.id, 'activity_conflict', o.activity_id, o.activity_title, o.created_at, o.user_id, null
      from public.activity_conflict_notification_outbox o
      where o.status <> 'cancelled'
    union all
    select o.id, 'activity_full', o.activity_id, o.activity_title, o.created_at, o.user_id, null
      from public.activity_full_notification_outbox o
    union all
    select o.id, 'friend_request_received', null::uuid, o.activity_title, o.created_at, o.user_id, null
      from public.friend_request_notification_outbox o
    union all
    select o.id, 'friend_request_accepted', null::uuid, o.activity_title, o.created_at, o.user_id, null
      from public.friend_request_accepted_notification_outbox o
    union all
    select o.id, 'activity_reminder', o.activity_id, o.activity_title, o.created_at, o.user_id, null
      from public.activity_reminder_notification_outbox o
  )
  select i.id, i.kind, i.activity_id, i.activity_title, i.created_at,
    i.created_at > me.seen_at and s.read_at is null as is_unread,
    a.photo_url,
    a.category_label,
    i.participation_id,
    i.kind = 'join_request_received' and exists (
      select 1 from public.activity_participants p
      where p.id = i.participation_id and p.status = 'pending'
    ) as request_pending
  from items i
  cross join me
  left join public.notification_states s
    on s.user_id = me.user_id and s.notification_id = i.id
  left join public.activities a on a.id = i.activity_id
  where i.user_id = me.user_id
    and i.created_at > now() - interval '30 days'
    and s.deleted_at is null
  order by i.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke execute on function public.get_my_notifications(integer) from public, anon;
grant execute on function public.get_my_notifications(integer) to authenticated;

commit;
