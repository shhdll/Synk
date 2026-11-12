-- Activity moderation, phase 4: stop direct writes.
--
-- Run in the SQL Editor ONLY after the app version that saves through the
-- save-activity Edge Function is released and tested. Kept out of
-- supabase/migrations on purpose, so `supabase db push` can't run it early.
--
-- After this, app versions that still write activities directly can no
-- longer create or edit activities or upload their photos (they show their
-- usual "couldn't create / save" message). Viewing, joining, leaving,
-- deleting and chat keep working. Undo with lockdown_rollback.sql.
--
-- Safe to run again.

begin;

-- Activities: content only through finish_activity_save (service_role).
-- Reading and deleting stay; security definer functions (host transfer,
-- joins, waitlist, schedule resolution, blocking, admin) run as their
-- owner and aren't affected.
revoke insert, update on table public.activities from anon, authenticated;

-- Activity photos: only the Edge Function uploads, so a host can't replace
-- a checked photo afterwards. Owner delete and public read stay.
drop policy if exists "activity-photos: owner insert" on storage.objects;
drop policy if exists "activity-photos: owner update" on storage.objects;

-- The bucket itself only takes what the function stores.
update storage.buckets
set allowed_mime_types = array['image/jpeg'],
    file_size_limit = 2000000
where id = 'activity-photos';

commit;
