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
  });

  final String id;
  final String kind;
  final String? activityId;
  final String activityTitle;
  final DateTime createdAt;
  final bool isUnread;

  AppNotification asRead() => AppNotification(
    id: id,
    kind: kind,
    activityId: activityId,
    activityTitle: activityTitle,
    createdAt: createdAt,
    isUnread: false,
  );

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      kind: map['kind'] as String,
      activityId: map['activity_id'] as String?,
      activityTitle: (map['activity_title'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      isUnread: map['is_unread'] == true,
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
}
