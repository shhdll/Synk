-- ==============================================================================
-- Migration: Keep public.users.email in sync with auth.users.email
-- ==============================================================================
-- Description:
-- Username login looks up the account's email in public.users. That column was
-- only written on signup, so after a confirmed email change it kept the old
-- address and username login failed. This trigger copies the new email over
-- whenever auth.users.email changes, and the backfill fixes existing rows.
-- ==============================================================================

-- 1. Copy the confirmed email to the profile row
CREATE OR REPLACE FUNCTION public.handle_user_email_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.users
  SET email = new.email
  WHERE id = new.id;

  RETURN NEW;
END;
$$;

-- 2. Attach trigger to auth.users after the email column changes
DROP TRIGGER IF EXISTS on_auth_user_email_changed ON auth.users;

CREATE TRIGGER on_auth_user_email_changed
  AFTER UPDATE OF email ON auth.users
  FOR EACH ROW
  WHEN (OLD.email IS DISTINCT FROM NEW.email)
  EXECUTE FUNCTION public.handle_user_email_change();

-- 3. Backfill profiles whose email already went stale
UPDATE public.users u
SET email = a.email
FROM auth.users a
WHERE a.id = u.id
  AND u.email IS DISTINCT FROM a.email;
