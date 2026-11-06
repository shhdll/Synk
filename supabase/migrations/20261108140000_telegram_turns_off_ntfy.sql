-- The telegram-webhook function turns ntfy off when a user connects
-- Telegram, so they don't get every notification twice. ntfy_saved_topic
-- keeps their topic for turning it on again.
grant update (ntfy_topic, updated_at) on public.notification_preferences
  to service_role;
