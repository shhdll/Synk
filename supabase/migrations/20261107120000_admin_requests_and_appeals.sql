-- Two additions to the admin dashboard:
--   * someone who signs in to synk.cc/admin without access can ask for it,
--     and admins approve or decline on the Admins page;
--   * a suspended user can write to support from the login screen. They
--     can't sign in, so submit-support checks the email belongs to a
--     suspended account and saves it as an "appeal" ticket.

begin;

-- ---- Appeals --------------------------------------------------------------------

do $$
declare
  old_check text;
begin
  for old_check in
    select c.conname from pg_constraint c
    where c.conrelid = 'public.support_tickets'::regclass
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) like '%category%'
  loop
    execute format('alter table public.support_tickets drop constraint %I', old_check);
  end loop;
end;
$$;

alter table public.support_tickets
  add constraint support_tickets_category_check
  check (category in ('problem', 'feedback', 'other', 'appeal'));

-- For submit-support only.
create or replace function public.suspended_user_for_email(p_email text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.id
  from auth.users u
  join private.user_suspensions s on s.user_id = u.id
  where lower(u.email) = lower(btrim(p_email))
  limit 1;
$$;

revoke all on function public.suspended_user_for_email(text)
  from public, anon, authenticated;
grant execute on function public.suspended_user_for_email(text) to service_role;

-- ---- Admin access requests ------------------------------------------------------

alter table private.admins
  add column if not exists added_by uuid references auth.users (id) on delete set null;

create table if not exists private.admin_requests (
  user_id uuid primary key references auth.users (id) on delete cascade,
  note text check (note is null or char_length(note) <= 500),
  status text not null default 'pending' check (status in ('pending', 'declined')),
  created_at timestamptz not null default now(),
  reviewed_by uuid references auth.users (id) on delete set null,
  reviewed_at timestamptz
);
revoke all on private.admin_requests from public, anon, authenticated;

-- What the signed-in person sees on the dashboard's sign-in screen.
create or replace function public.admin_access_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'is_admin', private.is_admin(),
    'request', (
      select jsonb_build_object('status', r.status, 'created_at', r.created_at,
        'reviewed_at', r.reviewed_at)
      from private.admin_requests r where r.user_id = auth.uid()
    )
  );
$$;

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

  insert into private.admin_requests (user_id, note)
  values (me, left(nullif(btrim(coalesce(p_note, '')), ''), 500))
  on conflict (user_id) do update
    set note = excluded.note, status = 'pending', created_at = now(),
      reviewed_by = null, reviewed_at = null;

  return jsonb_build_object('result', 'requested');
end;
$$;

revoke all on function public.admin_access_status() from public, anon;
grant execute on function public.admin_access_status() to authenticated;
revoke all on function public.request_admin_access(text) from public, anon;
grant execute on function public.request_admin_access(text) to authenticated;

create or replace function public.admin_list_admins()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();

  return jsonb_build_object(
    'admins', coalesce((
      select jsonb_agg(private.user_card(a.user_id) || jsonb_build_object(
        'email', u.email, 'added_at', a.added_at,
        'added_by', private.user_card(a.added_by)
      ) order by a.added_at)
      from private.admins a join auth.users u on u.id = a.user_id
    ), '[]'::jsonb),
    'requests', coalesce((
      select jsonb_agg(private.user_card(r.user_id) || jsonb_build_object(
        'email', u.email, 'note', r.note, 'created_at', r.created_at
      ) order by r.created_at)
      from private.admin_requests r join auth.users u on u.id = r.user_id
      where r.status = 'pending'
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.admin_review_access_request(p_user_id uuid, p_approve boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := private.require_admin();
begin
  perform 1 from private.admin_requests
  where user_id = p_user_id and status = 'pending' for update;
  if not found then
    return jsonb_build_object('result', 'not_pending');
  end if;

  if p_approve then
    if private.is_suspended(p_user_id) then
      raise exception 'This account is suspended.';
    end if;
    insert into private.admins (user_id, added_by) values (p_user_id, me)
    on conflict (user_id) do nothing;
    delete from private.admin_requests where user_id = p_user_id;
  else
    update private.admin_requests
    set status = 'declined', reviewed_by = me, reviewed_at = now()
    where user_id = p_user_id;
  end if;

  perform private.log_admin_action(
    case when p_approve then 'admin.approve' else 'admin.decline' end,
    'user', p_user_id);
  return jsonb_build_object('result', case when p_approve then 'approved' else 'declined' end);
end;
$$;

create or replace function public.admin_remove_admin(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := private.require_admin();
begin
  if p_user_id = me then
    raise exception 'You can''t remove yourself.';
  end if;

  delete from private.admins where user_id = p_user_id;
  if not found then
    return jsonb_build_object('result', 'not_admin');
  end if;

  perform private.log_admin_action('admin.remove', 'user', p_user_id);
  return jsonb_build_object('result', 'removed');
end;
$$;

revoke all on function public.admin_list_admins() from public, anon;
grant execute on function public.admin_list_admins() to authenticated;
revoke all on function public.admin_review_access_request(uuid, boolean) from public, anon;
grant execute on function public.admin_review_access_request(uuid, boolean) to authenticated;
revoke all on function public.admin_remove_admin(uuid) from public, anon;
grant execute on function public.admin_remove_admin(uuid) to authenticated;

commit;
