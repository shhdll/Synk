-- ==============================================================================
-- Migration: Stop the auth triggers writing public.users.updated_at
-- ==============================================================================
-- Description:
-- public.users has no updated_at column, so any trigger that sets it fails and
-- takes the whole sign up (POST /signup, 500) down with it. Both trigger
-- functions on auth.users are redefined here without it.
-- ==============================================================================

-- 1. Profile row on sign up
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
    created_at
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
    location_preference = COALESCE(EXCLUDED.location_preference, public.users.location_preference);

  RETURN NEW;
END;
$$;

-- 2. Email sync (in case an earlier version with updated_at was applied)
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
