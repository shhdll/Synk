-- Admins can add another admin by email from the Admins page, and a repeat
-- access request no longer resets a pending one, so request-admin only emails
-- the team once per request. Also drops old overloads of the list functions
-- left over from earlier versions, which made calls ambiguous.

begin;

-- ---- Old overloads --------------------------------------------------------------

do $$
declare
  fn record;
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('admin_list_users', 'admin_list_activities', 'admin_audit_log')
      and p.oid::regprocedure::text not in (
        'admin_list_users(text,text,integer,integer,text,text)',
        'admin_list_activities(text,text,integer,integer,text,text,text,text)',
        'admin_audit_log(integer,integer,text,text,text,text)'
      )
  loop
    execute format('drop function %s', fn.sig);
  end loop;
end;
$$;

-- ---- Access requests ------------------------------------------------------------

create or replace function public.request_admin_access(p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
begin
  if private.is_admin() then
    return jsonb_build_object('result', 'already_admin');
  end if;

  if exists (
    select 1 from private.admin_requests
    where user_id = me and status = 'pending'
  ) then
    return jsonb_build_object('result', 'already_pending');
  end if;

  insert into private.admin_requests (user_id, note)
  values (me, left(nullif(btrim(coalesce(p_note, '')), ''), 500))
  on conflict (user_id) do update
    set note = excluded.note, status = 'pending', created_at = now(),
      reviewed_by = null, reviewed_at = null;

  return jsonb_build_object('result', 'requested');
end;
$$;

-- ---- Add an admin ---------------------------------------------------------------

create or replace function public.admin_add_admin(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := private.require_admin();
  target uuid;
begin
  select u.id into target
  from auth.users u
  where lower(u.email) = lower(btrim(coalesce(p_email, '')))
  limit 1;

  if target is null then
    return jsonb_build_object('result', 'not_found');
  end if;
  if private.is_suspended(target) then
    raise exception 'This account is suspended.';
  end if;

  insert into private.admins (user_id, added_by) values (target, me)
  on conflict (user_id) do nothing;
  if not found then
    return jsonb_build_object('result', 'already_admin');
  end if;

  delete from private.admin_requests where user_id = target;
  perform private.log_admin_action('admin.add', 'user', target);
  return jsonb_build_object('result', 'added');
end;
$$;

revoke all on function public.admin_add_admin(text) from public, anon;
grant execute on function public.admin_add_admin(text) to authenticated;

commit;
