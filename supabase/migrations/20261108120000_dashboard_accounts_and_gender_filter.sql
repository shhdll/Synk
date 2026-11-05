-- Two changes for the admin dashboard:
--   * someone can sign up at synk.cc/admin just for the dashboard. The sign up
--     sends dashboard_only in its metadata, and handle_new_user skips the
--     public.users row, so they never show up as a Synk user. They still ask
--     for access like anyone else.
--   * a gender filter on the Users page.

begin;

-- ---- Dashboard-only accounts ----------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_interests jsonb;
  v_age integer;
begin
  if coalesce(new.raw_user_meta_data->>'dashboard_only', '') = 'true' then
    return new;
  end if;

  begin
    v_age := (new.raw_user_meta_data->>'age')::integer;
  exception when others then
    v_age := null;
  end;

  v_interests := new.raw_user_meta_data->'interests';

  insert into public.users (
    id,
    email,
    username,
    full_name,
    age,
    gender,
    interests,
    activity_type,
    location_preference,
    created_at
  )
  values (
    new.id,
    new.email,
    coalesce(lower(trim(new.raw_user_meta_data->>'username')), ''),
    coalesce(trim(new.raw_user_meta_data->>'full_name')),
    v_age,
    new.raw_user_meta_data->>'gender',
    case
      when v_interests is not null and jsonb_typeof(v_interests) = 'array'
      then array(select jsonb_array_elements_text(v_interests))
      else null
    end,
    new.raw_user_meta_data->>'activity_type',
    new.raw_user_meta_data->>'location_preference',
    now()
  )
  on conflict (id) do update set
    email = excluded.email,
    username = coalesce(nullif(excluded.username, ''), public.users.username),
    full_name = coalesce(nullif(excluded.full_name, ''), public.users.full_name),
    age = coalesce(excluded.age, public.users.age),
    gender = coalesce(excluded.gender, public.users.gender),
    interests = coalesce(excluded.interests, public.users.interests),
    activity_type = coalesce(excluded.activity_type, public.users.activity_type),
    location_preference = coalesce(excluded.location_preference, public.users.location_preference);

  return new;
end;
$$;

-- People without a Synk profile get a card from their auth account, so they
-- still show on the Admins page and in the audit log.
create or replace function private.user_card(target_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when target_user_id is null then null else coalesce(
    (
      select jsonb_build_object(
        'id', u.id,
        'full_name', u.full_name,
        'username', u.username,
        'avatar_url', u.avatar_url,
        'suspended', exists (select 1 from private.user_suspensions s where s.user_id = u.id)
      )
      from public.users u where u.id = target_user_id
    ),
    (
      select jsonb_build_object(
        'id', a.id,
        'full_name', a.raw_user_meta_data->>'full_name',
        'username', null,
        'avatar_url', null,
        'suspended', false,
        'dashboard_only', true,
        'email', a.email
      )
      from auth.users a where a.id = target_user_id
    )
  ) end;
$$;

revoke all on function private.user_card(uuid) from public, anon, authenticated;

-- ---- Gender filter --------------------------------------------------------------

drop function if exists public.admin_list_users(text, text, integer, integer, text, text);

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
  gender text := nullif(lower(btrim(coalesce(p_gender, ''))), '');
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
      and (gender is null or lower(btrim(coalesce(u.gender, ''))) = gender)
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
