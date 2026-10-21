-- An edit can create a conflict for someone who is committed to the other
-- activity, even when that person has not joined the activity being edited.
-- Reconcile those external commitments and notify them as well.
create or replace function public.refresh_external_activity_schedule_conflicts()
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
    select distinct impacts.user_id
    from (
      select activity.host_id as user_id
      from public.activities activity
      where activity.id <> new.id and activity.ends_at > now()
        and (public.activity_intervals_overlap(
          old.starts_at, old.ends_at, activity.starts_at, activity.ends_at
        ) or public.activity_intervals_overlap(
          new.starts_at, new.ends_at, activity.starts_at, activity.ends_at
        ))
      union
      select participant.user_id
      from public.activity_participants participant
      join public.activities activity on activity.id = participant.activity_id
      where activity.id <> new.id and activity.ends_at > now()
        and participant.status = 'joined'
        and (public.activity_intervals_overlap(
          old.starts_at, old.ends_at, activity.starts_at, activity.ends_at
        ) or public.activity_intervals_overlap(
          new.starts_at, new.ends_at, activity.starts_at, activity.ends_at
        ))
      union
      select conflict.user_id
      from public.activity_schedule_conflicts conflict
      where conflict.status = 'unresolved'
        and new.id in (conflict.first_activity_id, conflict.second_activity_id)
    ) impacts
    where impacts.user_id is not null
      and impacts.user_id is distinct from new.host_id
      and not exists (
        select 1 from public.activity_participants participant
        where participant.activity_id = new.id
          and participant.user_id = impacts.user_id
          and participant.status = 'joined'
      )
  loop
    perform pg_advisory_xact_lock(hashtextextended(affected_user.user_id::text, 0));

    for other_activity in
      select activity.id
      from public.activities activity
      where activity.id <> new.id and activity.ends_at > now()
        and public.activity_intervals_overlap(
          new.starts_at, new.ends_at, activity.starts_at, activity.ends_at
        )
        and (activity.host_id = affected_user.user_id or exists (
          select 1 from public.activity_participants participant
          where participant.activity_id = activity.id
            and participant.user_id = affected_user.user_id
            and participant.status = 'joined'
        ))
    loop
      first_id := least(new.id, other_activity.id);
      second_id := greatest(new.id, other_activity.id);
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

    update public.activity_schedule_conflicts conflict
    set status = 'cleared', updated_at = now(), resolved_at = now()
    where conflict.user_id = affected_user.user_id
      and conflict.status = 'unresolved'
      and new.id in (conflict.first_activity_id, conflict.second_activity_id)
      and not exists (
        select 1
        from public.activities first_activity
        join public.activities second_activity
          on second_activity.id = conflict.second_activity_id
        where first_activity.id = conflict.first_activity_id
          and first_activity.ends_at > now() and second_activity.ends_at > now()
          and public.activity_intervals_overlap(
            first_activity.starts_at, first_activity.ends_at,
            second_activity.starts_at, second_activity.ends_at
          )
          and (first_activity.host_id = affected_user.user_id or exists (
            select 1 from public.activity_participants participant
            where participant.activity_id = first_activity.id
              and participant.user_id = affected_user.user_id
              and participant.status = 'joined'
          ))
          and (second_activity.host_id = affected_user.user_id or exists (
            select 1 from public.activity_participants participant
            where participant.activity_id = second_activity.id
              and participant.user_id = affected_user.user_id
              and participant.status = 'joined'
          ))
      );

    update public.activity_conflict_notification_outbox outbox
    set status = 'cancelled', processed_at = now()
    where outbox.status = 'pending'
      and outbox.conflict_id in (
        select conflict.id from public.activity_schedule_conflicts conflict
        where conflict.user_id = affected_user.user_id
          and conflict.status = 'cleared'
          and new.id in (conflict.first_activity_id, conflict.second_activity_id)
      );
  end loop;

  return new;
end;
$$;

drop trigger if exists activity_schedule_conflicts_external_refresh on public.activities;
create trigger activity_schedule_conflicts_external_refresh
after update of starts_at, ends_at, host_id on public.activities
for each row execute function public.refresh_external_activity_schedule_conflicts();

revoke all on function public.refresh_external_activity_schedule_conflicts() from public;
