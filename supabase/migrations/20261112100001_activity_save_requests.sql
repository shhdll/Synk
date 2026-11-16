-- Activity content moderation, phase 1: the server side of `save-activity`.
--
-- Only adds things, so the app versions that still write activities
-- directly keep working until the lock-down (supabase/manual/
-- activity_moderation/04_lockdown.sql) is run after the new app is out.
--
--   * activities.edit_version: goes up only when something the host edits
--     changes (text, time, place, capacity, visibility, setting, category,
--     photo), never for joins, counts or a host transfer. Saves send the
--     version they started from, so a save over a newer one is refused
--     instead of silently winning.
--   * private.activity_save_requests: one row per save request, for
--     idempotency, leases, attempt tokens, rate limits and photo cleanup.
--     It holds ids, a hash, statuses and result codes, never activity text
--     or photos.
--   * begin_activity_save / finish_activity_save / fail_activity_save:
--     only the Edge Function can call them (service_role). finish is the
--     only place a moderated activity is written, in one transaction, so
--     the activity triggers and their notifications run once per request.
--
-- Safe to run again.

begin;

-- ---- Edit version -----------------------------------------------------------------

alter table public.activities
  add column if not exists edit_version integer not null default 1;

-- Computed from the old row, so nobody can set it directly.
create or replace function private.set_activity_edit_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.edit_version := 1;
    return new;
  end if;

  if (new.title, new.description, new.starts_at, new.ends_at,
      new.location_name, new.location_address, new.latitude, new.longitude,
      new.max_participants, new.is_public, new.setting,
      new.category_emoji, new.category_label, new.photo_url)
     is distinct from
     (old.title, old.description, old.starts_at, old.ends_at,
      old.location_name, old.location_address, old.latitude, old.longitude,
      old.max_participants, old.is_public, old.setting,
      old.category_emoji, old.category_label, old.photo_url) then
    new.edit_version := old.edit_version + 1;
  else
    new.edit_version := old.edit_version;
  end if;
  return new;
end;
$$;

revoke all on function private.set_activity_edit_version() from public, anon, authenticated;

drop trigger if exists activities_edit_version on public.activities;
create trigger activities_edit_version
  before insert or update on public.activities
  for each row execute function private.set_activity_edit_version();

-- ---- Save requests ----------------------------------------------------------------

create table if not exists private.activity_save_requests (
  request_id uuid primary key,
  user_id uuid not null references public.users (id) on delete cascade,
  activity_id uuid not null,
  operation text not null check (operation in ('create', 'update')),
  -- SHA-256 of the cleaned-up request, worked out by the Edge Function.
  payload_hash text not null check (payload_hash ~ '^[0-9a-f]{64}$'),
  status text not null
    check (status in ('processing', 'succeeded', 'failed_final', 'failed_retryable')),
  -- Goes up on every takeover; only the current attempt may finish.
  attempt integer not null default 1 check (attempt between 1 and 5),
  lease_until timestamptz,
  result_code text,
  result_fields text[],
  result_reason text,
  error_sqlstate text,
  -- Where this request's new photo goes: <user>/<activity>.<request>.jpg
  photo_path text,
  -- A file to delete later (an unused upload, or a replaced photo).
  cleanup_path text,
  cleanup_pending boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists activity_save_requests_user_created_idx
  on private.activity_save_requests (user_id, created_at desc);
create index if not exists activity_save_requests_processing_idx
  on private.activity_save_requests (activity_id)
  where status = 'processing';

-- RLS on with no policies: no app user can read or write it. Not forced,
-- so the security definer functions below (run as the owner) still can.
alter table private.activity_save_requests enable row level security;
revoke all on table private.activity_save_requests from public, anon, authenticated;

-- The response the app gets for a request row. Activity rows are read
-- fresh, and only for their host, so the table never stores content.
create or replace function private.activity_save_response(
  saved private.activity_save_requests
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'result', case when saved.status = 'processing' then 'busy' else saved.result_code end,
    'request_id', saved.request_id,
    'fields', case when saved.result_fields is not null then to_jsonb(saved.result_fields) end,
    'reason', saved.result_reason,
    'retry_after_seconds', case when saved.status = 'processing' then
      greatest(1, least(5, ceil(extract(epoch from (saved.lease_until - now())))::integer))
    end,
    'activity', case when saved.result_code in ('saved', 'already_exists', 'conflict') then (
      select to_jsonb(a) from public.activities a
      where a.id = saved.activity_id and a.host_id = saved.user_id
    ) end
  ));
$$;

revoke all on function private.activity_save_response(private.activity_save_requests)
  from public, anon, authenticated;

-- The storage path of one of our public activity photo URLs, or null.
create or replace function private.activity_photo_path(photo_url text)
returns text
language sql
immutable
set search_path = ''
as $$
  select substring(photo_url from '/storage/v1/object/public/activity-photos/([^?#]+)');
$$;

revoke all on function private.activity_photo_path(text) from public, anon, authenticated;

-- ---- begin ------------------------------------------------------------------------

-- Before moderation. Returns {"action": "proceed", "attempt": n} or
-- {"action": "respond", "response": {...}}, plus "cleanup_paths": photo
-- files of this user's earlier requests that the function should delete.
--
-- Network retries and replays of a stored result don't count toward the
-- rate limit; only new request ids do. A request may run at most 5 times.
create or replace function public.begin_activity_save(
  p_user_id uuid,
  p_request_id uuid,
  p_activity_id uuid,
  p_operation text,
  p_payload_hash text,
  p_photo_path text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing private.activity_save_requests;
  cleanup text[];
  recent_count integer;
  daily_count integer;
  wait_seconds integer;
begin
  if p_user_id is null or p_request_id is null or p_activity_id is null
     or p_operation not in ('create', 'update')
     or p_payload_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'begin_activity_save: invalid arguments';
  end if;

  -- One begin at a time per user, so the checks below can't race.
  perform pg_advisory_xact_lock(hashtextextended('activity_save:' || p_user_id::text, 0));

  if private.is_suspended(p_user_id) then
    return jsonb_build_object('action', 'respond',
      'response', jsonb_build_object('result', 'suspended', 'request_id', p_request_id),
      'cleanup_paths', '[]'::jsonb);
  end if;

  -- Old rows go; ones that still have a file to delete stay until it's done.
  delete from private.activity_save_requests
  where user_id = p_user_id
    and created_at < now() - interval '7 days'
    and status <> 'processing'
    and not cleanup_pending;

  -- Crashed attempts of other requests: their upload is unused.
  update private.activity_save_requests
  set status = 'failed_retryable', result_code = 'save_failed', lease_until = null,
      cleanup_path = photo_path, cleanup_pending = photo_path is not null,
      updated_at = now()
  where user_id = p_user_id
    and request_id <> p_request_id
    and status = 'processing'
    and lease_until <= now();

  -- Files to delete now. Cleared here; a delete that fails leaves an
  -- unlinked file behind (see the docs).
  with done as (
    update private.activity_save_requests
    set cleanup_pending = false, updated_at = now()
    where user_id = p_user_id
      and request_id <> p_request_id
      and cleanup_pending
      and cleanup_path is not null
    returning cleanup_path
  )
  select coalesce(array_agg(cleanup_path), '{}') into cleanup from done;

  select * into existing
  from private.activity_save_requests
  where request_id = p_request_id
  for update;

  if found then
    -- Someone else's id, or the same id with other content: never run it.
    if existing.user_id <> p_user_id
       or existing.payload_hash <> p_payload_hash
       or existing.activity_id <> p_activity_id
       or existing.operation <> p_operation then
      return jsonb_build_object('action', 'respond',
        'response', jsonb_build_object('result', 'request_mismatch', 'request_id', p_request_id),
        'cleanup_paths', to_jsonb(cleanup));
    end if;

    -- Already decided: the same answer again, with nothing re-run.
    if existing.status in ('succeeded', 'failed_final') then
      return jsonb_build_object('action', 'respond',
        'response', private.activity_save_response(existing) || jsonb_build_object('replayed', true),
        'cleanup_paths', to_jsonb(cleanup));
    end if;

    -- Still running.
    if existing.status = 'processing' and existing.lease_until > now() then
      return jsonb_build_object('action', 'respond',
        'response', private.activity_save_response(existing),
        'cleanup_paths', to_jsonb(cleanup));
    end if;

    -- Retryable, or a crashed attempt: run it again, up to 5 times.
    if existing.attempt >= 5 then
      update private.activity_save_requests
      set status = 'failed_final', result_code = 'too_many_attempts',
          result_fields = null, result_reason = null, lease_until = null,
          cleanup_path = coalesce(cleanup_path, photo_path),
          cleanup_pending = cleanup_pending or photo_path is not null,
          updated_at = now()
      where request_id = p_request_id
      returning * into existing;
      return jsonb_build_object('action', 'respond',
        'response', private.activity_save_response(existing),
        'cleanup_paths', to_jsonb(cleanup));
    end if;
  end if;

  -- Another save of this user, or of this activity, still running.
  if exists (
    select 1 from private.activity_save_requests r
    where r.request_id <> p_request_id
      and r.status = 'processing'
      and r.lease_until > now()
      and (r.user_id = p_user_id or r.activity_id = p_activity_id)
  ) then
    return jsonb_build_object('action', 'respond',
      'response', jsonb_build_object('result', 'busy', 'request_id', p_request_id,
        'retry_after_seconds', 3),
      'cleanup_paths', to_jsonb(cleanup));
  end if;

  if existing.request_id is not null then
    update private.activity_save_requests
    set status = 'processing', attempt = attempt + 1,
        lease_until = now() + interval '45 seconds',
        result_code = null, result_fields = null, result_reason = null,
        error_sqlstate = null, photo_path = p_photo_path, updated_at = now()
    where request_id = p_request_id
    returning * into existing;
    return jsonb_build_object('action', 'proceed', 'attempt', existing.attempt,
      'cleanup_paths', to_jsonb(cleanup));
  end if;

  -- A new request: rate limits.
  select count(*) filter (where created_at > now() - interval '10 minutes'),
         count(*) filter (where created_at > now() - interval '24 hours')
  into recent_count, daily_count
  from private.activity_save_requests
  where user_id = p_user_id;

  if recent_count >= 10 or daily_count >= 50 then
    select greatest(1, ceil(extract(epoch from (min(created_at) + case
             when recent_count >= 10 then interval '10 minutes' else interval '24 hours' end
             - now())))::integer)
    into wait_seconds
    from private.activity_save_requests
    where user_id = p_user_id
      and created_at > now() - case
        when recent_count >= 10 then interval '10 minutes' else interval '24 hours' end;
    return jsonb_build_object('action', 'respond',
      'response', jsonb_build_object('result', 'rate_limited', 'request_id', p_request_id,
        'retry_after_seconds', wait_seconds),
      'cleanup_paths', to_jsonb(cleanup));
  end if;

  insert into private.activity_save_requests (
    request_id, user_id, activity_id, operation, payload_hash,
    status, attempt, lease_until, photo_path
  ) values (
    p_request_id, p_user_id, p_activity_id, p_operation, p_payload_hash,
    'processing', 1, now() + interval '45 seconds', p_photo_path
  );

  return jsonb_build_object('action', 'proceed', 'attempt', 1,
    'cleanup_paths', to_jsonb(cleanup));
end;
$$;

-- ---- fail -------------------------------------------------------------------------

-- Moderation, the photo check, the upload or anything else failed before
-- finish. Records the outcome and gives the lease back straight away, so
-- an immediate retry runs again instead of getting "busy". Returns
-- {"response": {...}, "cleanup_path": text|null}: this request's unused
-- upload to delete now, only when this attempt was still the current one.
create or replace function public.fail_activity_save(
  p_user_id uuid,
  p_request_id uuid,
  p_attempt integer,
  p_result_code text,
  p_retryable boolean,
  p_fields text[] default null,
  p_reason text default null,
  p_photo_path text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  saved private.activity_save_requests;
begin
  if p_result_code not in ('rejected', 'photo_invalid', 'invalid',
                           'moderation_unavailable', 'storage_failed', 'save_failed') then
    raise exception 'fail_activity_save: unknown result code';
  end if;

  update private.activity_save_requests
  set status = case when p_retryable then 'failed_retryable' else 'failed_final' end,
      result_code = p_result_code,
      result_fields = p_fields,
      result_reason = p_reason,
      lease_until = null,
      cleanup_path = p_photo_path,
      cleanup_pending = p_photo_path is not null,
      updated_at = now()
  where request_id = p_request_id
    and user_id = p_user_id
    and attempt = p_attempt
    and status = 'processing'
  returning * into saved;

  if not found then
    -- A newer attempt took over (or finish already saved): report what
    -- that one says, and delete nothing, since it may use the same file.
    select * into saved from private.activity_save_requests
    where request_id = p_request_id and user_id = p_user_id;
    if not found then
      return jsonb_build_object('response',
        jsonb_build_object('result', 'save_failed', 'request_id', p_request_id),
        'cleanup_path', null);
    end if;
    return jsonb_build_object('response', private.activity_save_response(saved),
      'cleanup_path', null);
  end if;

  return jsonb_build_object('response', private.activity_save_response(saved),
    'cleanup_path', p_photo_path);
end;
$$;

-- ---- finish -----------------------------------------------------------------------

-- After moderation passed and any new photo is uploaded: writes the
-- activity in this one transaction. Returns {"response": {...},
-- "cleanup_path": text|null}; cleanup_path is a file the function should
-- delete now (the replaced photo, or this request's unused upload).
create or replace function public.finish_activity_save(
  p_user_id uuid,
  p_request_id uuid,
  p_attempt integer,
  p_activity jsonb,
  p_expected_version integer default null,
  p_photo_action text default 'none',
  p_photo_url text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  saved private.activity_save_requests;
  current_row public.activities;
  new_photo_url text;
  old_photo_path text;
  code text;
  final boolean := true;
  state text;
  message text;
  cleanup text;
begin
  select * into saved
  from private.activity_save_requests
  where request_id = p_request_id and user_id = p_user_id
  for update;

  if not found then
    return jsonb_build_object('response',
      jsonb_build_object('result', 'save_failed', 'request_id', p_request_id),
      'cleanup_path', null);
  end if;

  -- A newer attempt took over. Its photo has the same path, so nothing is
  -- deleted here.
  if saved.status <> 'processing' or saved.attempt <> p_attempt then
    return jsonb_build_object('response', private.activity_save_response(saved),
      'cleanup_path', null);
  end if;

  if p_photo_action not in ('none', 'keep', 'remove', 'replace')
     or (p_photo_action = 'replace') <> (p_photo_url is not null)
     or (saved.operation = 'create' and p_photo_action not in ('none', 'replace'))
     or (saved.operation = 'update' and p_photo_action = 'none')
     or (saved.operation = 'update') <> (p_expected_version is not null) then
    raise exception 'finish_activity_save: invalid arguments';
  end if;

  if private.is_suspended(p_user_id) then
    code := 'suspended';
  elsif saved.operation = 'create' then
    select * into current_row from public.activities where id = saved.activity_id;
    if found then
      code := case when current_row.host_id = p_user_id then 'already_exists' else 'conflict' end;
    end if;
  else
    select * into current_row from public.activities where id = saved.activity_id for update;
    if not found then
      code := 'not_found';
    elsif current_row.host_id is distinct from p_user_id then
      code := 'not_host';
    elsif current_row.edit_version <> p_expected_version then
      code := 'conflict';
    end if;
  end if;

  if code is null then
    begin
      if saved.operation = 'create' then
        insert into public.activities (
          id, host_id, title, description, starts_at, ends_at,
          location_name, location_address, latitude, longitude,
          max_participants, is_public, setting, category_emoji, category_label,
          photo_url
        ) values (
          saved.activity_id, p_user_id,
          p_activity->>'title',
          p_activity->>'description',
          (p_activity->>'starts_at')::timestamptz,
          (p_activity->>'ends_at')::timestamptz,
          p_activity->>'location_name',
          p_activity->>'location_address',
          (p_activity->>'latitude')::double precision,
          (p_activity->>'longitude')::double precision,
          (p_activity->>'max_participants')::integer,
          (p_activity->>'is_public')::boolean,
          p_activity->>'setting',
          p_activity->>'category_emoji',
          p_activity->>'category_label',
          p_photo_url
        );
      else
        new_photo_url := case p_photo_action
          when 'keep' then current_row.photo_url
          when 'remove' then null
          else p_photo_url
        end;
        update public.activities set
          title = p_activity->>'title',
          description = p_activity->>'description',
          starts_at = (p_activity->>'starts_at')::timestamptz,
          ends_at = (p_activity->>'ends_at')::timestamptz,
          location_name = p_activity->>'location_name',
          location_address = p_activity->>'location_address',
          latitude = (p_activity->>'latitude')::double precision,
          longitude = (p_activity->>'longitude')::double precision,
          max_participants = (p_activity->>'max_participants')::integer,
          is_public = (p_activity->>'is_public')::boolean,
          setting = p_activity->>'setting',
          category_emoji = p_activity->>'category_emoji',
          category_label = p_activity->>'category_label',
          photo_url = new_photo_url
        where id = saved.activity_id;

        if p_photo_action in ('remove', 'replace') then
          old_photo_path := private.activity_photo_path(current_row.photo_url);
        end if;
      end if;
      code := 'saved';
    exception when others then
      -- Only known checks get their own code; nothing raw goes back.
      get stacked diagnostics state = returned_sqlstate, message = message_text;
      code := case
        when message like 'You already have an activity scheduled%' then 'schedule_conflict'
        when message like 'Capacity cannot be lower than the current number of participants%'
          then 'capacity_below_participants'
        when message like '%can only be scheduled up to%' then 'schedule_too_far'
        when message like 'The activity end time must be after its start time%'
          then 'invalid_time_range'
        when state = '23514' then 'invalid'
        else 'save_failed'
      end;
      final := code <> 'save_failed';
    end;
  end if;

  -- Which file to delete now: the replaced photo after a save, or this
  -- request's own upload when nothing was saved with it.
  if code = 'saved' then
    cleanup := case when old_photo_path is distinct from saved.photo_path then old_photo_path end;
  elsif p_photo_action = 'replace' then
    cleanup := saved.photo_path;
  end if;

  update private.activity_save_requests
  set status = case when code = 'saved' then 'succeeded'
                    when final then 'failed_final' else 'failed_retryable' end,
      result_code = code,
      result_fields = null,
      error_sqlstate = state,
      lease_until = null,
      cleanup_path = cleanup,
      cleanup_pending = cleanup is not null,
      updated_at = now()
  where request_id = p_request_id
  returning * into saved;

  return jsonb_build_object(
    'response', private.activity_save_response(saved),
    'cleanup_path', cleanup,
    'sqlstate', state
  );
end;
$$;

-- Only the Edge Function (service_role) may call these.
revoke all on function public.begin_activity_save(uuid, uuid, uuid, text, text, text)
  from public, anon, authenticated;
revoke all on function public.fail_activity_save(uuid, uuid, integer, text, boolean, text[], text, text)
  from public, anon, authenticated;
revoke all on function public.finish_activity_save(uuid, uuid, integer, jsonb, integer, text, text)
  from public, anon, authenticated;
grant execute on function public.begin_activity_save(uuid, uuid, uuid, text, text, text) to service_role;
grant execute on function public.fail_activity_save(uuid, uuid, integer, text, boolean, text[], text, text) to service_role;
grant execute on function public.finish_activity_save(uuid, uuid, integer, jsonb, integer, text, text) to service_role;

commit;
