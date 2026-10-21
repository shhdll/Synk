-- Delete accounts that didn't confirm their email within 24 hours, so the
-- email and username can be used again. public.users and the other user
-- tables cascade from auth.users.

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;

CREATE OR REPLACE FUNCTION public.delete_unconfirmed_users()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_deleted integer;
BEGIN
  DELETE FROM auth.users
  WHERE email_confirmed_at IS NULL
    AND created_at < NOW() - INTERVAL '24 hours';

  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;

-- Only the cron job should run this
REVOKE EXECUTE ON FUNCTION public.delete_unconfirmed_users() FROM PUBLIC, anon, authenticated;

-- Remove the old job first so running this again doesn't add a second one
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'delete-unconfirmed-users') THEN
    PERFORM cron.unschedule('delete-unconfirmed-users');
  END IF;
END $$;

-- Every hour
SELECT cron.schedule(
  'delete-unconfirmed-users',
  '0 * * * *',
  $cron$SELECT public.delete_unconfirmed_users();$cron$
);
