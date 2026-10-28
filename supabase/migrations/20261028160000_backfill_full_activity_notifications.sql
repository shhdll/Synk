-- Catch up current participants of upcoming activities that became full before
-- the all-participants notification trigger was installed.
do $$
declare
  full_activity record;
begin
  for full_activity in
    select activity.id
    from public.activities as activity
    where activity.starts_at > now()
      and 1 + (
        select count(*)
        from public.activity_participants as participant
        where participant.activity_id = activity.id
          and participant.status = 'joined'
          and participant.user_id <> activity.host_id
      ) >= activity.max_participants
  loop
    perform public.enqueue_activity_full_notifications(full_activity.id);
  end loop;
end;
$$;
