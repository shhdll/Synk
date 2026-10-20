-- Ties activity photo writes to the activity's current host instead of the
-- uploader's folder, so transferring hosting also transfers photo control.
-- Updates the three existing write policies in place; public read is kept.
-- Verified in the SQL Editor with a rolled-back ALTER POLICY test.

begin;

-- Fail fast instead of waiting behind other storage activity.
set local lock_timeout = '5s';

-- Stop unless the verified policies exist and nothing else can write.
do $$
declare
  expected constant text[] := array[
    'activity-photos: owner insert',
    'activity-photos: owner update',
    'activity-photos: owner delete'
  ];
  allowed_avatar_policies constant text[] := array[
    'avatars: owner insert',
    'avatars: owner update',
    'avatars: owner delete'
  ];
  allowed constant text[] := expected || allowed_avatar_policies;
  unexpected text;
begin
  if (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = any (expected)
  ) <> 3 then
    raise exception 'The three activity-photos write policies were not found.';
  end if;

  select string_agg(policyname, ', ')
  into unexpected
  from pg_policies
  where schemaname = 'storage'
    and tablename = 'objects'
    and cmd in ('INSERT', 'UPDATE', 'DELETE', 'ALL')
    and policyname <> all (allowed);

  if unexpected is not null then
    raise exception 'Other write policies exist on storage.objects: %',
      unexpected;
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'activity-photos: public read'
      and cmd = 'SELECT'
  ) then
    raise exception 'The activity-photos public read policy was not found.';
  end if;
end;
$$;

-- Upload only into the uploader's own folder, for an activity they host,
-- using the <host_id>/<activity_id>.<ext> path the app creates.
alter policy "activity-photos: owner insert"
on storage.objects
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

-- Only the activity's current host can replace its photo, wherever it is
-- stored. A renamed object must still be a photo of an activity they host.
-- Known limitation: the host may move that photo into another user's folder.
-- It grants no extra access, but breaks the photo link; the app never moves.
alter policy "activity-photos: owner update"
on storage.objects
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

-- Only the activity's current host can delete its photo.
alter policy "activity-photos: owner delete"
on storage.objects
to authenticated
using (
  bucket_id = 'activity-photos'
  and exists (
    select 1
    from public.activities as activity
    where activity.id::text = split_part(storage.filename(objects.name), '.', 1)
      and activity.host_id = auth.uid()
  )
);

commit;
