-- ==============================================================================
-- Migration: Automatic Profile Creation Trigger for Synk
-- ==============================================================================
-- Description:
-- When a user registers via Supabase auth, this trigger automatically extracts
-- user profile metadata (username, full_name, age, gender, interests, etc.)
-- and securely inserts it into public.users using SECURITY DEFINER privileges.
-- This guarantees profile rows exist even when email confirmation is pending
-- and the user does not have an active client session yet.
-- ==============================================================================

-- 1. Create or replace the trigger function
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_interests jsonb;
  v_age integer;
BEGIN
  -- Safely extract age as integer
  BEGIN
    v_age := (new.raw_user_meta_data->>'age')::integer;
  EXCEPTION WHEN OTHERS THEN
    v_age := NULL;
  END;

  -- Extract raw interests
  v_interests := new.raw_user_meta_data->'interests';

  -- Upsert into public.users
  INSERT INTO public.users (
    id,
    email,
    username,
    full_name,
    age,
    gender,
    interests,
    activity_type,
    location_preference,
    created_at,
    updated_at
  )
  VALUES (
    new.id,
    new.email,
    COALESCE(LOWER(TRIM(new.raw_user_meta_data->>'username')), ''),
    COALESCE(TRIM(new.raw_user_meta_data->>'full_name')),
    v_age,
    new.raw_user_meta_data->>'gender',
    CASE
      WHEN v_interests IS NOT NULL AND jsonb_typeof(v_interests) = 'array'
      THEN ARRAY(SELECT jsonb_array_elements_text(v_interests))
      ELSE NULL
    END,
    new.raw_user_meta_data->>'activity_type',
    new.raw_user_meta_data->>'location_preference',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    username = COALESCE(NULLIF(EXCLUDED.username, ''), public.users.username),
    full_name = COALESCE(NULLIF(EXCLUDED.full_name, ''), public.users.full_name),
    age = COALESCE(EXCLUDED.age, public.users.age),
    gender = COALESCE(EXCLUDED.gender, public.users.gender),
    interests = COALESCE(EXCLUDED.interests, public.users.interests),
    activity_type = COALESCE(EXCLUDED.activity_type, public.users.activity_type),
    location_preference = COALESCE(EXCLUDED.location_preference, public.users.location_preference),
    updated_at = NOW();

  RETURN NEW;
END;
$$;

-- 2. Drop any previous version of the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 3. Attach trigger to auth.users after INSERT
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- Optional: RLS Policies for public.users
-- ==============================================================================
-- Ensure users can read public profiles and update their own profiles:
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Allow anyone (authenticated or anon) to read basic user profiles:
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Public profiles are viewable by everyone'
  ) THEN
    CREATE POLICY "Public profiles are viewable by everyone"
      ON public.users FOR SELECT
      USING (true);
  END IF;
END $$;

-- Allow authenticated users to update their own profile:
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Users can update own profile'
  ) THEN
    CREATE POLICY "Users can update own profile"
      ON public.users FOR UPDATE
      TO authenticated
      USING (auth.uid() = id)
      WITH CHECK (auth.uid() = id);
  END IF;
END $$;

-- Allow authenticated users to insert their own profile (if client-side insert is needed):
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'users' AND policyname = 'Users can insert own profile'
  ) THEN
    CREATE POLICY "Users can insert own profile"
      ON public.users FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = id);
  END IF;
END $$;
