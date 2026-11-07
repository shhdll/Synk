-- The Users page failed with 'column reference "gender" is ambiguous': the
-- gender variable had the same name as the users column. Renamed it.
-- Otherwise unchanged from 20261108120000_dashboard_accounts_and_gender_filter.sql.
-- Safe to run again.

begin;

create or replace function public.admin_list_users(
  p_search text default null,
  p_filter text default 'all',
  p_limit integer default 50,
  p_offset integer default 0,
  p_sort text default 'joined',
  p_dir text default 'desc',
  p_gender text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  term text := nullif(btrim(coalesce(p_search, '')), '');
  lim integer := private.clamp_limit(p_limit);
  skip integer := greatest(coalesce(p_offset, 0), 0);
  sort_key text := coalesce(p_sort, 'joined');
  up boolean := lower(coalesce(p_dir, 'desc')) = 'asc';
  wanted_gender text := nullif(lower(btrim(coalesce(p_gender, ''))), '');
  result jsonb;
begin
  perform private.require_admin();

  with base as (
    select
      u.id, u.full_name, u.username, u.email, u.avatar_url, u.created_at,
      u.gender,
      au.last_sign_in_at,
      s.suspended_at,
      (select count(*) from public.activities a where a.host_id = u.id) as hosted_count,
      (select count(*) from public.activity_participants p
        where p.user_id = u.id and p.status = 'joined') as joined_count,
      (select count(*) from public.user_reports r
        where r.reported_user_id = u.id and r.status in ('open', 'reviewing')) as open_reports
    from public.users u
    left join auth.users au on au.id = u.id
    left join private.user_suspensions s on s.user_id = u.id
    where (term is null
        or u.full_name ilike '%' || term || '%'
        or u.username ilike '%' || term || '%'
        or u.email ilike '%' || term || '%'
        or u.id::text = term)
      and (wanted_gender is null
        or lower(btrim(coalesce(u.gender, ''))) = wanted_gender)
  ), filtered as (
    select * from base
    where case coalesce(p_filter, 'all')
      when 'suspended' then suspended_at is not null
      when 'reported' then open_reports > 0
      else true
    end
  ), ordered as (
    select f.*, row_number() over (order by
      case when sort_key = 'name' and up then lower(coalesce(nullif(f.full_name, ''), f.username)) end asc nulls last,
      case when sort_key = 'name' and not up then lower(coalesce(nullif(f.full_name, ''), f.username)) end desc nulls last,
      case when sort_key = 'email' and up then lower(f.email) end asc nulls last,
      case when sort_key = 'email' and not up then lower(f.email) end desc nulls last,
      case when sort_key = 'last_sign_in' and up then f.last_sign_in_at end asc nulls last,
      case when sort_key = 'last_sign_in' and not up then f.last_sign_in_at end desc nulls last,
      case when sort_key = 'hosted' and up then f.hosted_count end asc,
      case when sort_key = 'hosted' and not up then f.hosted_count end desc,
      case when sort_key = 'joins' and up then f.joined_count end asc,
      case when sort_key = 'joins' and not up then f.joined_count end desc,
      case when sort_key = 'status' and up then (f.suspended_at is not null)::int * 2 + (f.open_reports > 0)::int end asc,
      case when sort_key = 'status' and not up then (f.suspended_at is not null)::int * 2 + (f.open_reports > 0)::int end desc,
      case when sort_key = 'joined' and up then f.created_at end asc,
      f.created_at desc, f.id
    ) as rn
    from filtered f
  )
  select jsonb_build_object(
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(o) - 'rn' order by o.rn)
      from ordered o where o.rn > skip and o.rn <= skip + lim
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

revoke all on function public.admin_list_users(text, text, integer, integer, text, text, text) from public, anon;
grant execute on function public.admin_list_users(text, text, integer, integer, text, text, text) to authenticated;

commit;
