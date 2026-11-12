-- Scenario tests for 20261112100000_activity_save_requests.sql.
-- Each block asserts; the first failure stops the run (ON_ERROR_STOP).
-- Run with ./run.sh.

\set ON_ERROR_STOP on
set client_min_messages = notice;

-- Short names for the users and hashes.
create temp table ids as select
  '00000000-0000-0000-0000-00000000000a'::uuid as amal,
  '00000000-0000-0000-0000-00000000000b'::uuid as sara,
  '00000000-0000-0000-0000-00000000000c'::uuid as suspended,
  repeat('a', 64) as hash_a,
  repeat('b', 64) as hash_b;
grant select on ids to service_role;

create function pg_temp.activity(title text default 'Padel night', max_participants int default 4)
returns jsonb language sql as $$
  select jsonb_build_object(
    'title', title, 'description', null,
    'starts_at', (now() + interval '2 days')::text,
    'ends_at', (now() + interval '2 days 2 hours')::text,
    'location_name', 'Kingdom Arena', 'location_address', null,
    'latitude', 24.7, 'longitude', 46.6,
    'max_participants', max_participants, 'is_public', true, 'setting', 'indoor',
    'category_emoji', null, 'category_label', null);
$$;

-- ---- Create, replay and mismatch ----------------------------------------------------

do $$
declare
  i record; r jsonb; f jsonb;
begin
  select * into i from ids;
  -- Earlier blocks' requests fall outside the 10-minute rate-limit window.
  update private.activity_save_requests set created_at = now() - interval '1 hour';

  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001', 'create', i.hash_a);
  assert r->>'action' = 'proceed' and (r->>'attempt')::int = 1, 'new request proceeds: ' || r::text;

  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000001', 1,
    pg_temp.activity(), null, 'none', null);
  assert f->'response'->>'result' = 'saved', 'create saved: ' || f::text;
  assert (f->'response'->'activity'->>'edit_version')::int = 1, 'version starts at 1';
  assert (f->'response'->'activity'->>'host_id')::uuid = i.amal, 'host is the verified user';
  assert (select count(*) from public.trigger_runs) = 1, 'triggers ran once';

  -- Lost response: same id and content replays, nothing runs again.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001', 'create', i.hash_a);
  assert r->>'action' = 'respond' and r->'response'->>'result' = 'saved'
    and (r->'response'->>'replayed')::boolean, 'replay returns the stored result: ' || r::text;
  assert r->'response'->'activity'->>'title' = 'Padel night', 'replay includes the activity';
  assert (select count(*) from public.trigger_runs) = 1, 'replay ran no triggers';
  assert (select count(*) from public.activities) = 1, 'no duplicate activity';

  -- Same id, different content.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001', 'create', i.hash_b);
  assert r->'response'->>'result' = 'request_mismatch', 'different content is refused: ' || r::text;

  -- Someone else's request id.
  r := public.begin_activity_save(i.sara, '10000000-0000-4000-8000-000000000001',
    '20000000-0000-4000-8000-000000000001', 'create', i.hash_a);
  assert r->'response'->>'result' = 'request_mismatch', 'another user''s id is refused: ' || r::text;

  -- A new request creating the same activity id.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000001', 'create', i.hash_b);
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000002', 1,
    pg_temp.activity('Changed'), null, 'none', null);
  assert f->'response'->>'result' = 'already_exists', 'existing id is not overwritten: ' || f::text;
  assert (select title from public.activities) = 'Padel night', 'existing row unchanged';

  -- Sara creating with Amal's activity id.
  r := public.begin_activity_save(i.sara, '10000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000001', 'create', i.hash_a);
  f := public.finish_activity_save(i.sara, '10000000-0000-4000-8000-000000000003', 1,
    pg_temp.activity(), null, 'none', null);
  assert f->'response'->>'result' = 'conflict' and f->'response'->'activity' is null,
    'someone else''s id: conflict, nothing revealed: ' || f::text;
  raise notice 'ok: create, replay, mismatch, existing ids';
end $$;

-- ---- Update, optimistic locking, host checks ---------------------------------------------

do $$
declare
  i record; r jsonb; f jsonb;
begin
  select * into i from ids;
  -- Earlier blocks' requests fall outside the 10-minute rate-limit window.
  update private.activity_save_requests set created_at = now() - interval '1 hour';

  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000010',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_a);
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000010', 1,
    pg_temp.activity('Padel night 2'), 1, 'keep', null);
  assert f->'response'->>'result' = 'saved', 'update saved: ' || f::text;
  assert (select edit_version from public.activities) = 2, 'version went up';

  -- A second device still on version 1.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000011',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_b);
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000011', 1,
    pg_temp.activity('Stale edit'), 1, 'keep', null);
  assert f->'response'->>'result' = 'conflict', 'stale version: conflict: ' || f::text;
  assert f->'response'->'activity'->>'title' = 'Padel night 2', 'conflict returns the current row';
  assert (select title from public.activities) = 'Padel night 2', 'stale edit not written';

  -- Not the host.
  r := public.begin_activity_save(i.sara, '10000000-0000-4000-8000-000000000012',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_a);
  f := public.finish_activity_save(i.sara, '10000000-0000-4000-8000-000000000012', 1,
    pg_temp.activity('Hijack'), 2, 'keep', null);
  assert f->'response'->>'result' = 'not_host', 'not the host: ' || f::text;
  assert f->'response'->'activity' is null, 'nothing revealed to a non-host';

  -- Deleted.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000013',
    '20000000-0000-4000-8000-000000000099', 'update', i.hash_a);
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000013', 1,
    pg_temp.activity(), 1, 'keep', null);
  assert f->'response'->>'result' = 'not_found', 'deleted activity: ' || f::text;

  -- Host changed while editing (a definer function, like host transfer).
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000014',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_a);
  perform public.stub_transfer_host('20000000-0000-4000-8000-000000000001', i.sara);
  assert (select edit_version from public.activities) = 2, 'host transfer does not bump the version';
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000014', 1,
    pg_temp.activity('After transfer'), 2, 'keep', null);
  assert f->'response'->>'result' = 'not_host', 'host changed: ' || f::text;
  perform public.stub_transfer_host('20000000-0000-4000-8000-000000000001', i.amal);

  -- A non-edit column (like a count) doesn't bump; a client can't set it.
  update public.activities set participants_note = participants_note + 1;
  assert (select edit_version from public.activities) = 2, 'count change does not bump';
  update public.activities set edit_version = 99;
  assert (select edit_version from public.activities) = 2, 'version cannot be set directly';
  raise notice 'ok: update, conflict, not_host, not_found, version rules';
end $$;

-- ---- Database errors become codes --------------------------------------------------

do $$
declare
  i record; f jsonb; n int := 20;
  cases text[][] := array[
    array['Schedule clash', '4', 'schedule_conflict', 'failed_final'],
    array['Padel night 2', '2', 'capacity_below_participants', 'failed_final']
  ];
  c text[];
  req uuid;
begin
  select * into i from ids;
  -- Earlier blocks' requests fall outside the 10-minute rate-limit window.
  update private.activity_save_requests set created_at = now() - interval '1 hour';
  foreach c slice 1 in array cases loop
    n := n + 1;
    req := ('10000000-0000-4000-8000-0000000000' || n)::uuid;
    perform public.begin_activity_save(i.amal, req, '20000000-0000-4000-8000-000000000001', 'update', i.hash_a);
    f := public.finish_activity_save(i.amal, req, 1, pg_temp.activity(c[1], c[2]::int), 2, 'keep', null);
    assert f->'response'->>'result' = c[3], c[3] || ': ' || f::text;
    assert (select status from private.activity_save_requests where request_id = req) = c[4], c[3] || ' status';
    assert not (f->'response' ? 'message'), 'no raw message is returned';
  end loop;

  -- Too far ahead.
  perform public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000031',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_a);
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000031', 1,
    pg_temp.activity() || jsonb_build_object('starts_at', (now() + interval '5 months')::text,
      'ends_at', (now() + interval '5 months 2 hours')::text), 2, 'keep', null);
  assert f->'response'->>'result' = 'schedule_too_far', 'too far: ' || f::text;

  -- End before start.
  perform public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000032',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_a);
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000032', 1,
    pg_temp.activity() || jsonb_build_object('ends_at', (now() + interval '1 day')::text), 2, 'keep', null);
  assert f->'response'->>'result' = 'invalid_time_range', 'end before start: ' || f::text;

  -- A check constraint.
  perform public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000033',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_a);
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000033', 1,
    pg_temp.activity() || jsonb_build_object('setting', 'beach'), 2, 'keep', null);
  assert f->'response'->>'result' = 'invalid', 'check constraint: ' || f::text;

  -- Anything else: generic and retryable, SQLSTATE kept for logs only.
  perform public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000034',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_a);
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000034', 1,
    pg_temp.activity() || jsonb_build_object('max_participants', 'many'), 2, 'keep', null);
  assert f->'response'->>'result' = 'save_failed', 'unexpected error: ' || f::text;
  assert f->>'sqlstate' = '22P02', 'sqlstate kept for logs';
  assert (select status from private.activity_save_requests
          where request_id = '10000000-0000-4000-8000-000000000034') = 'failed_retryable', 'save_failed is retryable';
  assert (select title from public.activities) = 'Padel night 2', 'failed saves wrote nothing';
  raise notice 'ok: database errors mapped to codes';
end $$;

-- ---- Leases, fail, takeovers, attempts ------------------------------------------------

do $$
declare
  i record; r jsonb; f jsonb;
begin
  select * into i from ids;
  -- Earlier blocks' requests fall outside the 10-minute rate-limit window.
  update private.activity_save_requests set created_at = now() - interval '1 hour';

  -- Moderation down: fail releases the lease, an immediate retry runs.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000040',
    '20000000-0000-4000-8000-000000000040', 'create', i.hash_a);
  f := public.fail_activity_save(i.amal, '10000000-0000-4000-8000-000000000040', 1,
    'moderation_unavailable', true);
  assert f->'response'->>'result' = 'moderation_unavailable', 'fail stores the code: ' || f::text;
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000040',
    '20000000-0000-4000-8000-000000000040', 'create', i.hash_a);
  assert r->>'action' = 'proceed' and (r->>'attempt')::int = 2, 'immediate retry is not busy: ' || r::text;

  -- While it runs, the same request is busy.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000040',
    '20000000-0000-4000-8000-000000000040', 'create', i.hash_a);
  assert r->'response'->>'result' = 'busy' and (r->'response'->>'retry_after_seconds')::int between 1 and 5,
    'running request is busy: ' || r::text;

  -- Another save of the same user is busy too.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000041',
    '20000000-0000-4000-8000-000000000041', 'create', i.hash_a);
  assert r->'response'->>'result' = 'busy', 'one save at a time per user: ' || r::text;

  -- And another user's save of the same activity id.
  r := public.begin_activity_save(i.sara, '10000000-0000-4000-8000-000000000042',
    '20000000-0000-4000-8000-000000000040', 'create', i.hash_a);
  assert r->'response'->>'result' = 'busy', 'one save at a time per activity: ' || r::text;

  -- An old attempt finishing late can't overwrite the current one.
  f := public.fail_activity_save(i.amal, '10000000-0000-4000-8000-000000000040', 1, 'rejected', false, array['title']);
  assert f->'response'->>'result' = 'busy' and f->>'cleanup_path' is null,
    'stale attempt changes nothing: ' || f::text;
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000040', 1,
    pg_temp.activity(), null, 'none', null);
  assert f->'response'->>'result' = 'busy' and f->>'cleanup_path' is null, 'stale finish writes nothing: ' || f::text;

  -- Rejected is final, with its fields, and replays.
  f := public.fail_activity_save(i.amal, '10000000-0000-4000-8000-000000000040', 2, 'rejected', false,
    array['title', 'photo']);
  assert f->'response'->>'result' = 'rejected' and f->'response'->'fields' = '["title", "photo"]'::jsonb,
    'rejected with fields: ' || f::text;
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000040',
    '20000000-0000-4000-8000-000000000040', 'create', i.hash_a);
  assert r->'response'->>'result' = 'rejected' and r->'response'->'fields' = '["title", "photo"]'::jsonb,
    'rejected replays: ' || r::text;

  -- A crashed attempt: the lease runs out and a retry takes over.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000043',
    '20000000-0000-4000-8000-000000000043', 'create', i.hash_a);
  update private.activity_save_requests set lease_until = now() - interval '1 second'
  where request_id = '10000000-0000-4000-8000-000000000043';
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000043',
    '20000000-0000-4000-8000-000000000043', 'create', i.hash_a);
  assert r->>'action' = 'proceed' and (r->>'attempt')::int = 2, 'expired lease is taken over: ' || r::text;

  -- At most 5 runs of one request.
  update private.activity_save_requests set attempt = 5, status = 'failed_retryable', lease_until = null
  where request_id = '10000000-0000-4000-8000-000000000043';
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000043',
    '20000000-0000-4000-8000-000000000043', 'create', i.hash_a);
  assert r->'response'->>'result' = 'too_many_attempts', 'attempt cap: ' || r::text;

  -- Suspended users.
  r := public.begin_activity_save(i.suspended, '10000000-0000-4000-8000-000000000044',
    '20000000-0000-4000-8000-000000000044', 'create', i.hash_a);
  assert r->'response'->>'result' = 'suspended', 'suspended at begin: ' || r::text;
  r := public.begin_activity_save(i.sara, '10000000-0000-4000-8000-000000000045',
    '20000000-0000-4000-8000-000000000045', 'create', i.hash_a);
  insert into private.user_suspensions values (i.sara);
  f := public.finish_activity_save(i.sara, '10000000-0000-4000-8000-000000000045', 1,
    pg_temp.activity(), null, 'none', null);
  assert f->'response'->>'result' = 'suspended', 'suspended during the save: ' || f::text;
  delete from private.user_suspensions where user_id = i.sara;
  assert not exists (select 1 from public.activities where id = '20000000-0000-4000-8000-000000000045'),
    'suspended user created nothing';
  raise notice 'ok: leases, fail, takeover, stale attempts, attempt cap, suspension';
end $$;

-- ---- Rate limit -------------------------------------------------------------------

do $$
declare
  i record; r jsonb; n int; before_count int;
begin
  select * into i from ids;
  -- Earlier blocks' requests fall outside the 10-minute rate-limit window.
  update private.activity_save_requests set created_at = now() - interval '1 hour';
  -- Start from a clean window for Sara.
  delete from private.activity_save_requests where user_id = i.sara;
  for n in 1..10 loop
    r := public.begin_activity_save(i.sara, ('30000000-0000-4000-8000-0000000000' || lpad(n::text, 2, '0'))::uuid,
      ('40000000-0000-4000-8000-0000000000' || lpad(n::text, 2, '0'))::uuid, 'create', i.hash_a);
    assert r->>'action' = 'proceed', 'request ' || n || ' allowed: ' || r::text;
    perform public.fail_activity_save(i.sara, ('30000000-0000-4000-8000-0000000000' || lpad(n::text, 2, '0'))::uuid,
      1, 'invalid', false);
  end loop;
  before_count := (select count(*) from private.activity_save_requests where user_id = i.sara);

  -- Replays of stored results are free.
  r := public.begin_activity_save(i.sara, '30000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000001', 'create', i.hash_a);
  assert r->'response'->>'result' = 'invalid', 'replay still works at the limit: ' || r::text;

  r := public.begin_activity_save(i.sara, '30000000-0000-4000-8000-000000000011',
    '40000000-0000-4000-8000-000000000011', 'create', i.hash_a);
  assert r->'response'->>'result' = 'rate_limited'
    and (r->'response'->>'retry_after_seconds')::int between 1 and 600, 'eleventh new request limited: ' || r::text;
  assert (select count(*) from private.activity_save_requests where user_id = i.sara) = before_count,
    'a limited request leaves no row';
  raise notice 'ok: rate limit counts new request ids only';
end $$;

-- ---- Photos and cleanup -------------------------------------------------------------

do $$
declare
  i record; r jsonb; f jsonb;
  url_old text := 'https://x.supabase.co/storage/v1/object/public/activity-photos/'
    || '00000000-0000-0000-0000-00000000000a/20000000-0000-4000-8000-000000000001.jpg?v=1';
  path_new text := '00000000-0000-0000-0000-00000000000a/20000000-0000-4000-8000-000000000001.10000000-0000-4000-8000-000000000050.jpg';
begin
  select * into i from ids;
  -- Earlier blocks' requests fall outside the 10-minute rate-limit window.
  update private.activity_save_requests set created_at = now() - interval '1 hour';
  update public.activities set photo_url = url_old where id = '20000000-0000-4000-8000-000000000001';

  -- Replace: the old file is returned for deletion, the new one is linked.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000050',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_a, path_new);
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000050', 1,
    pg_temp.activity('Padel night 2'), (select edit_version from public.activities
      where id = '20000000-0000-4000-8000-000000000001'),
    'replace', 'https://x.supabase.co/storage/v1/object/public/activity-photos/' || path_new);
  assert f->'response'->>'result' = 'saved', 'photo replaced: ' || f::text;
  assert f->>'cleanup_path' = '00000000-0000-0000-0000-00000000000a/20000000-0000-4000-8000-000000000001.jpg',
    'old photo returned for deletion: ' || f::text;

  -- A failed save with an upload: the upload is returned for deletion.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000051',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_a, 'amal/new-unused.jpg');
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000051', 1,
    pg_temp.activity('Schedule clash'), (select edit_version from public.activities
      where id = '20000000-0000-4000-8000-000000000001'), 'replace', 'https://x/unused');
  assert f->'response'->>'result' = 'schedule_conflict' and f->>'cleanup_path' = 'amal/new-unused.jpg',
    'unused upload returned for deletion: ' || f::text;
  assert (select photo_url from public.activities where id = '20000000-0000-4000-8000-000000000001')
    like '%' || path_new, 'old photo kept when the edit failed';

  -- An upload that failed half-way: fail hands the file straight back.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000056',
    '20000000-0000-4000-8000-000000000056', 'create', i.hash_a, 'amal/partial.jpg');
  assert r->'cleanup_paths' @> '["amal/new-unused.jpg"]'::jsonb,
    'the unused upload is handed back on the next save: ' || r::text;
  f := public.fail_activity_save(i.amal, '10000000-0000-4000-8000-000000000056', 1,
    'storage_failed', true, null, null, 'amal/partial.jpg');
  assert f->'response'->>'result' = 'storage_failed' and f->>'cleanup_path' = 'amal/partial.jpg',
    'failed upload returned for deletion: ' || f::text;

  -- A crash after uploading: the next save of this user gets the file.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000052',
    '20000000-0000-4000-8000-000000000052', 'create', i.hash_a, 'amal/crashed.jpg');
  assert r->'cleanup_paths' @> '["amal/partial.jpg"]'::jsonb,
    'and the failed upload is confirmed on the one after: ' || r::text;
  update private.activity_save_requests set lease_until = now() - interval '1 second'
  where request_id = '10000000-0000-4000-8000-000000000052';
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000053',
    '20000000-0000-4000-8000-000000000053', 'create', i.hash_a);
  assert r->'cleanup_paths' @> '["amal/crashed.jpg"]'::jsonb
    and not (r->'cleanup_paths' @> '["amal/new-unused.jpg"]'::jsonb),
    'a crashed attempt''s upload is handed back, each file once: ' || r::text;
  perform public.fail_activity_save(i.amal, '10000000-0000-4000-8000-000000000053', 1, 'invalid', false);
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000054',
    '20000000-0000-4000-8000-000000000054', 'create', i.hash_a);
  assert not (r->'cleanup_paths' @> '["amal/crashed.jpg"]'::jsonb), 'each file only once: ' || r::text;
  perform public.fail_activity_save(i.amal, '10000000-0000-4000-8000-000000000054', 1, 'invalid', false);

  -- Remove: the photo goes, its file is returned.
  r := public.begin_activity_save(i.amal, '10000000-0000-4000-8000-000000000055',
    '20000000-0000-4000-8000-000000000001', 'update', i.hash_a);
  f := public.finish_activity_save(i.amal, '10000000-0000-4000-8000-000000000055', 1,
    pg_temp.activity('Padel night 2'), (select edit_version from public.activities
      where id = '20000000-0000-4000-8000-000000000001'), 'remove', null);
  assert f->'response'->>'result' = 'saved' and f->>'cleanup_path' = path_new, 'photo removed: ' || f::text;
  assert (select photo_url from public.activities where id = '20000000-0000-4000-8000-000000000001') is null,
    'photo_url cleared';
  raise notice 'ok: photo replace, remove and cleanup';
end $$;

-- ---- Who may call what ---------------------------------------------------------------

do $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
  begin
    perform public.begin_activity_save('00000000-0000-0000-0000-00000000000a',
      gen_random_uuid(), gen_random_uuid(), 'create', repeat('a', 64));
    assert false, 'app users must not call begin';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.finish_activity_save('00000000-0000-0000-0000-00000000000a',
      gen_random_uuid(), 1, '{}'::jsonb);
    assert false, 'app users must not call finish';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.fail_activity_save('00000000-0000-0000-0000-00000000000a',
      gen_random_uuid(), 1, 'invalid', false);
    assert false, 'app users must not call fail';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from private.activity_save_requests;
    assert false, 'app users must not read save requests';
  exception when insufficient_privilege then null;
  end;
  reset role;

  set local role service_role;
  perform public.begin_activity_save('00000000-0000-0000-0000-00000000000b',
    '10000000-0000-4000-8000-000000000060', gen_random_uuid(), 'create', repeat('a', 64));
  reset role;
  raise notice 'ok: only service_role calls the functions';
end $$;
