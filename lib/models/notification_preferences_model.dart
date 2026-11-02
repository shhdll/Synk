import 'package:supabase_flutter/supabase_flutter.dart';

// Push notification switches (supabase/migrations/20261102120000_notification_preferences.sql).
// The push function skips any type that is turned off. No row means all on.
enum NotificationKind {
  waitlist('waitlist'),
  joinRequests('join_requests'),
  activityUpdates('activity_updates'),
  reminders('reminders'),
  friendRequests('friend_requests'),
  chats('chats'),
  marketing('marketing');

  const NotificationKind(this.column);

  final String column;
}

class NotificationPreferencesModel {
  NotificationPreferencesModel({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<({Map<NotificationKind, bool> values, String? ntfyTopic})>
  fetch() async {
    final userId = _supabase.auth.currentUser?.id;
    final values = {for (final kind in NotificationKind.values) kind: true};
    if (userId == null) return (values: values, ntfyTopic: null);

    final row = await _supabase
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return (values: values, ntfyTopic: null);

    for (final kind in NotificationKind.values) {
      values[kind] = row[kind.column] != false;
    }
    return (values: values, ntfyTopic: row['ntfy_topic'] as String?);
  }

  Future<void> save(NotificationKind kind, bool enabled) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw AuthSessionMissingException();

    await _supabase.from('notification_preferences').upsert({
      'user_id': userId,
      kind.column: enabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ntfy topic for iPhones without native push. Null turns it off.
  Future<void> saveNtfyTopic(String? topic) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw AuthSessionMissingException();

    await _supabase.from('notification_preferences').upsert({
      'user_id': userId,
      'ntfy_topic': topic,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
