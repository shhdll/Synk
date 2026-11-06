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

  Future<
    ({
      Map<NotificationKind, bool> values,
      String? ntfyTopic,
      String? savedNtfyTopic,
      bool telegramLinked,
    })
  >
  fetch() async {
    final userId = _supabase.auth.currentUser?.id;
    final values = {for (final kind in NotificationKind.values) kind: true};
    if (userId == null) {
      return (
        values: values,
        ntfyTopic: null,
        savedNtfyTopic: null,
        telegramLinked: false,
      );
    }

    final row = await _supabase
        .from('notification_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    final telegramLinked = await fetchTelegramLinked();
    if (row == null) {
      return (
        values: values,
        ntfyTopic: null,
        savedNtfyTopic: null,
        telegramLinked: telegramLinked,
      );
    }

    for (final kind in NotificationKind.values) {
      values[kind] = row[kind.column] != false;
    }
    return (
      values: values,
      ntfyTopic: row['ntfy_topic'] as String?,
      savedNtfyTopic: row['ntfy_saved_topic'] as String?,
      telegramLinked: telegramLinked,
    );
  }

  // Telegram link (supabase/migrations/20261108130000_telegram_notifications.sql).
  // Only the telegram-webhook function sets the chat id.
  Future<bool> fetchTelegramLinked() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final row = await _supabase
        .from('telegram_links')
        .select('chat_id')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['chat_id'] != null;
  }

  // One-time code for https://t.me/<bot>?start=<code>.
  Future<String> telegramLinkCode(String language) async {
    final code = await _supabase.rpc(
      'telegram_link_code',
      params: {'p_language': language},
    );
    return code as String;
  }

  Future<void> unlinkTelegram() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw AuthSessionMissingException();

    await _supabase.from('telegram_links').delete().eq('user_id', userId);
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

  // ntfy topic for iPhones without native push. Null turns it off; a topic
  // is also kept as the saved one, for turning it on again.
  Future<void> saveNtfyTopic(String? topic) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw AuthSessionMissingException();

    await _supabase.from('notification_preferences').upsert({
      'user_id': userId,
      'ntfy_topic': topic,
      'ntfy_saved_topic': ?topic,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
