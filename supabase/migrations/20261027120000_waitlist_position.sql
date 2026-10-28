-- Waitlist position: how many waitlisted users are ahead of the signed-in
-- user. Uses the same order as promote_eligible_waitlist, so the count
-- matches who gets the next open spot.

CREATE OR REPLACE FUNCTION public.get_my_waitlist_position(requested_activity_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT (
    SELECT count(*)::integer
    FROM public.activity_participants AS other
    WHERE other.activity_id = me.activity_id
      AND other.status = 'waitlisted'
      AND (other.updated_at, other.created_at, other.id)
        < (me.updated_at, me.created_at, me.id)
  )
  FROM public.activity_participants AS me
  WHERE me.activity_id = requested_activity_id
    AND me.user_id = auth.uid()
    AND me.status = 'waitlisted';
$$;

-- Returns null when the user is not on this activity's waitlist.
REVOKE ALL ON FUNCTION public.get_my_waitlist_position(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.get_my_waitlist_position(uuid) TO authenticated;
