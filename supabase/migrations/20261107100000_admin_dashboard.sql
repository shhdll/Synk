-- Admin dashboard at synk.cc/admin.
--
-- Admins are rows in private.admins, added by hand in the SQL editor:
--   insert into private.admins (user_id)
--   select id from auth.users where email = 'someone@example.com';
--
-- The dashboard only talks to the admin_* functions below. Each one checks
-- private.is_admin() first, so a normal account gets an error even if it
-- calls them directly. Every change an admin makes goes to the audit log.
--
-- Suspending a user bans the auth account and treats them as blocked by
-- everyone, which reuses all the block rules from 20261104170000.

begin;

create schema if not exists private;

-- ---- Admins ---------------------------------------------------------------------

create table if not exists private.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  added_at timestamptz not null default now()
);
revoke all on private.admins from public, anon, authenticated;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and exists (select 1 from private.admins where user_id = auth.uid());
$$;

revoke all on function private.is_admin() from public, anon;
grant execute on function private.is_admin() to authenticated;

create or replace function private.require_admin()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.is_admin() then
    raise exception 'Not allowed.' using errcode = '42501';
  end if;
  return auth.uid();
end;
$$;

revoke all on function private.require_admin() from public, anon, authenticated;

-- Lets the dashboard check access right after sign in.
create or replace function public.admin_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_admin();
$$;

revoke all on function public.admin_is_admin() from public, anon;
grant execute on function public.admin_is_admin() to authenticated;

-- ---- Audit log ------------------------------------------------------------------

create table if not exists private.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid references auth.users (id) on delete set null,
  action text not null,
  target_type text not null,
  target_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
revoke all on private.admin_audit_log from public, anon, authenticated;

create index if not exists admin_audit_log_created_idx
  on private.admin_audit_log (created_at desc);
create index if not exists admin_audit_log_target_idx
  on private.admin_audit_log (target_id);

create or replace function private.log_admin_action(
  p_action text,
  p_target_type text,
  p_target_id uuid,
  p_details jsonb default '{}'::jsonb
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into private.admin_audit_log (admin_id, action, target_type, target_id, details)
  values (auth.uid(), p_action, p_target_type, p_target_id, coalesce(p_details, '{}'::jsonb));
$$;

revoke all on function private.log_admin_action(text, text, uuid, jsonb)
  from public, anon, authenticated;

-- ---- Suspensions ----------------------------------------------------------------

create table if not exists private.user_suspensions (
  user_id uuid primary key references public.users (id) on delete cascade,
  reason text not null check (char_length(reason) between 1 and 500),
  suspended_by uuid references auth.users (id) on delete set null,
  suspended_at timestamptz not null default now()
);
revoke all on private.user_suspensions from public, anon, authenticated;

create or replace function private.is_suspended(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from private.user_suspensions where user_id = target_user_id
  );
$$;

revoke all on function private.is_suspended(uuid) from public, anon;
grant execute on function private.is_suspended(uuid) to authenticated;

-- A suspended user counts as blocked with everyone: their profile, hosted
-- activities and messages are hidden the same way, and nobody can join
-- their activities. Otherwise unchanged from 20261030150000_activity_ratings.sql.
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
    and exists (
      select 1 from private.user_suspensions as s
      where s.user_id in (first_user_id, second_user_id)
    )
  );
$$;

revoke all on function public.users_blocked_either_way(uuid, uuid)
  from public, anon, authenticated;

-- The ban stops new sign ins and token refresh, but an access token can
-- live up to an hour. This stops the app's own functions in that window.
-- Otherwise unchanged from 20261028200000_friends.sql.
create or replace function public.require_signed_in()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'You must be signed in.';
  end if;
  if exists (select 1 from private.user_suspensions where user_id = auth.uid()) then
    raise exception 'This account is suspended.';
  end if;
  return auth.uid();
end;
$$;

revoke all on function public.require_signed_in() from public, anon, authenticated;

drop policy if exists "Hide suspended profiles" on public.users;
create policy "Hide suspended profiles"
  on public.users
  as restrictive
  for select
  to authenticated
  using (id = auth.uid() or not private.is_suspended(id));

drop policy if exists "Suspended users can't create activities" on public.activities;
create policy "Suspended users can't create activities"
  on public.activities
  as restrictive
  for insert
  to authenticated
  with check (not private.is_suspended(auth.uid()));

-- ---- Activity reports -----------------------------------------------------------

-- activity_id goes null if the activity is deleted, so the title and host
-- are copied in to keep the report readable.
create table if not exists public.activity_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users (id) on delete cascade,
  activity_id uuid references public.activities (id) on delete set null,
  activity_title text not null,
  activity_host_id uuid references public.users (id) on delete set null,
  reason text not null
    check (reason in ('harassment', 'spam', 'fake_profile', 'inappropriate_content', 'other')),
  details text check (details is null or char_length(details) <= 1000),
  constraint activity_reports_other_needs_details
    check (reason <> 'other' or details is not null),
  status text not null default 'open'
    check (status in ('open', 'reviewing', 'resolved', 'dismissed')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.users (id) on delete set null,
  action_taken text,
  admin_note text check (admin_note is null or char_length(admin_note) <= 1000)
);

create unique index if not exists activity_reports_one_open_per_pair
  on public.activity_reports (reporter_id, activity_id)
  where status in ('open', 'reviewing');

create index if not exists activity_reports_queue_idx
  on public.activity_reports (status, created_at desc);

create index if not exists activity_reports_activity_idx
  on public.activity_reports (activity_id);

alter table public.activity_reports enable row level security;
revoke all on public.activity_reports from public, anon, authenticated;

alter table public.user_reports
  add column if not exists action_taken text,
  add column if not exists admin_note text
    check (admin_note is null or char_length(admin_note) <= 1000);

create or replace function public.report_activity(
  target_activity_id uuid,
  report_reason text,
  report_details text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := public.require_signed_in();
  cleaned_details text := nullif(btrim(coalesce(report_details, '')), '');
  target public.activities%rowtype;
begin
  select * into target from public.activities where id = target_activity_id;
  if not found or not public.can_see_activity(target_activity_id, me) then
    return jsonb_build_object('result', 'not_found');
  end if;

  if target.host_id = me then
    return jsonb_build_object('result', 'self');
  end if;

  if report_reason is null or report_reason not in
      ('harassment', 'spam', 'fake_profile', 'inappropriate_content', 'other') then
    return jsonb_build_object('result', 'invalid_reason');
  end if;

  if report_reason = 'other' and cleaned_details is null then
    return jsonb_build_object('result', 'details_required');
  end if;

  if cleaned_details is not null and char_length(cleaned_details) > 1000 then
    return jsonb_build_object('result', 'details_too_long');
  end if;

  insert into public.activity_reports
    (reporter_id, activity_id, activity_title, activity_host_id, reason, details)
  values
    (me, target.id, target.title, target.host_id, report_reason, cleaned_details)
  on conflict (reporter_id, activity_id)
    where status in ('open', 'reviewing')
    do nothing;

  if not found then
    return jsonb_build_object('result', 'already_reported');
  end if;

  return jsonb_build_object('result', 'reported');
end;
$$;

revoke all on function public.report_activity(uuid, text, text) from public, anon;
grant execute on function public.report_activity(uuid, text, text) to authenticated;

-- ---- Support reply history ------------------------------------------------------

create table if not exists public.support_replies (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets (id) on delete cascade,
  -- Null when sent from the emailed reply link.
  admin_id uuid references auth.users (id) on delete set null,
  body text not null check (char_length(body) between 1 and 5000),
  email_status text not null check (email_status in ('sent', 'failed')),
  error text,
  created_at timestamptz not null default now()
);

create index if not exists support_replies_ticket_idx
  on public.support_replies (ticket_id, created_at);

alter table public.support_replies enable row level security;
revoke all on public.support_replies from public, anon, authenticated;
grant select, insert on public.support_replies to service_role;

alter table public.support_tickets
  add column if not exists closed_at timestamptz;

-- The old replies, so the history isn't empty for them.
insert into public.support_replies (ticket_id, body, email_status, created_at)
select t.id, t.reply, 'sent', coalesce(t.replied_at, t.created_at)
from public.support_tickets t
where t.reply is not null
  and not exists (select 1 from public.support_replies r where r.ticket_id = t.id);

-- Called by reply-support after each send attempt. A failed email stays in
-- the history but leaves the ticket as it was.
create or replace function public.record_support_reply(
  p_ticket_id uuid,
  p_admin_id uuid,
  p_body text,
  p_sent boolean,
  p_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.support_replies (ticket_id, admin_id, body, email_status, error)
  values (p_ticket_id, p_admin_id, p_body,
    case when p_sent then 'sent' else 'failed' end, left(p_error, 500));

  if p_sent then
    update public.support_tickets
    set status = 'replied', reply = p_body, replied_at = now(), closed_at = null
    where id = p_ticket_id;
  end if;

  insert into private.admin_audit_log (admin_id, action, target_type, target_id, details)
  values (p_admin_id,
    case when p_sent then 'support.reply' else 'support.reply_failed' end,
    'ticket', p_ticket_id,
    jsonb_build_object('via', case when p_admin_id is null then 'email_link' else 'dashboard' end));
end;
$$;

revoke all on function public.record_support_reply(uuid, uuid, text, boolean, text)
  from public, anon, authenticated;
grant execute on function public.record_support_reply(uuid, uuid, text, boolean, text)
  to service_role;

-- ---- Shared bits ----------------------------------------------------------------

create or replace function private.user_card(target_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when target_user_id is null then null else (
    select jsonb_build_object(
      'id', u.id,
      'full_name', u.full_name,
      'username', u.username,
      'avatar_url', u.avatar_url,
      'suspended', exists (select 1 from private.user_suspensions s where s.user_id = u.id)
    )
    from public.users u where u.id = target_user_id
  ) end;
$$;

revoke all on function private.user_card(uuid) from public, anon, authenticated;

create or replace function private.clamp_limit(p_limit integer)
returns integer
language sql
immutable
set search_path = ''
as $$
  select least(greatest(coalesce(p_limit, 50), 1), 200);
$$;

revoke all on function private.clamp_limit(integer) from public, anon, authenticated;

-- ---- Overview -------------------------------------------------------------------

create or replace function public.admin_stats(p_days integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  days integer := least(greatest(coalesce(p_days, 30), 7), 180);
  first_day date := (now() at time zone 'Asia/Riyadh')::date - (days - 1);
begin
  perform private.require_admin();

  return jsonb_build_object(
    'days', days,
    'users', (select count(*) from public.users),
    'users_in_period', (select count(*) from public.users
      where (created_at at time zone 'Asia/Riyadh')::date >= first_day),
    'signed_in_in_period', (select count(*) from auth.users
      where (last_sign_in_at at time zone 'Asia/Riyadh')::date >= first_day),
    'suspended', (select count(*) from private.user_suspensions),
    'activities', (select count(*) from public.activities),
    'activities_in_period', (select count(*) from public.activities
      where (created_at at time zone 'Asia/Riyadh')::date >= first_day),
    'upcoming_activities', (select count(*) from public.activities where starts_at > now()),
    'joins_in_period', (select count(*) from public.activity_participants
      where status = 'joined'
        and (created_at at time zone 'Asia/Riyadh')::date >= first_day),
    'open_tickets', (select count(*) from public.support_tickets where status = 'open'),
    'open_reports',
      (select count(*) from public.user_reports where status in ('open', 'reviewing'))
      + (select count(*) from public.activity_reports where status in ('open', 'reviewing')),
    'daily', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'day', d.day,
        'users', (select count(*) from public.users u
          where (u.created_at at time zone 'Asia/Riyadh')::date = d.day),
        'activities', (select count(*) from public.activities a
          where (a.created_at at time zone 'Asia/Riyadh')::date = d.day)
      ) order by d.day), '[]'::jsonb)
      from (
        select generate_series(first_day::timestamp, (first_day + (days - 1))::timestamp,
          interval '1 day')::date as day
      ) d
    ),
    'categories', (
      select coalesce(jsonb_agg(c order by c.count desc), '[]'::jsonb)
      from (
        select coalesce(nullif(trim(category_label), ''), 'Other') as label, count(*) as count
        from public.activities
        group by 1
        order by 2 desc
        limit 8
      ) c
    )
  );
end;
$$;

-- ---- Users ----------------------------------------------------------------------

create or replace function public.admin_list_users(
  p_search text default null,
  p_filter text default 'all',
  p_limit integer default 50,
  p_offset integer default 0
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
  )
  select jsonb_build_object(
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(f) order by f.created_at desc)
      from (select * from filtered order by created_at desc
        limit lim offset greatest(coalesce(p_offset, 0), 0)) f
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

create or replace function public.admin_get_user(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.require_admin();

  select jsonb_build_object(
    'profile', to_jsonb(u),
    'auth', jsonb_build_object(
      'email_confirmed_at', au.email_confirmed_at,
      'last_sign_in_at', au.last_sign_in_at,
      'banned_until', au.banned_until
    ),
    'is_admin', exists (select 1 from private.admins ad where ad.user_id = u.id),
    'suspension', (
      select jsonb_build_object(
        'reason', s.reason,
        'suspended_at', s.suspended_at,
        'suspended_by', private.user_card(s.suspended_by)
      )
      from private.user_suspensions s where s.user_id = u.id
    ),
    'hosted', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'title', a.title, 'starts_at', a.starts_at,
        'category_label', a.category_label, 'is_public', a.is_public
      ) order by a.starts_at desc)
      from (select * from public.activities where host_id = u.id
        order by starts_at desc limit 50) a
    ), '[]'::jsonb),
    'joined', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'title', a.title, 'starts_at', a.starts_at,
        'status', p.status
      ) order by a.starts_at desc)
      from (select * from public.activity_participants where user_id = u.id
        order by created_at desc limit 50) p
      join public.activities a on a.id = p.activity_id
    ), '[]'::jsonb),
    'reports_against', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'reason', r.reason, 'details', r.details, 'status', r.status,
        'created_at', r.created_at, 'reporter', private.user_card(r.reporter_id)
      ) order by r.created_at desc)
      from public.user_reports r where r.reported_user_id = u.id
    ), '[]'::jsonb),
    'reports_made', (select count(*) from public.user_reports r where r.reporter_id = u.id)
      + (select count(*) from public.activity_reports r where r.reporter_id = u.id),
    'tickets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'category', t.category, 'status', t.status,
        'created_at', t.created_at, 'message', left(t.message, 140)
      ) order by t.created_at desc)
      from public.support_tickets t where t.user_id = u.id
    ), '[]'::jsonb)
  )
  into result
  from public.users u
  left join auth.users au on au.id = u.id
  where u.id = p_user_id;

  if result is null then
    raise exception 'User not found.' using errcode = 'P0002';
  end if;
  return result;
end;
$$;

create or replace function private.suspend_user(p_user_id uuid, p_reason text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := private.require_admin();
  cleaned text := nullif(btrim(coalesce(p_reason, '')), '');
begin
  if p_user_id = me then
    raise exception 'You can''t suspend yourself.';
  end if;
  if exists (select 1 from private.admins where user_id = p_user_id) then
    raise exception 'Admins can''t be suspended. Remove them from admins first.';
  end if;
  if cleaned is null then
    raise exception 'A reason is required.';
  end if;
  if not exists (select 1 from public.users where id = p_user_id) then
    raise exception 'User not found.' using errcode = 'P0002';
  end if;

  insert into private.user_suspensions (user_id, reason, suspended_by)
  values (p_user_id, left(cleaned, 500), me)
  on conflict (user_id) do nothing;

  if not found then
    return false;
  end if;

  -- Blocks sign in and refresh, and ends current sessions.
  update auth.users set banned_until = now() + interval '100 years' where id = p_user_id;
  delete from auth.sessions where user_id = p_user_id;

  perform private.log_admin_action('user.suspend', 'user', p_user_id,
    jsonb_build_object('reason', left(cleaned, 500)));
  return true;
end;
$$;

revoke all on function private.suspend_user(uuid, text) from public, anon, authenticated;

create or replace function public.admin_suspend_user(p_user_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  if not private.suspend_user(p_user_id, p_reason) then
    return jsonb_build_object('result', 'already_suspended');
  end if;
  return jsonb_build_object('result', 'suspended');
end;
$$;

create or replace function public.admin_restore_user(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();

  delete from private.user_suspensions where user_id = p_user_id;
  if not found then
    return jsonb_build_object('result', 'not_suspended');
  end if;

  update auth.users set banned_until = null where id = p_user_id;
  perform private.log_admin_action('user.restore', 'user', p_user_id);
  return jsonb_build_object('result', 'restored');
end;
$$;

-- ---- Activities -----------------------------------------------------------------

create or replace function public.admin_list_activities(
  p_search text default null,
  p_filter text default 'all',
  p_limit integer default 50,
  p_offset integer default 0
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
      a.location_name, a.is_public, a.max_participants, a.created_at,
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
    where case coalesce(p_filter, 'all')
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

create or replace function public.admin_get_activity(p_activity_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.require_admin();

  select jsonb_build_object(
    'activity', to_jsonb(a),
    'host', private.user_card(a.host_id),
    'participants', coalesce((
      select jsonb_agg(private.user_card(p.user_id) || jsonb_build_object(
        'status', p.status, 'joined_at', p.created_at
      ) order by p.created_at)
      from public.activity_participants p where p.activity_id = a.id
    ), '[]'::jsonb),
    'reports', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'reason', r.reason, 'details', r.details, 'status', r.status,
        'created_at', r.created_at, 'reporter', private.user_card(r.reporter_id)
      ) order by r.created_at desc)
      from public.activity_reports r where r.activity_id = a.id
    ), '[]'::jsonb)
  )
  into result
  from public.activities a
  where a.id = p_activity_id;

  if result is null then
    raise exception 'Activity not found.' using errcode = 'P0002';
  end if;
  return result;
end;
$$;

-- Same as the host deleting it: participants get the usual "deleted"
-- notification and everything tied to it cascades.
create or replace function private.delete_activity(p_activity_id uuid, p_reason text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := private.require_admin();
  cleaned text := nullif(btrim(coalesce(p_reason, '')), '');
  target public.activities%rowtype;
begin
  if cleaned is null then
    raise exception 'A reason is required.';
  end if;

  select * into target from public.activities where id = p_activity_id for update;
  if not found then
    return false;
  end if;

  update public.activity_reports
  set status = 'resolved', reviewed_at = now(), reviewed_by = me,
    action_taken = 'deleted_activity',
    admin_note = coalesce(admin_note, left(cleaned, 1000))
  where activity_id = p_activity_id and status in ('open', 'reviewing');

  delete from public.activities where id = p_activity_id;

  perform private.log_admin_action('activity.delete', 'activity', p_activity_id,
    jsonb_build_object(
      'reason', left(cleaned, 500),
      'title', target.title,
      'host_id', target.host_id,
      'starts_at', target.starts_at
    ));
  return true;
end;
$$;

revoke all on function private.delete_activity(uuid, text) from public, anon, authenticated;

create or replace function public.admin_delete_activity(p_activity_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  if not private.delete_activity(p_activity_id, p_reason) then
    return jsonb_build_object('result', 'not_found');
  end if;
  return jsonb_build_object('result', 'deleted');
end;
$$;

-- ---- Reports --------------------------------------------------------------------

create or replace function public.admin_list_reports(
  p_kind text default 'all',
  p_status text default 'open',
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  lim integer := private.clamp_limit(p_limit);
  result jsonb;
begin
  perform private.require_admin();

  with all_reports as (
    select
      'user' as kind, r.id, r.reason, r.details, r.status, r.created_at,
      r.reviewed_at, r.action_taken, r.admin_note,
      private.user_card(r.reporter_id) as reporter,
      private.user_card(r.reviewed_by) as reviewed_by,
      private.user_card(r.reported_user_id) as target_user,
      null::jsonb as target_activity,
      (select count(*) from public.user_reports o
        where o.reported_user_id = r.reported_user_id
          and o.status in ('open', 'reviewing')) as open_on_target
    from public.user_reports r
    union all
    select
      'activity', r.id, r.reason, r.details, r.status, r.created_at,
      r.reviewed_at, r.action_taken, r.admin_note,
      private.user_card(r.reporter_id),
      private.user_card(r.reviewed_by),
      private.user_card(r.activity_host_id),
      jsonb_build_object(
        'id', r.activity_id,
        'title', coalesce(a.title, r.activity_title),
        'starts_at', a.starts_at,
        'deleted', r.activity_id is null
      ),
      (select count(*) from public.activity_reports o
        where o.activity_id = r.activity_id
          and o.status in ('open', 'reviewing'))
    from public.activity_reports r
    left join public.activities a on a.id = r.activity_id
  ), filtered as (
    select * from all_reports
    where (coalesce(p_kind, 'all') = 'all' or kind = p_kind)
      and case coalesce(p_status, 'open')
        when 'open' then status in ('open', 'reviewing')
        when 'closed' then status in ('resolved', 'dismissed')
        else true
      end
  )
  select jsonb_build_object(
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(f) order by f.created_at desc)
      from (select * from filtered order by created_at desc
        limit lim offset greatest(coalesce(p_offset, 0), 0)) f
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

-- Marks an open report as being looked at, so two admins don't pick up
-- the same one.
create or replace function public.admin_start_review(p_kind text, p_report_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := private.require_admin();
begin
  if p_kind = 'user' then
    update public.user_reports set status = 'reviewing', reviewed_by = me
    where id = p_report_id and status = 'open';
  elsif p_kind = 'activity' then
    update public.activity_reports set status = 'reviewing', reviewed_by = me
    where id = p_report_id and status = 'open';
  else
    raise exception 'Unknown report type.';
  end if;

  if not found then
    return jsonb_build_object('result', 'not_open');
  end if;
  perform private.log_admin_action('report.start_review', p_kind || '_report', p_report_id);
  return jsonb_build_object('result', 'reviewing');
end;
$$;

-- dismiss: nothing wrong. remove: suspend the user or delete the activity,
-- and close the other open reports about the same thing.
create or replace function public.admin_review_report(
  p_kind text,
  p_report_id uuid,
  p_decision text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := private.require_admin();
  note text := left(nullif(btrim(coalesce(p_note, '')), ''), 1000);
  current_status text;
  target_id uuid;
  report_reason text;
  closed_by uuid;
  closed_on timestamptz;
  taken text;
begin
  if p_decision not in ('dismiss', 'remove') then
    raise exception 'Unknown decision.';
  end if;

  if p_kind = 'user' then
    select status, reported_user_id, reason, reviewed_by, reviewed_at
    into current_status, target_id, report_reason, closed_by, closed_on
    from public.user_reports where id = p_report_id for update;
  elsif p_kind = 'activity' then
    select status, activity_id, reason, reviewed_by, reviewed_at
    into current_status, target_id, report_reason, closed_by, closed_on
    from public.activity_reports where id = p_report_id for update;
  else
    raise exception 'Unknown report type.';
  end if;

  if current_status is null then
    return jsonb_build_object('result', 'not_found');
  end if;
  if current_status in ('resolved', 'dismissed') then
    return jsonb_build_object('result', 'already_closed',
      'status', current_status, 'reviewed_by', private.user_card(closed_by),
      'reviewed_at', closed_on);
  end if;

  if p_decision = 'dismiss' then
    taken := 'none';
    if p_kind = 'user' then
      update public.user_reports
      set status = 'dismissed', reviewed_at = now(), reviewed_by = me,
        action_taken = taken, admin_note = note
      where id = p_report_id;
    else
      update public.activity_reports
      set status = 'dismissed', reviewed_at = now(), reviewed_by = me,
        action_taken = taken, admin_note = note
      where id = p_report_id;
    end if;
  elsif p_kind = 'user' then
    taken := 'suspended_user';
    perform private.suspend_user(target_id,
      coalesce(note, 'Reported: ' || replace(report_reason, '_', ' ')));
    update public.user_reports
    set status = 'resolved', reviewed_at = now(), reviewed_by = me,
      action_taken = taken,
      admin_note = case when id = p_report_id then note else admin_note end
    where reported_user_id = target_id and status in ('open', 'reviewing');
  else
    taken := 'deleted_activity';
    update public.activity_reports set admin_note = note where id = p_report_id;
    if target_id is not null then
      perform private.delete_activity(target_id,
        coalesce(note, 'Reported: ' || replace(report_reason, '_', ' ')));
    end if;
    -- Already deleted some other way: just close it.
    update public.activity_reports
    set status = 'resolved', reviewed_at = now(), reviewed_by = me, action_taken = taken
    where id = p_report_id and status in ('open', 'reviewing');
  end if;

  perform private.log_admin_action('report.' || p_decision, p_kind || '_report', p_report_id,
    jsonb_build_object('action', taken, 'note', note, 'target_id', target_id));
  return jsonb_build_object('result', 'done', 'action', taken);
end;
$$;

-- ---- Support --------------------------------------------------------------------

create or replace function public.admin_list_tickets(
  p_status text default 'open',
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
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

  with filtered as (
    select
      t.id, t.email, t.category, left(t.message, 200) as message, t.status,
      t.created_at, t.replied_at, t.closed_at, t.app_version,
      coalesce(array_length(t.screenshot_paths, 1), 0) as screenshot_count,
      private.user_card(t.user_id) as "user",
      (select count(*) from public.support_replies r
        where r.ticket_id = t.id and r.email_status = 'sent') as reply_count,
      exists (select 1 from public.support_replies r
        where r.ticket_id = t.id and r.email_status = 'failed'
          and r.created_at > coalesce(t.replied_at, '-infinity')) as last_send_failed
    from public.support_tickets t
    where (coalesce(p_status, 'all') = 'all' or t.status = p_status)
      and (term is null
        or t.email ilike '%' || term || '%'
        or t.message ilike '%' || term || '%'
        or t.id::text ilike term || '%')
  )
  select jsonb_build_object(
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(f) order by f.created_at desc)
      from (select * from filtered order by created_at desc
        limit lim offset greatest(coalesce(p_offset, 0), 0)) f
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$$;

create or replace function public.admin_get_ticket(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.require_admin();

  select jsonb_build_object(
    'ticket', to_jsonb(t) - 'reply_token' - 'reply',
    'user', private.user_card(t.user_id),
    'replies', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'body', r.body, 'email_status', r.email_status,
        'error', r.error, 'created_at', r.created_at,
        'admin', private.user_card(r.admin_id)
      ) order by r.created_at)
      from public.support_replies r where r.ticket_id = t.id
    ), '[]'::jsonb),
    'other_tickets', (
      select count(*) from public.support_tickets o
      where o.id <> t.id and (o.user_id = t.user_id or o.email = t.email)
    )
  )
  into result
  from public.support_tickets t
  where t.id = p_ticket_id;

  if result is null then
    raise exception 'Ticket not found.' using errcode = 'P0002';
  end if;
  return result;
end;
$$;

create or replace function public.admin_set_ticket_status(p_ticket_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.require_admin();
  if p_status not in ('open', 'closed') then
    raise exception 'Unknown status.';
  end if;

  update public.support_tickets
  set status = case
      when p_status = 'closed' then 'closed'
      when replied_at is not null then 'replied'
      else 'open'
    end,
    closed_at = case when p_status = 'closed' then now() end
  where id = p_ticket_id
    and (p_status = 'closed') = (status <> 'closed');

  if not found then
    return jsonb_build_object('result', 'unchanged');
  end if;
  perform private.log_admin_action(
    case when p_status = 'closed' then 'support.close' else 'support.reopen' end,
    'ticket', p_ticket_id);
  return jsonb_build_object('result', 'updated');
end;
$$;

-- ---- Audit log ------------------------------------------------------------------

create or replace function public.admin_audit_log(
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  lim integer := private.clamp_limit(p_limit);
begin
  perform private.require_admin();

  return jsonb_build_object(
    'total', (select count(*) from private.admin_audit_log),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id, 'action', l.action, 'target_type', l.target_type,
        'target_id', l.target_id, 'details', l.details, 'created_at', l.created_at,
        'admin', private.user_card(l.admin_id)
      ) order by l.created_at desc)
      from (select * from private.admin_audit_log order by created_at desc
        limit lim offset greatest(coalesce(p_offset, 0), 0)) l
    ), '[]'::jsonb)
  );
end;
$$;

-- ---- Grants ---------------------------------------------------------------------

do $$
declare
  fn text;
begin
  foreach fn in array array[
    'public.admin_stats(integer)',
    'public.admin_list_users(text, text, integer, integer)',
    'public.admin_get_user(uuid)',
    'public.admin_suspend_user(uuid, text)',
    'public.admin_restore_user(uuid)',
    'public.admin_list_activities(text, text, integer, integer)',
    'public.admin_get_activity(uuid)',
    'public.admin_delete_activity(uuid, text)',
    'public.admin_list_reports(text, text, integer, integer)',
    'public.admin_start_review(text, uuid)',
    'public.admin_review_report(text, uuid, text, text)',
    'public.admin_list_tickets(text, text, integer, integer)',
    'public.admin_get_ticket(uuid)',
    'public.admin_set_ticket_status(uuid, text)',
    'public.admin_audit_log(integer, integer)'
  ] loop
    execute format('revoke all on function %s from public, anon', fn);
    execute format('grant execute on function %s to authenticated', fn);
  end loop;
end;
$$;

commit;
