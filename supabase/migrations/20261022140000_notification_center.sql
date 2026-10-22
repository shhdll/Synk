-- Notification center: lists the signed-in user's notifications from the
-- existing push outbox tables (read only, no changes to them) and tracks
-- when the user last opened the list, for the unread badge.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS notifications_seen_at timestamptz;

CREATE OR REPLACE FUNCTION public.get_my_notifications(p_limit integer DEFAULT 50)
RETURNS TABLE (
  id uuid,
  kind text,
  activity_id uuid,
  activity_title text,
  created_at timestamptz,
  is_unread boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  WITH me AS (
    SELECT auth.uid() AS user_id,
      coalesce(
        (SELECT u.notifications_seen_at FROM public.users u WHERE u.id = auth.uid()),
        '-infinity'::timestamptz
      ) AS seen_at
  ),
  items AS (
    SELECT o.id, 'waitlist_promotion' AS kind, o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.waitlist_promotion_notification_outbox o
    UNION ALL
    SELECT o.id, 'activity_updated', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.activity_update_notification_outbox o
    UNION ALL
    SELECT o.id, 'activity_deleted', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.activity_deleted_notification_outbox o
    UNION ALL
    SELECT o.id, 'join_request_accepted', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.join_request_accepted_notification_outbox o
    UNION ALL
    SELECT o.id, 'join_request_rejected', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.join_request_rejected_notification_outbox o
    UNION ALL
    SELECT o.id, 'join_request_received', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.join_request_received_notification_outbox o
    UNION ALL
    SELECT o.id, 'host_assigned', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.host_transfer_notification_outbox o
    UNION ALL
    SELECT o.id, 'activity_conflict', o.activity_id, o.activity_title, o.created_at, o.user_id
      FROM public.activity_conflict_notification_outbox o
      WHERE o.status <> 'cancelled'
  )
  SELECT i.id, i.kind, i.activity_id, i.activity_title, i.created_at,
    i.created_at > me.seen_at AS is_unread
  FROM items i, me
  WHERE i.user_id = me.user_id
    AND i.created_at > now() - interval '30 days'
  ORDER BY i.created_at DESC
  LIMIT least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.mark_my_notifications_seen()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  UPDATE public.users SET notifications_seen_at = now() WHERE id = auth.uid();
$$;

REVOKE EXECUTE ON FUNCTION public.get_my_notifications(integer) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.mark_my_notifications_seen() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_notifications(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_my_notifications_seen() TO authenticated;
