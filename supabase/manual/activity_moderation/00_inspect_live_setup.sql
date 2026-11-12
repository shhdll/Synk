-- Activity moderation, phase 0: read-only checks of the live project.
-- Run in the Supabase SQL Editor BEFORE anything else and keep the output.
-- Nothing here changes data.

-- 1. Every policy on activities (the table and its insert/update policies
--    were made in the dashboard, so they aren't in the repo). finish_activity_save
--    is security definer, so any rule here that isn't host = you or
--    "not suspended" needs adding to it.
select policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'activities'
order by cmd, policyname;

-- 2. The activity photo storage policies. Keep this output: the rollback
--    recreates "owner insert" and "owner update" from 20261014100400, which
--    should match what you see here.
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
  and policyname like 'activity-photos:%'
order by policyname;

-- 3. The photo bucket's current limits. lockdown_rollback.sql sets them back
--    to what this showed on 2026-11-12 (image/jpeg and image/png, 5 MiB);
--    update it if they've changed since.
select id, public, allowed_mime_types, file_size_limit
from storage.buckets
where id = 'activity-photos';

-- 4. The activities columns and their types. The migration expects the
--    columns the app writes today; edit_version must not exist yet.
select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'activities'
order by ordinal_position;

-- 5. Triggers on activities. They all run inside finish_activity_save;
--    the known messages it maps are the schedule, capacity, 3-month and
--    end-time ones.
select tgname, pg_get_triggerdef(oid)
from pg_trigger
where tgrelid = 'public.activities'::regclass and not tgisinternal
order by tgname;

-- 6. Who can write activities directly today.
select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public' and table_name = 'activities'
  and grantee in ('anon', 'authenticated', 'service_role')
order by grantee, privilege_type;

-- 7. The suspension check the functions use exists.
select to_regprocedure('private.is_suspended(uuid)') as is_suspended,
       to_regclass('private.user_suspensions') as user_suspensions;
