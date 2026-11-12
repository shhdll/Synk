-- Tests for supabase/manual/activity_moderation/lockdown.sql and its
-- rollback. Run with ./run.sh after test_save_requests.sql.

\set ON_ERROR_STOP on
set client_min_messages = notice;

-- Before: the app can still write directly (phase 1 to 3).
do $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
  insert into public.activities (host_id, title, starts_at, ends_at)
    values ('00000000-0000-0000-0000-00000000000b', 'Direct before lockdown',
            now() + interval '1 day', now() + interval '1 day 2 hours');
  reset role;
  raise notice 'ok: direct writes still allowed before the lock-down';
end $$;

\ir ../../manual/activity_moderation/lockdown.sql

do $$
declare
  target uuid := (select id from public.activities where title = 'Direct before lockdown');
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
  begin
    insert into public.activities (host_id, title, starts_at, ends_at)
      values ('00000000-0000-0000-0000-00000000000b', 'Direct insert',
              now() + interval '1 day', now() + interval '1 day 2 hours');
    assert false, 'direct insert must be refused';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.activities set title = 'Direct update' where id = target;
    assert false, 'direct update must be refused';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into storage.objects (bucket_id, name, owner)
      values ('activity-photos', 'x/y.jpg', '00000000-0000-0000-0000-00000000000b');
    assert false, 'direct photo upload must be refused';
  exception when insufficient_privilege then null;
  end;
  -- Reading, deleting and internal functions still work.
  perform 1 from public.activities;
  perform public.stub_transfer_host(target, '00000000-0000-0000-0000-00000000000a');
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', true);
  delete from public.activities where id = target;
  assert not exists (select 1 from public.activities where id = target), 'host can still delete';
  reset role;

  assert (select allowed_mime_types from storage.buckets where id = 'activity-photos') = array['image/jpeg'],
    'bucket only takes JPEG';
  assert (select file_size_limit from storage.buckets where id = 'activity-photos') = 2000000,
    'bucket size limit';
  assert exists (select 1 from pg_policies where policyname = 'activity-photos: owner delete'),
    'owner delete kept';
  assert exists (select 1 from pg_policies where policyname = 'activity-photos: public read'),
    'public read kept';
  raise notice 'ok: lock-down refuses direct writes, keeps reads, deletes and internal functions';
end $$;

-- Saving through the functions still works after the lock-down.
do $$
declare
  f jsonb;
begin
  -- Out of the rate-limit window left by the earlier tests.
  update private.activity_save_requests set created_at = now() - interval '1 hour',
    lease_until = least(lease_until, now() - interval '1 second');
  set local role service_role;
  f := public.begin_activity_save('00000000-0000-0000-0000-00000000000b',
    '10000000-0000-4000-8000-000000000070', '20000000-0000-4000-8000-000000000070', 'create', repeat('c', 64));
  assert f->>'action' = 'proceed', 'begin after lock-down: ' || f::text;
  f := public.finish_activity_save('00000000-0000-0000-0000-00000000000b',
    '10000000-0000-4000-8000-000000000070', 1,
    jsonb_build_object('title', 'Via function', 'description', null,
      'starts_at', (now() + interval '1 day')::text, 'ends_at', (now() + interval '1 day 2 hours')::text,
      'location_name', 'Court', 'location_address', null, 'latitude', null, 'longitude', null,
      'max_participants', 4, 'is_public', true, 'setting', 'outdoor',
      'category_emoji', null, 'category_label', null), null, 'none', null);
  reset role;
  assert f->'response'->>'result' = 'saved', 'saving through the function after lock-down: ' || f::text;
  raise notice 'ok: the Edge Function path still saves after the lock-down';
end $$;

\ir ../../manual/activity_moderation/lockdown_rollback.sql

do $$
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', true);
  insert into public.activities (host_id, title, starts_at, ends_at)
    values ('00000000-0000-0000-0000-00000000000b', 'Direct after rollback',
            now() + interval '1 day', now() + interval '1 day 2 hours');
  reset role;
  assert exists (select 1 from pg_policies where policyname = 'activity-photos: owner insert'), 'insert policy back';
  assert exists (select 1 from pg_policies where policyname = 'activity-photos: owner update'), 'update policy back';
  assert (select allowed_mime_types from storage.buckets where id = 'activity-photos')
    = array['image/jpeg', 'image/png'], 'bucket types back to the live values';
  assert (select file_size_limit from storage.buckets where id = 'activity-photos') = 5242880,
    'bucket size back to the live value';
  raise notice 'ok: rollback restores direct writes for older app versions';
end $$;

-- Running the lock-down twice is safe.
\ir ../../manual/activity_moderation/lockdown.sql
\ir ../../manual/activity_moderation/lockdown.sql
\ir ../../manual/activity_moderation/lockdown_rollback.sql
