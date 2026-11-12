-- Undoes lockdown.sql: direct activity writes and photo uploads work again,
-- so older app versions can create and edit activities. This also reopens
-- the way around moderation, so use it only while fixing a problem.
--
-- The storage policies are recreated exactly as
-- 20261014100400_activity_photo_host_policies.sql left them. Check them
-- against the output you kept from 00_inspect_live_setup.sql.
--
-- Safe to run again.

begin;

grant insert, update on table public.activities to anon, authenticated;

drop policy if exists "activity-photos: owner insert" on storage.objects;
create policy "activity-photos: owner insert"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'activity-photos'
  and objects.name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.[a-z0-9]+$'
  and (storage.foldername(objects.name))[1] = auth.uid()::text
  and exists (
    select 1
    from public.activities as activity
    where activity.id::text = split_part(storage.filename(objects.name), '.', 1)
      and activity.host_id = auth.uid()
  )
);

drop policy if exists "activity-photos: owner update" on storage.objects;
create policy "activity-photos: owner update"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'activity-photos'
  and exists (
    select 1
    from public.activities as activity
    where activity.id::text = split_part(storage.filename(objects.name), '.', 1)
      and activity.host_id = auth.uid()
  )
)
with check (
  bucket_id = 'activity-photos'
  and objects.name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.[a-z0-9]+$'
  and exists (
    select 1
    from public.activities as activity
    where activity.id::text = split_part(storage.filename(objects.name), '.', 1)
      and activity.host_id = auth.uid()
  )
);

-- Back to the limits the live bucket had before the lock-down (from
-- 00_inspect_live_setup.sql on 2026-11-12): JPEG and PNG, up to 5 MiB.
update storage.buckets
set allowed_mime_types = array['image/jpeg', 'image/png'],
    file_size_limit = 5242880
where id = 'activity-photos';

commit;
