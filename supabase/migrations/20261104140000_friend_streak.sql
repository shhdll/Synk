-- Start times of the activities a user attended, so friends can see their
-- weekly streak. Only times, nothing about the activities. Visible to the
-- user and their friends, never across a block.
begin;

create or replace function public.get_user_streak_times(target_user_id uuid)
returns setof timestamptz
language sql
stable
security definer
set search_path = ''
as $$
  select activity.starts_at
  from public.activities as activity
  where auth.uid() is not null
    and target_user_id is not null
    and (
      auth.uid() = target_user_id
      or (
        exists (
          select 1
          from public.friendships as friendship
          where friendship.user_a = least(auth.uid(), target_user_id)
            and friendship.user_b = greatest(auth.uid(), target_user_id)
        )
        and not public.users_blocked_either_way(auth.uid(), target_user_id)
      )
    )
    and activity.starts_at <= now()
    and activity.starts_at > now() - interval '2 years'
    and public.is_activity_attendee(activity.id, target_user_id);
$$;

revoke all on function public.get_user_streak_times(uuid) from public, anon;
grant execute on function public.get_user_streak_times(uuid) to authenticated;

commit;
