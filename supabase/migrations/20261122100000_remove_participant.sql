-- Hosts can remove a joined participant from their activity before it
-- starts.
--
-- The participant's row is kept as 'rejected', marked removed_by_host_at,
-- rather than deleted, so:
--   * they're out of the count, the group chat (the chat sync trigger from
--     20261029120000_chats.sql) and their activity lists, like any
--     rejected request;
--   * they can't join the same activity again, by browsing or by code:
--     join_activity_by_code already refuses anyone with a row, and now
--     says the host removed them;
--   * the freed place goes to the waitlist through promote_eligible_waitlist,
--     as when someone leaves.
-- The removed person gets a "participant_removed" notification (push and
-- notification center).
--
-- Safe to run again.

begin;

-- ---- 1. Who was removed by the host -------------------------------------------

alter table public.activity_participants
  add column if not exists removed_by_host_at timestamptz;

-- ---- 2. Notification for the removed person -----------------------------------

create table if not exists public.participant_removed_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  activity_id uuid references public.activities (id) on delete cascade,
  activity_title text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists participant_removed_notification_outbox_user_idx
  on public.participant_removed_notification_outbox (user_id, created_at desc);

alter table public.participant_removed_notification_outbox enable row level security;
revoke all on public.participant_removed_notification_outbox
  from public, anon, authenticated;
grant select, update on public.participant_removed_notification_outbox to service_role;

-- Saves the notification and asks the push function to send it, like
-- private.queue_badge_push from 20261114200000_badges.sql.
create or replace function private.queue_participant_removed_push(
  p_user uuid,
  p_activity uuid,
  p_title text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  notification_id uuid;
  function_url text;
  webhook_secret text;
begin
  insert into public.participant_removed_notification_outbox (
    user_id, activity_id, activity_title
  ) values (
    p_user, p_activity, p_title
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
    raise warning 'Participant removed notification endpoint or webhook secret is not configured.';
    return;
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
        'event_type', 'participant_removed'
      ),
      timeout_milliseconds := 5000
    );
  exception when others then
    raise warning 'Could not queue participant removed notification: %', sqlerrm;
  end;
end;
$$;

revoke all on function private.queue_participant_removed_push(uuid, uuid, text)
  from public, anon, authenticated;

-- ---- 3. Removing a participant ------------------------------------------------

create or replace function public.remove_participant(
  requested_activity_id uuid,
  participant_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_activity public.activities%rowtype;
  removed_id uuid;
begin
  if current_user_id is null then raise exception 'You must be signed in.'; end if;

  if participant_user_id is null or participant_user_id = current_user_id then
    return jsonb_build_object('result','not_eligible',
      'message','The selected participant is no longer in this activity.');
  end if;

  -- The same locks as leave_activity: the person, then the activity.
  perform pg_advisory_xact_lock(hashtextextended(participant_user_id::text, 0));
  select * into selected_activity from public.activities
    where id = requested_activity_id for update;

  if not found then
    return jsonb_build_object('result','not_found','message','This activity was not found.');
  end if;
  if selected_activity.host_id is distinct from current_user_id then
    return jsonb_build_object('result','not_host','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,
      'message','Only the host can remove participants.');
  end if;
  if selected_activity.starts_at <= now() then
    return jsonb_build_object('result','activity_started','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','This activity has already started.');
  end if;

  update public.activity_participants
  set status = 'rejected',
      removed_by_host_at = now(),
      updated_at = now()
  where activity_id = selected_activity.id
    and user_id = participant_user_id
    and status = 'joined'
  returning id into removed_id;

  if removed_id is null then
    return jsonb_build_object('result','not_eligible','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,
      'message','The selected participant is no longer in this activity.');
  end if;

  perform public.promote_eligible_waitlist(selected_activity.id);
  perform private.queue_participant_removed_push(
    participant_user_id, selected_activity.id, selected_activity.title
  );

  return jsonb_build_object('result','removed','activity_id',selected_activity.id,
    'activity_title',selected_activity.title,
    'message','The participant was removed.');
end;
$$;

revoke all on function public.remove_participant(uuid, uuid) from public, anon;
grant execute on function public.remove_participant(uuid, uuid) to authenticated;

-- ---- 4. A removed person can't join again --------------------------------------

-- Same as 20261108110000_same_gender_activity_codes.sql, except that
-- someone the host removed is told so, instead of "Your request was
-- rejected by the host."
create or replace function public.join_activity_by_code(entered_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  selected_activity public.activities%rowtype;
  existing_status text;
  existing_removed_at timestamptz;
  resulting_status text;
  joined_participants integer;
begin
  if current_user_id is null then raise exception 'You must be signed in.'; end if;
  if entered_code is null or trim(entered_code) !~ '^[0-9]{6}$' then
    return jsonb_build_object('result','invalid_code','message','Enter a valid six-digit activity code.');
  end if;
  perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 0));
  select * into selected_activity from public.activities
  where activity_code = trim(entered_code) for update;
  -- Another gender's activity is answered as if the code didn't exist.
  if not found
      or (selected_activity.host_id <> current_user_id
        and not private.same_gender(current_user_id, selected_activity.host_id)) then
    return jsonb_build_object('result','invalid_code','message','No activity was found with this code.');
  end if;
  if public.users_blocked_either_way(current_user_id, selected_activity.host_id) then
    return jsonb_build_object('result','unavailable','message','This activity is unavailable.');
  end if;
  if selected_activity.starts_at <= now() then
    return jsonb_build_object('result','activity_started','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','This activity is no longer available to join.');
  end if;
  if selected_activity.host_id = current_user_id then
    return jsonb_build_object('result','host','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'message','You are the host of this activity.');
  end if;
  select status, removed_by_host_at into existing_status, existing_removed_at
  from public.activity_participants
  where activity_id = selected_activity.id and user_id = current_user_id;
  if existing_status is not null then
    return jsonb_build_object('result',existing_status,'activity_id',selected_activity.id,
      'activity_title',selected_activity.title,'is_public',selected_activity.is_public,
      'message',case
        when existing_status = 'joined' then 'You have already joined this activity.'
        when existing_status = 'pending' then 'Your request is waiting for host approval.'
        when existing_status = 'waitlisted' then 'You are already on the waitlist.'
        when existing_removed_at is not null then 'The host removed you from this activity.'
        else 'Your request was rejected by the host.' end);
  end if;
  if public.activity_schedule_conflicts(current_user_id, selected_activity.starts_at,
      selected_activity.ends_at, selected_activity.id) then
    return jsonb_build_object('result','time_conflict','activity_id',selected_activity.id,
      'activity_title',selected_activity.title,
      'message','You already have an activity scheduled during this time. Please choose a different date or time.');
  end if;
  if selected_activity.is_public then
    select 1 + count(*) into joined_participants from public.activity_participants
      where activity_id = selected_activity.id and status = 'joined';
    resulting_status := case when joined_participants >= selected_activity.max_participants
      then 'waitlisted' else 'joined' end;
  else
    resulting_status := 'pending';
  end if;
  insert into public.activity_participants(activity_id,user_id,status)
  values(selected_activity.id,current_user_id,resulting_status);
  return jsonb_build_object('result',resulting_status,'activity_id',selected_activity.id,
    'activity_title',selected_activity.title,'is_public',selected_activity.is_public,
    'message',case resulting_status when 'joined' then 'You joined the activity successfully.'
      when 'pending' then 'Your request was sent to the host.'
      else 'The activity is full. You were added to the waitlist.' end);
end;
$$;

-- ---- 5. Notification center ---------------------------------------------------

-- Same as 20261104120000_notification_rows.sql, plus participant_removed.
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
    union all
    select o.id, 'participant_removed', o.activity_id, o.activity_title, o.created_at, o.user_id, null
      from public.participant_removed_notification_outbox o
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
