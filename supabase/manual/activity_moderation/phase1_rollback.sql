-- Removes 20261112100000_activity_save_requests.sql.
--
-- Only after lockdown_rollback.sql has run and no released app version
-- uses the save-activity function any more: without these functions it
-- can't save anything. Deletes the save-request rows (ids and result codes
-- only, no activity content). The activities themselves are untouched;
-- only their edit_version column goes.

begin;

drop function if exists public.begin_activity_save(uuid, uuid, uuid, text, text, text);
drop function if exists public.finish_activity_save(uuid, uuid, integer, jsonb, integer, text, text);
drop function if exists public.fail_activity_save(uuid, uuid, integer, text, boolean, text[], text, text);
drop function if exists private.activity_save_response(private.activity_save_requests);
drop function if exists private.activity_photo_path(text);
drop table if exists private.activity_save_requests;

drop trigger if exists activities_edit_version on public.activities;
drop function if exists private.set_activity_edit_version();
alter table public.activities drop column if exists edit_version;

commit;
