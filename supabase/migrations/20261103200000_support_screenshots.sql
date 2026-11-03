-- Screenshots and a reply-to address for support messages.
--
-- The app uploads up to 3 screenshots to support-screenshots/<user_id>/...
-- and sends their paths with the message. The bucket is private; the
-- submit-support function makes links for the team's email.

begin;

alter table public.support_tickets
  add column if not exists screenshot_paths text[] not null default '{}',
  add column if not exists reply_to text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'support-screenshots',
  'support-screenshots',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do nothing;

drop policy if exists "support screenshots: owner insert" on storage.objects;
drop policy if exists "support screenshots: owner delete" on storage.objects;

create policy "support screenshots: owner insert"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'support-screenshots'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "support screenshots: owner delete"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'support-screenshots'
  and (storage.foldername(name))[1] = auth.uid()::text
);

commit;
