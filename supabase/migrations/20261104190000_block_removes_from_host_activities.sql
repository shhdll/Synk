-- Blocking the host of an activity you're in, or a person in your activity.
--
-- When a block is made between an activity's host and someone who is
-- joined, pending or waitlisted in it, that person is taken out of the
-- activity in the same transaction as the block, whoever made it:
--   * their activity_participants row is deleted, as when leaving, so they
--     are out of the count and the group chat (the chat sync trigger from
--     20261029120000_chats.sql does that);
--   * a joined place that frees up goes to the waitlist through
--     promote_eligible_waitlist, as when leaving, with its notifications.
-- Only activities that haven't ended, so past activities, ratings and
-- history stay. Unblocking doesn't bring anything back; they join again.
-- Two people who are both just participants of someone else's activity
-- both stay (20261104170000_block_activities.sql redacts them instead).
--
-- Safe to run again.

begin;

-- Same as 20261028200000_friends.sql, plus taking the non-host out of the
-- activities between the two.
create or replace function public.block_user(target_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  removal record;
  removed_status text;
  removed_count integer := 0;
begin
  if target_user_id = me then
    return jsonb_build_object('result', 'self');
  end if;

  if not exists (select 1 from public.users where id = target_user_id) then
    return jsonb_build_object('result', 'not_found');
  end if;

  perform public.lock_user_pair(me, target_user_id);

  delete from public.friendships
  where user_a = least(me, target_user_id) and user_b = greatest(me, target_user_id);

  delete from public.friend_requests
  where (sender_id = me and receiver_id = target_user_id)
     or (sender_id = target_user_id and receiver_id = me);

  insert into public.user_blocks (blocker_id, blocked_id)
  values (me, target_user_id)
  on conflict do nothing;

  -- In activity order, so two blocks at once lock activities in the
  -- same order.
  for removal in
    select ap.id, ap.activity_id, ap.user_id, a.starts_at
    from public.activity_participants ap
    join public.activities a on a.id = ap.activity_id
    where a.ends_at > now()
      and ap.status in ('joined', 'pending', 'waitlisted')
      and (
        (a.host_id = me and ap.user_id = target_user_id)
        or (a.host_id = target_user_id and ap.user_id = me)
      )
    order by ap.activity_id
  loop
    -- The same locks as leave_activity: the person, then the activity.
    perform pg_advisory_xact_lock(hashtextextended(removal.user_id::text, 0));
    perform 1 from public.activities where id = removal.activity_id for update;

    removed_status := null;
    delete from public.activity_participants
    where id = removal.id and status in ('joined', 'pending', 'waitlisted')
    returning status into removed_status;

    if removed_status is not null then
      removed_count := removed_count + 1;
    end if;

    -- A place freed up before the start goes to the waitlist, as when
    -- someone leaves (leaving isn't possible after the start).
    if removed_status = 'joined' and removal.starts_at > now() then
      perform public.promote_eligible_waitlist(removal.activity_id);
    end if;
  end loop;

  return jsonb_build_object(
    'result', 'blocked',
    'removed_from_activities', removed_count
  );
end;
$$;

revoke all on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;

-- For the confirmation before blocking: does target_user_id host an
-- activity the signed-in user is in that blocking would take them out of?
-- Only about the signed-in user's own activities.
create or replace function public.block_removes_me_from_activity(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.activity_participants ap
    join public.activities a on a.id = ap.activity_id
    where ap.user_id = auth.uid()
      and a.host_id = target_user_id
      and a.ends_at > now()
      and ap.status in ('joined', 'pending', 'waitlisted')
  );
$$;

revoke all on function public.block_removes_me_from_activity(uuid) from public, anon;
grant execute on function public.block_removes_me_from_activity(uuid) to authenticated;

commit;
