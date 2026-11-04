-- Sorting for the users, activities and audit log lists in the admin
-- dashboard, plus a visibility filter for activities and a kind filter and
-- search for the audit log. Keeps the category filter from
-- 20261107150000_admin_activity_categories.sql.

begin;

drop function if exists public.admin_list_users(text, text, integer, integer);
drop function if exists public.admin_list_activities(text, text, integer, integer);
drop function if exists public.admin_list_activities(text, text, integer, integer, text);
drop function if exists public.admin_audit_log(integer, integer);

-- ---- Users ----------------------------------------------------------------------

create or replace function public.admin_list_users(
  p_search text default null,
  p_filter text default 'all',
  p_limit integer default 50,
  p_offset integer default 0,
  p_sort text default 'joined',
  p_dir text default 'desc'
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
  result jsonb;
begin
  perform private.require_admin();

  with base as (
    select
      u.id, u.full_name, u.username, u.email, u.avatar_url, u.created_at,
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

-- ---- Activities -----------------------------------------------------------------

create or replace function public.admin_list_activities(
  p_search text default null,
  p_filter text default 'all',
  p_limit integer default 50,
  p_offset integer default 0,
  p_sort text default 'starts',
  p_dir text default 'desc',
  p_visibility text default 'all',
  p_category text default null
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
  sort_key text := coalesce(p_sort, 'starts');
  up boolean := lower(coalesce(p_dir, 'desc')) = 'asc';
  result jsonb;
begin
  perform private.require_admin();

  with base as (
    select
      a.id, a.title, a.category_label, a.category_emoji, a.starts_at, a.ends_at,
      a.location_name, a.is_public, a.max_participants, a.created_at, a.photo_url,
      private.activity_category(a.category_label, a.title, a.description) as category,
      private.user_card(a.host_id) as host,
      lower(coalesce(nullif(h.full_name, ''), h.username)) as host_sort,
      1 + (select count(*) from public.activity_participants p
        where p.activity_id = a.id and p.status = 'joined') as participants_count,
      (select count(*) from public.activity_reports r
        where r.activity_id = a.id and r.status in ('open', 'reviewing')) as open_reports
    from public.activities a
    left join public.users h on h.id = a.host_id
    where (term is null
        or a.title ilike '%' || term || '%'
        or a.location_name ilike '%' || term || '%'
        or a.category_label ilike '%' || term || '%'
        or h.username ilike '%' || term || '%'
        or h.full_name ilike '%' || term || '%'
        or a.id::text = term
        or a.activity_code = term)
  ), filtered as (
    select * from base
    where (p_category is null or category = p_category)
    and case coalesce(p_filter, 'all')
      when 'upcoming' then starts_at > now()
      when 'past' then starts_at <= now()
      when 'reported' then open_reports > 0
      else true
    end
    and case coalesce(p_visibility, 'all')
      when 'public' then is_public
      when 'private' then not is_public
      else true
    end
  ), ordered as (
    select f.*, row_number() over (order by
      case when sort_key = 'title' and up then lower(f.title) end asc nulls last,
      case when sort_key = 'title' and not up then lower(f.title) end desc nulls last,
      case when sort_key = 'host' and up then f.host_sort end asc nulls last,
      case when sort_key = 'host' and not up then f.host_sort end desc nulls last,
      case when sort_key = 'place' and up then lower(f.location_name) end asc nulls last,
      case when sort_key = 'place' and not up then lower(f.location_name) end desc nulls last,
      case when sort_key = 'people' and up then f.participants_count end asc,
      case when sort_key = 'people' and not up then f.participants_count end desc,
      case when sort_key = 'visibility' and up then f.is_public end asc,
      case when sort_key = 'visibility' and not up then f.is_public end desc,
      case when sort_key = 'reports' and up then f.open_reports end asc,
      case when sort_key = 'reports' and not up then f.open_reports end desc,
      case when sort_key = 'starts' and up then f.starts_at end asc,
      f.starts_at desc, f.id
    ) as rn
    from filtered f
  )
  select jsonb_build_object(
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(o) - 'rn' - 'host_sort' order by o.rn)
      from ordered o where o.rn > skip and o.rn <= skip + lim
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

-- ---- Audit log ------------------------------------------------------------------

create or replace function public.admin_audit_log(
  p_limit integer default 50,
  p_offset integer default 0,
  p_kind text default 'all',
  p_search text default null,
  p_sort text default 'when',
  p_dir text default 'desc'
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
  sort_key text := coalesce(p_sort, 'when');
  up boolean := lower(coalesce(p_dir, 'desc')) = 'asc';
  result jsonb;
begin
  perform private.require_admin();

  with filtered as (
    select l.*, lower(coalesce(nullif(u.full_name, ''), u.username)) as admin_sort
    from private.admin_audit_log l
    left join public.users u on u.id = l.admin_id
    where (coalesce(p_kind, 'all') = 'all' or split_part(l.action, '.', 1) = p_kind)
      and (term is null
        or u.full_name ilike '%' || term || '%'
        or u.username ilike '%' || term || '%'
        or u.email ilike '%' || term || '%'
        or l.details ->> 'reason' ilike '%' || term || '%'
        or l.details ->> 'note' ilike '%' || term || '%'
        or l.details ->> 'title' ilike '%' || term || '%'
        or l.target_id::text = term)
  ), ordered as (
    select f.*, row_number() over (order by
      case when sort_key = 'admin' and up then f.admin_sort end asc nulls last,
      case when sort_key = 'admin' and not up then f.admin_sort end desc nulls last,
      case when sort_key = 'action' and up then f.action end asc,
      case when sort_key = 'action' and not up then f.action end desc,
      case when sort_key = 'target' and up then f.target_type end asc,
      case when sort_key = 'target' and not up then f.target_type end desc,
      case when sort_key = 'when' and up then f.created_at end asc,
      f.created_at desc, f.id desc
    ) as rn
    from filtered f
  )
  select jsonb_build_object(
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', o.id, 'action', o.action, 'target_type', o.target_type,
        'target_id', o.target_id, 'details', o.details, 'created_at', o.created_at,
        'admin', private.user_card(o.admin_id)
      ) order by o.rn)
      from ordered o where o.rn > skip and o.rn <= skip + lim
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.admin_list_users(text, text, integer, integer, text, text)',
    'public.admin_list_activities(text, text, integer, integer, text, text, text, text)',
    'public.admin_audit_log(integer, integer, text, text, text, text)'
  ] loop
    execute format('revoke all on function %s from public, anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;

commit;
