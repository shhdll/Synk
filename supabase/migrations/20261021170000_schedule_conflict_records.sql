-- Keep schedule conflicts available to users after a push is missed. A row is
-- one unordered pair of confirmed activities for one user.
create table if not exists public.activity_schedule_conflicts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  first_activity_id uuid not null references public.activities(id) on delete cascade,
  second_activity_id uuid not null references public.activities(id) on delete cascade,
  changed_activity_id uuid references public.activities(id) on delete cascade,
  status text not null default 'unresolved'
    check (status in ('unresolved', 'resolved', 'cleared')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  constraint activity_schedule_conflicts_pair_key
    unique (user_id, first_activity_id, second_activity_id),
  constraint activity_schedule_conflicts_ordered_pair
    check (first_activity_id < second_activity_id)
);

alter table public.activity_schedule_conflicts enable row level security;
drop policy if exists "Users can read their schedule conflicts"
  on public.activity_schedule_conflicts;
create policy "Users can read their schedule conflicts"
  on public.activity_schedule_conflicts for select to authenticated
  using ((select auth.uid()) = user_id);
grant select on public.activity_schedule_conflicts to authenticated;
revoke insert, update, delete on public.activity_schedule_conflicts from public, anon, authenticated;

-- Preserve legacy confirmed overlaps as unresolved records so no existing
-- participant loses their place while the app surfaces the conflict.
with commitments as (
  select activity.host_id as user_id, activity.id as activity_id
  from public.activities activity
  where activity.ends_at > now()
  union
  select participant.user_id, activity.id
  from public.activity_participants participant
  join public.activities activity on activity.id=participant.activity_id
  where participant.status='joined' and activity.ends_at>now()
), overlap_pairs as (
  select distinct first_commitment.user_id,
    first_commitment.activity_id as first_id,
    second_commitment.activity_id as second_id
  from commitments first_commitment
  join commitments second_commitment
    on second_commitment.user_id=first_commitment.user_id
    and first_commitment.activity_id<second_commitment.activity_id
  join public.activities first_activity on first_activity.id=first_commitment.activity_id
  join public.activities second_activity on second_activity.id=second_commitment.activity_id
  where public.activity_intervals_overlap(first_activity.starts_at,first_activity.ends_at,
    second_activity.starts_at,second_activity.ends_at)
)
insert into public.activity_schedule_conflicts(
  user_id,first_activity_id,second_activity_id,changed_activity_id,status
)
select user_id,first_id,second_id,null,'unresolved' from overlap_pairs
on conflict (user_id,first_activity_id,second_activity_id) do nothing;

create or replace function public.refresh_activity_schedule_conflicts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected_user record;
  other_activity record;
  first_id uuid;
  second_id uuid;
begin
  if old.starts_at is not distinct from new.starts_at
    and old.ends_at is not distinct from new.ends_at
    and old.host_id is not distinct from new.host_id then
    return new;
  end if;

  for affected_user in
    select new.host_id as user_id
    union
    select old.host_id where old.host_id is distinct from new.host_id
    union
    select participant.user_id
    from public.activity_participants participant
    where participant.activity_id = new.id and participant.status = 'joined'
  loop
    perform pg_advisory_xact_lock(hashtextextended(affected_user.user_id::text, 0));
    -- Recalculate pairs involving this activity. Existing memberships stay
    -- confirmed until the user resolves the conflict.
    for other_activity in
      select activity.id, activity.starts_at, activity.ends_at, activity.host_id
      from public.activities activity
      where activity.id <> new.id
        and activity.ends_at > now()
        and public.activity_intervals_overlap(
          new.starts_at, new.ends_at, activity.starts_at, activity.ends_at
        )
        and (
          activity.host_id = affected_user.user_id
          or exists (
            select 1 from public.activity_participants participant
            where participant.activity_id = activity.id
              and participant.user_id = affected_user.user_id
              and participant.status = 'joined'
          )
        )
    loop
      first_id := least(new.id, other_activity.id);
      second_id := greatest(new.id, other_activity.id);
      update public.activity_conflict_notification_outbox outbox
      set status='cancelled', processed_at=now()
      where outbox.conflict_id = (
        select conflict.id from public.activity_schedule_conflicts conflict
        where conflict.user_id=affected_user.user_id
          and conflict.first_activity_id=first_id
          and conflict.second_activity_id=second_id
      ) and outbox.status='pending';
      insert into public.activity_schedule_conflicts(
        user_id, first_activity_id, second_activity_id, changed_activity_id,
        status, updated_at, resolved_at
      ) values (
        affected_user.user_id, first_id, second_id, new.id, 'unresolved', now(), null
      )
      on conflict (user_id, first_activity_id, second_activity_id)
      do update set changed_activity_id = excluded.changed_activity_id,
        status = 'unresolved', updated_at = now(), resolved_at = null;
    end loop;

    -- Clear records whose overlap disappeared after this edit, or where one
    -- of the memberships has since ended.
    update public.activity_schedule_conflicts conflict
    set status = 'cleared', updated_at = now(), resolved_at = now()
    where conflict.user_id = affected_user.user_id
      and conflict.status = 'unresolved'
      and new.id in (conflict.first_activity_id, conflict.second_activity_id)
      and not exists (
        select 1
        from public.activities first_activity
        join public.activities second_activity on second_activity.id =
          case when conflict.first_activity_id = new.id
            then conflict.second_activity_id else conflict.first_activity_id end
        where first_activity.id = new.id
          and first_activity.ends_at > now()
          and second_activity.ends_at > now()
          and public.activity_intervals_overlap(
            first_activity.starts_at, first_activity.ends_at,
            second_activity.starts_at, second_activity.ends_at
          )
          and (
            first_activity.host_id = affected_user.user_id
            or exists (select 1 from public.activity_participants p
              where p.activity_id = first_activity.id
                and p.user_id = affected_user.user_id and p.status = 'joined')
          )
          and (
            second_activity.host_id = affected_user.user_id
            or exists (select 1 from public.activity_participants p
              where p.activity_id = second_activity.id
                and p.user_id = affected_user.user_id and p.status = 'joined')
          )
      );
    update public.activity_conflict_notification_outbox outbox
    set status='cancelled', processed_at=now()
    where outbox.status='pending' and outbox.conflict_id in (
      select conflict.id from public.activity_schedule_conflicts conflict
      where conflict.user_id=affected_user.user_id and conflict.status='cleared'
        and new.id in (conflict.first_activity_id, conflict.second_activity_id)
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists activity_schedule_conflicts_refresh on public.activities;
create trigger activity_schedule_conflicts_refresh
after update of starts_at, ends_at, host_id on public.activities
for each row execute function public.refresh_activity_schedule_conflicts();

create or replace function public.clear_departed_schedule_conflicts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' then
    if old.status <> 'joined' or new.status = 'joined' then return new; end if;
  elsif old.status <> 'joined' then
    return old;
  end if;
  update public.activity_schedule_conflicts conflict
  set status='cleared', updated_at=now(), resolved_at=now()
  where conflict.user_id=old.user_id and conflict.status='unresolved'
    and old.activity_id in (conflict.first_activity_id, conflict.second_activity_id);
  update public.activity_conflict_notification_outbox outbox
  set status='cancelled', processed_at=now()
  where outbox.status='pending' and outbox.conflict_id in (
    select conflict.id from public.activity_schedule_conflicts conflict
    where conflict.user_id=old.user_id and conflict.status='cleared'
      and old.activity_id in (conflict.first_activity_id, conflict.second_activity_id)
  );
  return new;
end;
$$;
drop trigger if exists activity_schedule_conflicts_clear_departed on public.activity_participants;
create trigger activity_schedule_conflicts_clear_departed
after delete or update of status on public.activity_participants
for each row execute function public.clear_departed_schedule_conflicts();

create or replace function public.get_my_schedule_conflicts()
returns table (
  conflict_id uuid,
  first_activity_id uuid,
  first_title text,
  first_starts_at timestamptz,
  first_ends_at timestamptz,
  first_is_host boolean,
  second_activity_id uuid,
  second_title text,
  second_starts_at timestamptz,
  second_ends_at timestamptz,
  second_is_host boolean,
  changed_activity_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.id,
    first_activity.id, first_activity.title, first_activity.starts_at,
    first_activity.ends_at, first_activity.host_id = auth.uid(),
    second_activity.id, second_activity.title, second_activity.starts_at,
    second_activity.ends_at, second_activity.host_id = auth.uid(),
    c.changed_activity_id
  from public.activity_schedule_conflicts c
  join public.activities first_activity on first_activity.id = c.first_activity_id
  join public.activities second_activity on second_activity.id = c.second_activity_id
  where c.user_id = auth.uid() and c.status = 'unresolved'
  order by first_activity.starts_at, second_activity.starts_at;
$$;
revoke all on function public.get_my_schedule_conflicts() from public;
grant execute on function public.get_my_schedule_conflicts() to authenticated;

create table if not exists public.activity_conflict_notification_outbox (
  id uuid primary key default gen_random_uuid(),
  conflict_id uuid not null references public.activity_schedule_conflicts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  activity_title text not null,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'no_tokens', 'failed', 'cancelled')),
  created_at timestamptz not null default now(),
  processed_at timestamptz
);
alter table public.activity_conflict_notification_outbox enable row level security;
revoke all on public.activity_conflict_notification_outbox from public, anon, authenticated;
grant select, update on public.activity_conflict_notification_outbox to service_role;

create or replace function public.enqueue_activity_conflict_notification()
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
  if new.status <> 'unresolved' then return new; end if;
  if tg_op='UPDATE' then
    if new.updated_at=old.updated_at then return new; end if;
  end if;
  insert into public.activity_conflict_notification_outbox(
    conflict_id,user_id,activity_id,activity_title
  ) select new.id,new.user_id,activity.id,activity.title
    from public.activities activity where activity.id=new.changed_activity_id
  returning id into event_id;
  if event_id is null then return new; end if;
  select decrypted_secret into function_url from vault.decrypted_secrets
    where name='waitlist_promotion_function_url' limit 1;
  select decrypted_secret into webhook_secret from vault.decrypted_secrets
    where name='waitlist_promotion_webhook_secret' limit 1;
  if function_url is null or webhook_secret is null then
    raise warning 'Schedule conflict push endpoint or webhook secret is not configured.';
    return new;
  end if;
  begin
    perform net.http_post(url:=function_url,
      headers:=jsonb_build_object('Content-Type','application/json',
        'x-waitlist-push-secret',webhook_secret),
      body:=jsonb_build_object('event_id',event_id,'event_type','activity_conflict'),
      timeout_milliseconds:=5000);
  exception when others then
    raise warning 'Could not queue schedule conflict notification: %',sqlerrm;
  end;
  return new;
end;
$$;
drop trigger if exists activity_conflict_push on public.activity_schedule_conflicts;
create trigger activity_conflict_push
after insert or update of status, updated_at on public.activity_schedule_conflicts
for each row execute function public.enqueue_activity_conflict_notification();

-- A participant with a newly detected conflict receives the specific conflict
-- notification instead of both a generic update and a conflict push.
alter table public.activity_update_notification_outbox
  add column if not exists schedule_changed boolean not null default false;

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
    and old.ends_at is not distinct from new.ends_at
    and old.location_name is not distinct from new.location_name
    and old.location_address is not distinct from new.location_address
    and old.latitude is not distinct from new.latitude
    and old.longitude is not distinct from new.longitude
    and old.max_participants is not distinct from new.max_participants
    and old.is_public is not distinct from new.is_public
    and old.photo_url is not distinct from new.photo_url then
    return new;
  end if;

  select decrypted_secret into function_url from vault.decrypted_secrets
    where name='waitlist_promotion_function_url' limit 1;
  select decrypted_secret into webhook_secret from vault.decrypted_secrets
    where name='waitlist_promotion_webhook_secret' limit 1;
  for recipient in
    select participant.user_id
    from public.activity_participants participant
    where participant.activity_id=new.id
      and participant.status='joined' and participant.user_id<>new.host_id
      and (
        (old.starts_at is not distinct from new.starts_at
          and old.ends_at is not distinct from new.ends_at)
        or not public.activity_schedule_conflicts(
          participant.user_id,new.starts_at,new.ends_at,new.id
        )
      )
  loop
    insert into public.activity_update_notification_outbox(
      user_id,activity_id,activity_title,schedule_changed
    ) values(recipient.user_id,new.id,new.title,
      old.starts_at is distinct from new.starts_at
        or old.ends_at is distinct from new.ends_at)
      returning id into notification_id;
    if function_url is null or webhook_secret is null then
      raise warning 'Activity update push endpoint or webhook secret is not configured.';
      continue;
    end if;
    begin
      perform net.http_post(url:=function_url,
        headers:=jsonb_build_object('Content-Type','application/json',
          'x-waitlist-push-secret',webhook_secret),
        body:=jsonb_build_object('event_id',notification_id,'event_type','activity_updated'),
        timeout_milliseconds:=5000);
    exception when others then
      raise warning 'Could not queue activity update notification: %',sqlerrm;
    end;
  end loop;
  return new;
end;
$$;

-- Resolve the active conflict group atomically. Non-conflicting commitments
-- remain, selected activities are revalidated, and a host must transfer
-- ownership before choosing to leave an activity they host.
create or replace function public.resolve_my_schedule_conflicts(keep_activity_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  conflict_activity_ids uuid[];
  keep_ids uuid[] := coalesce(keep_activity_ids, array[]::uuid[]);
  activity_id uuid;
  conflict_count integer;
begin
  if current_user_id is null then raise exception 'You must be signed in.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(current_user_id::text, 0));
  perform 1 from public.activity_schedule_conflicts
    where user_id=current_user_id and status='unresolved' for update;
  select array_agg(distinct ids.activity_id) into conflict_activity_ids
  from public.activity_schedule_conflicts c
  cross join lateral (values (c.first_activity_id), (c.second_activity_id)) ids(activity_id)
  where c.user_id=current_user_id and c.status='unresolved';
  if conflict_activity_ids is null then
    return jsonb_build_object('result','no_conflicts','message','There are no unresolved schedule conflicts.');
  end if;
  if not keep_ids <@ conflict_activity_ids then
    return jsonb_build_object('result','invalid_selection','message','Choose from the activities in your current conflicts.');
  end if;
  if cardinality(keep_ids)=0 then
    return jsonb_build_object('result','invalid_selection','message','Choose at least one activity to keep.');
  end if;
  if exists (
    select 1 from public.activities activity
    where activity.id=any(conflict_activity_ids)
      and activity.host_id=current_user_id
      and activity.id <> all(keep_ids)
  ) then
    return jsonb_build_object('result','host_transfer_required',
      'message','Transfer hosting before leaving an activity you host.');
  end if;
  if exists (
    select 1 from public.activities kept
    join public.activities other on other.id<>kept.id and other.ends_at>now()
      and public.activity_intervals_overlap(kept.starts_at,kept.ends_at,other.starts_at,other.ends_at)
    where kept.id=any(keep_ids) and kept.ends_at>now()
      and (kept.host_id=current_user_id or exists (
        select 1 from public.activity_participants kp
        where kp.activity_id=kept.id and kp.user_id=current_user_id and kp.status='joined'
      ))
      and (other.host_id=current_user_id or exists (
        select 1 from public.activity_participants op
        where op.activity_id=other.id and op.user_id=current_user_id and op.status='joined'
      ))
      and (other.id=any(keep_ids) or other.id <> all(conflict_activity_ids))
  ) then
    return jsonb_build_object('result','still_conflicting',
      'message','Your selected activities still overlap another confirmed activity.');
  end if;

  foreach activity_id in array conflict_activity_ids loop
    if not activity_id=any(keep_ids) then
      delete from public.activity_participants
      where activity_participants.activity_id=activity_id
        and user_id=current_user_id and status='joined';
      perform public.promote_eligible_waitlist(activity_id);
    end if;
  end loop;
  update public.activity_schedule_conflicts set status='resolved',
    updated_at=now(), resolved_at=now()
  where user_id=current_user_id and status='unresolved';
  update public.activity_conflict_notification_outbox outbox
  set status='cancelled', processed_at=now()
  where outbox.user_id=current_user_id and outbox.status='pending'
    and outbox.conflict_id in (
      select conflict.id from public.activity_schedule_conflicts conflict
      where conflict.user_id=current_user_id and conflict.status='resolved'
    );
  return jsonb_build_object('result','resolved','message','Your schedule conflicts were resolved.');
end;
$$;
revoke all on function public.resolve_my_schedule_conflicts(uuid[]) from public;
grant execute on function public.resolve_my_schedule_conflicts(uuid[]) to authenticated;

revoke all on function public.promote_eligible_waitlist(uuid) from public, anon, authenticated;
