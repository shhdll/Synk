-- Keeps each user's ntfy topic when they turn ntfy off, so turning it on
-- again gives the same topic and their ntfy subscription keeps working.
-- ntfy_topic is still what the push function sends to (null when off).
--
-- Safe to run again.

begin;

alter table public.notification_preferences
  add column if not exists ntfy_saved_topic text;

alter table public.notification_preferences
  drop constraint if exists notification_preferences_ntfy_saved_topic_format;
alter table public.notification_preferences
  add constraint notification_preferences_ntfy_saved_topic_format
  check (
    ntfy_saved_topic is null
    or ntfy_saved_topic ~ '^[A-Za-z0-9_-]{16,64}$'
  );

update public.notification_preferences
set ntfy_saved_topic = ntfy_topic
where ntfy_topic is not null
  and ntfy_saved_topic is null;

commit;
