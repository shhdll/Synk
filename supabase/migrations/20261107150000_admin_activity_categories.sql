-- Activities in the admin dashboard can be filtered by category, worked
-- out the same way as the overview (private.activity_category).

begin;

drop function if exists public.admin_list_activities(text, text, integer, integer);

create or replace function public.admin_list_activities(
  p_search text default null,
  p_filter text default 'all',
  p_limit integer default 50,
  p_offset integer default 0,
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
  result jsonb;
begin
  perform private.require_admin();

  with base as (
    select
      a.id, a.title, a.category_label, a.category_emoji, a.starts_at, a.ends_at,
      a.location_name, a.is_public, a.max_participants, a.created_at, a.photo_url,
      private.activity_category(a.category_label, a.title, a.description) as category,
      private.user_card(a.host_id) as host,
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
  )
  select jsonb_build_object(
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(f) order by f.starts_at desc)
      from (select * from filtered order by starts_at desc
        limit lim offset greatest(coalesce(p_offset, 0), 0)) f
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

create or replace function public.admin_activity_categories()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  return coalesce((
    select jsonb_agg(c order by c.count desc, c.label)
    from (
      select private.activity_category(category_label, title, description) as label,
        count(*) as count
      from public.activities
      group by 1
    ) c
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.admin_list_activities(text, text, integer, integer, text) from public, anon;
grant execute on function public.admin_list_activities(text, text, integer, integer, text) to authenticated;
revoke all on function public.admin_activity_categories() from public, anon;
grant execute on function public.admin_activity_categories() to authenticated;

commit;
