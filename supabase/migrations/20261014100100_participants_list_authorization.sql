-- Restricts participant lists to public activities, hosts, and approved participants.

begin;

create or replace function public.get_activity_participants_list(
  p_activity_id uuid
)
returns table (
  user_id uuid,
  full_name text,
  username text,
  avatar_url text,
  gender text,
  status text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    u.id as user_id,
    coalesce(nullif(trim(u.full_name), ''), 'Synk member') as full_name,
    u.username,
    u.avatar_url,
    u.gender,
    ap.status
  from public.activity_participants ap
  join public.users u
    on u.id = ap.user_id
  where ap.activity_id = p_activity_id
    and ap.status = 'joined'
    and auth.uid() is not null
    and exists (
      select 1
      from public.activities a
      where a.id = p_activity_id
        and (
          a.is_public
          or a.host_id = auth.uid()
          or exists (
            select 1
            from public.activity_participants viewer
            where viewer.activity_id = a.id
              and viewer.user_id = auth.uid()
              and viewer.status in ('joined', 'waitlisted')
          )
        )
    )
  order by ap.created_at asc;
$$;

revoke all on function public.get_activity_participants_list(uuid) from public;
revoke all on function public.get_activity_participants_list(uuid) from anon;
grant execute on function public.get_activity_participants_list(uuid) to authenticated;

commit;
