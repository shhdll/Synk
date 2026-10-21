-- Profile header: a preset color (header_style) or an uploaded photo
-- (header_url). Photos are stored in the avatars bucket as
-- <user_id>/header.<ext>, which the existing avatars policies already allow.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS header_style text,
  ADD COLUMN IF NOT EXISTS header_url text;
