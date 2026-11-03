import 'package:supabase_flutter/supabase_flutter.dart';

// One entry in the notification center. [kind] matches the push event type.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.activityId,
    required this.activityTitle,
    required this.createdAt,
    required this.isUnread,
    this.photoUrl,
    this.categoryLabel = '',
    this.participationId,
    this.requestPending = false,
  });

  final String id;
  final String kind;
  final String? activityId;
  final String activityTitle;
  final DateTime createdAt;
  final bool isUnread;
  final String? photoUrl;
  final String categoryLabel;

  // Join requests only: the request, and whether it still waits for an answer.
  final String? participationId;
  final bool requestPending;

  AppNotification asRead() => AppNotification(
    id: id,
    kind: kind,
    activityId: activityId,
    activityTitle: activityTitle,
    createdAt: createdAt,
    isUnread: false,
    photoUrl: photoUrl,
    categoryLabel: categoryLabel,
    participationId: participationId,
    requestPending: requestPending,
  );

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      kind: map['kind'] as String,
      activityId: map['activity_id'] as String?,
      activityTitle: (map['activity_title'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      isUnread: map['is_unread'] == true,
      photoUrl: map['activity_photo_url'] as String?,
      categoryLabel: (map['activity_category_label'] as String?) ?? '',
      participationId: map['participation_id'] as String?,
      requestPending: map['request_pending'] == true,
    );
  }
}

class NotificationsModel {
  final SupabaseClient _supabase = Supabase.instance.client;

  // The signed-in user's notifications from the last 30 days, newest first.
  Future<List<AppNotification>> fetch() async {
    final response = await _supabase.rpc('get_my_notifications');
    if (response is! List) return const [];
    return response
        .map((row) => AppNotification.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // Everything up to now counts as read.
  Future<void> markSeen() async {
    await _supabase.rpc('mark_my_notifications_seen');
  }

  Future<void> markRead(String id) async {
    await _supabase.rpc(
      'mark_notification_read',
      params: {'p_notification_id': id},
    );
  }

  // Hides it from the list for good.
  Future<void> delete(String id) async {
    await _supabase.rpc(
      'delete_notification',
      params: {'p_notification_id': id},
    );
  }
}
