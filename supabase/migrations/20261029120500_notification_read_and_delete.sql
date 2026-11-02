-- Per-notification read and delete state for the notification center.
--
-- Notifications live in the outbox tables, which users can't write to, so
-- each user's read and deleted marks are kept here by notification id.
-- users.notifications_seen_at still marks everything up to a time as read
-- ("Mark all read").

create table if not exists public.notification_states (
  user_id uuid not null references public.users (id) on delete cascade,
  notification_id uuid not null,
  read_at timestamptz,
  deleted_at timestamptz,
  primary key (user_id, notification_id)
);

alter table public.notification_states enable row level security;
revoke all on public.notification_states from public, anon, authenticated;

create or replace function public.mark_notification_read(p_notification_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notification_states (user_id, notification_id, read_at)
  select auth.uid(), p_notification_id, now()
  where auth.uid() is not null
  on conflict (user_id, notification_id)
    do update set read_at = coalesce(public.notification_states.read_at, now());
$$;

create or replace function public.delete_notification(p_notification_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notification_states (user_id, notification_id, deleted_at)
  select auth.uid(), p_notification_id, now()
  where auth.uid() is not null
  on conflict (user_id, notification_id)
    do update set deleted_at = now();
$$;

revoke all on function public.mark_notification_read(uuid) from public, anon;
revoke all on function public.delete_notification(uuid) from public, anon;
grant execute on function public.mark_notification_read(uuid) to authenticated;
grant execute on function public.delete_notification(uuid) to authenticated;

-- Same sources as before; deleted notifications are left out, and one read
-- on its own no longer counts as unread.
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
    i.created_at > me.seen_at and s.read_at is null as is_unread
  from items i
  cross join me
  left join public.notification_states s
    on s.user_id = me.user_id and s.notification_id = i.id
  where i.user_id = me.user_id
    and i.created_at > now() - interval '30 days'
    and s.deleted_at is null
  order by i.created_at desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;
