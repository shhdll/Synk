-- Optional ntfy topic per user. The push function also sends each
-- notification to https://ntfy.sh/<topic>, so iPhones can get them through
-- the ntfy app without native push.
alter table public.notification_preferences
  add column if not exists ntfy_topic text;

alter table public.notification_preferences
  drop constraint if exists notification_preferences_ntfy_topic_format;
alter table public.notification_preferences
  add constraint notification_preferences_ntfy_topic_format
  check (ntfy_topic is null or ntfy_topic ~ '^[A-Za-z0-9_-]{16,64}$');
