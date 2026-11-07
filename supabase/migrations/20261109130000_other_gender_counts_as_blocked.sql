-- Someone of the other gender counts as blocked, like a suspended user.
--
-- Every check that hides blocked people (my activities list, ratings,
-- chats, joins) then also hides old mixed activities from before the
-- same-gender rules. Someone without a gender matches no one, as in
-- private.same_gender.
--
-- Otherwise unchanged from 20261107100000_admin_dashboard.sql.
-- Safe to run again.

begin;

create or replace function public.users_blocked_either_way(
  first_user_id uuid,
  second_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_blocks as block
    where (block.blocker_id = first_user_id
        and block.blocked_id = second_user_id)
      or (block.blocker_id = second_user_id
        and block.blocked_id = first_user_id)
  )
  or (
    first_user_id is distinct from second_user_id
    and (
      exists (
        select 1 from private.user_suspensions as s
        where s.user_id in (first_user_id, second_user_id)
      )
      or not private.same_gender(first_user_id, second_user_id)
    )
  );
$$;

revoke all on function public.users_blocked_either_way(uuid, uuid)
  from public, anon, authenticated;

commit;
