-- Another user's friends, for the friend count on their profile.
--
-- Empty when either of you blocked the other. Friends who blocked you, or
-- whom you blocked, are left out.

begin;

create or replace function public.get_user_friends(target_user_id uuid)
returns table (
  id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text
)
language sql
stable
security definer
set search_path = ''
as $$
  select u.id, u.full_name, u.username, u.avatar_url, u.gender
  from public.friendships f
  join public.users u
    on u.id = case when f.user_a = target_user_id then f.user_b else f.user_a end
  where auth.uid() is not null
    and target_user_id in (f.user_a, f.user_b)
    and not exists (
      select 1 from public.user_blocks b
      where (b.blocker_id = auth.uid() and b.blocked_id in (target_user_id, u.id))
         or (b.blocked_id = auth.uid() and b.blocker_id in (target_user_id, u.id))
    )
  order by lower(coalesce(u.full_name, u.username, ''));
$$;

revoke all on function public.get_user_friends(uuid) from public, anon;
grant execute on function public.get_user_friends(uuid) to authenticated;

commit;
