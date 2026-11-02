import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_model.dart';
import 'friends_model.dart';
import 'place_search_model.dart';

// Activity group chats and one-to-one chats between friends. Changes go
// through database functions (supabase/migrations/20261029120000_chats.sql),
// which also keep activity chat members in step with the activity.

enum ChatKind { activity, direct }

// A row in the chats list.
class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.activity,
    this.otherUser,
    this.memberCount = 0,
    this.lastMessageBody,
    this.lastMessageSenderId,
    this.lastMessageSenderName,
    this.lastMessageAt,
    this.lastMessageIsDeleted = false,
    this.lastMessageHasPhoto = false,
    this.lastMessageKind = 'text',
    this.lastMessageLabel,
    this.unreadCount = 0,
    this.isMuted = false,
  });

  final String id;
  final ChatKind kind;
  final DateTime createdAt;

  // Activity chats: enough of the activity for the title and thumbnail.
  final Activity? activity;

  // Direct chats: the friend.
  final FriendUser? otherUser;

  final int memberCount;
  final String? lastMessageBody;
  final String? lastMessageSenderId;
  final String? lastMessageSenderName;
  final DateTime? lastMessageAt;
  final bool lastMessageIsDeleted;
  final bool lastMessageHasPhoto;

  // 'text', 'photo', 'activity' or 'location'.
  final String lastMessageKind;

  // The shared activity's title or the place's name.
  final String? lastMessageLabel;
  final int unreadCount;

  // Left out of the Chat tab badge.
  final bool isMuted;

  bool get isActivity => kind == ChatKind.activity;

  String get title => activity?.title ?? otherUser?.name ?? '';

  DateTime get sortTime => lastMessageAt ?? createdAt;

  ChatSummary copyWith({int? unreadCount, bool? isMuted}) {
    return ChatSummary(
      id: id,
      kind: kind,
      createdAt: createdAt,
      activity: activity,
      otherUser: otherUser,
      memberCount: memberCount,
      lastMessageBody: lastMessageBody,
      lastMessageSenderId: lastMessageSenderId,
      lastMessageSenderName: lastMessageSenderName,
      lastMessageAt: lastMessageAt,
      lastMessageIsDeleted: lastMessageIsDeleted,
      lastMessageHasPhoto: lastMessageHasPhoto,
      lastMessageKind: lastMessageKind,
      lastMessageLabel: lastMessageLabel,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  factory ChatSummary.fromMap(Map<String, dynamic> map) {
    final kind = map['kind'] == 'direct' ? ChatKind.direct : ChatKind.activity;
    final startsAt = map['activity_starts_at'] as String?;
    final lastAt = map['last_message_at'] as String?;

    return ChatSummary(
      id: map['chat_id'] as String,
      kind: kind,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      activity: kind == ChatKind.activity && startsAt != null
          ? Activity(
              id: map['activity_id'] as String,
              title: map['activity_title'] as String? ?? '',
              dateTime: DateTime.parse(startsAt).toLocal(),
              location: '',
              photoUrl: map['activity_photo_url'] as String?,
              categoryLabel: map['activity_category_label'] as String? ?? '',
              categoryEmoji: map['activity_category_emoji'] as String? ?? '',
            )
          : null,
      otherUser: kind == ChatKind.direct && map['other_user_id'] != null
          ? FriendUser.fromMap({
              'id': map['other_user_id'],
              'full_name': map['other_full_name'],
              'username': map['other_username'],
              'avatar_url': map['other_avatar_url'],
              'gender': map['other_gender'],
            })
          : null,
      memberCount: map['member_count'] as int? ?? 0,
      lastMessageBody: map['last_message_body'] as String?,
      lastMessageSenderId: map['last_message_sender_id'] as String?,
      lastMessageSenderName: map['last_message_sender_name'] as String?,
      lastMessageAt: lastAt == null ? null : DateTime.parse(lastAt).toLocal(),
      lastMessageIsDeleted: map['last_message_is_deleted'] == true,
      lastMessageHasPhoto: map['last_message_has_photo'] == true,
      lastMessageKind: map['last_message_kind'] as String? ?? 'text',
      lastMessageLabel: map['last_message_label'] as String?,
      unreadCount: map['unread_count'] as int? ?? 0,
      isMuted: map['is_muted'] == true,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.imagePath,
    this.deletedAt,
    this.kind = 'text',
    this.sharedActivityId,
    this.sharedActivity,
    this.latitude,
    this.longitude,
    this.locationName,
    this.locationAddress,
  });

  final String id;
  final String chatId;

  // Null when the sender deleted their account.
  final String? senderId;
  // Empty for a photo sent without text.
  final String body;
  final DateTime createdAt;

  // Where the photo is in the chat-photos bucket, for photo messages.
  final String? imagePath;

  // Set when the sender deleted it for everyone; text and photo are gone.
  final DateTime? deletedAt;

  bool get hasPhoto => imagePath != null && imagePath!.isNotEmpty;

  bool get isDeleted => deletedAt != null;

  // 'text', 'photo', 'activity' or 'location'.
  final String kind;

  // Activity messages. The id is null once the activity is deleted; the
  // snapshot still has what the card shows.
  final String? sharedActivityId;
  final Activity? sharedActivity;

  // Location messages.
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? locationAddress;

  bool get isActivityShare => kind == 'activity' && sharedActivity != null;

  bool get isLocation =>
      kind == 'location' && latitude != null && longitude != null;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      chatId: map['chat_id'] as String,
      senderId: map['sender_id'] as String?,
      body: map['body'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      imagePath: map['image_path'] as String?,
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at'] as String).toLocal(),
      kind: map['kind'] as String? ?? 'text',
      sharedActivityId: map['shared_activity_id'] as String?,
      sharedActivity: _activityFromSnapshot(
        map['shared_activity_id'] as String?,
        map['shared_activity'],
      ),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationName: map['location_name'] as String?,
      locationAddress: map['location_address'] as String?,
    );
  }

  static Activity? _activityFromSnapshot(String? id, Object? snapshot) {
    if (snapshot is! Map || snapshot['starts_at'] == null) return null;
    final endsAt = snapshot['ends_at'] as String?;
    return Activity(
      id: id ?? '',
      title: snapshot['title'] as String? ?? '',
      dateTime: DateTime.parse(snapshot['starts_at'] as String).toLocal(),
      endsAt: endsAt == null ? null : DateTime.parse(endsAt).toLocal(),
      location: snapshot['location_name'] as String? ?? '',
      photoUrl: snapshot['photo_url'] as String?,
      categoryLabel: snapshot['category_label'] as String? ?? '',
      categoryEmoji: snapshot['category_emoji'] as String? ?? '',
    );
  }
}

class ChatModel {
  static const photoBucket = 'chat-photos';

  // How long a photo's link works; the chat asks for new ones when reopened.
  static const _photoLinkSeconds = 60 * 60;

  final ImagePicker _picker = ImagePicker();

  // Looked up on use, so widgets can build without Supabase (e.g. in tests).
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<List<ChatSummary>> fetchChats() async {
    final response = await _supabase.rpc('get_my_chats');
    if (response is! List) return const [];
    return response
        .map((row) => ChatSummary.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendUser>> fetchMembers(String chatId) async {
    final response = await _supabase.rpc(
      'get_chat_members',
      params: {'target_chat_id': chatId},
    );
    if (response is! List) return const [];
    return response
        .map((row) => FriendUser.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // Each user's interests, keyed by user id.
  Future<Map<String, List<String>>> fetchInterests(List<String> userIds) async {
    final rows = await _supabase
        .from('users')
        .select('id, interests')
        .inFilter('id', userIds);
    return {
      for (final row in rows)
        row['id'] as String:
            (row['interests'] as List?)?.cast<String>() ?? const [],
    };
  }

  // The latest [limit] messages, oldest first.
  Future<List<ChatMessage>> fetchMessages(
    String chatId, {
    int limit = 200,
  }) async {
    final rows = await _supabase
        .from('chat_messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.reversed.map(ChatMessage.fromMap).toList();
  }

  // Calls [onMessage] for each new message in the chat, and again when one
  // is deleted.
  RealtimeChannel listenForMessages(
    String chatId,
    void Function(ChatMessage message) onMessage,
  ) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'chat_id',
      value: chatId,
    );
    void deliver(PostgresChangePayload payload) =>
        onMessage(ChatMessage.fromMap(payload.newRecord));
    return _supabase
        .channel('chat:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: filter,
          callback: deliver,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          filter: filter,
          callback: deliver,
        )
        .subscribe();
  }

  // Calls [onChange] whenever a message arrives in, or is deleted from, any
  // of the user's chats.
  RealtimeChannel listenForAnyMessage(void Function() onChange) {
    return _supabase
        .channel('chats:inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> removeChannel(RealtimeChannel channel) =>
      _supabase.removeChannel(channel);

  // The chat id, or null when the two aren't friends.
  Future<String?> openDirectChat(String userId) async {
    final response = await _supabase.rpc(
      'get_or_create_direct_chat',
      params: {'target_user_id': userId},
    );
    if (response is Map && response['result'] == 'ok') {
      return response['chat_id'] as String?;
    }
    return null;
  }

  // Opens the photo picker; null when the user cancels.
  Future<XFile?> pickPhoto({bool fromCamera = false}) => _picker.pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 85,
  );

  // Uploads into the chat's folder and returns the path to send.
  Future<String> uploadPhoto(String chatId, XFile file) async {
    final me = _supabase.auth.currentUser?.id ?? 'unknown';
    final extension = file.path.split('.').last.toLowerCase();
    final type = switch (extension) {
      'png' => 'png',
      'heic' => 'heic',
      'webp' => 'webp',
      _ => 'jpeg',
    };
    final path =
        '$chatId/${me}_${DateTime.now().microsecondsSinceEpoch}'
        '.${type == 'jpeg' ? 'jpg' : type}';
    await _supabase.storage
        .from(photoBucket)
        .upload(
          path,
          File(file.path),
          fileOptions: FileOptions(contentType: 'image/$type'),
        );
    return path;
  }

  // Temporary links for photos, keyed by path. Missing photos are left out.
  Future<Map<String, String>> photoLinks(List<String> paths) async {
    if (paths.isEmpty) return const {};
    final results = await _supabase.storage
        .from(photoBucket)
        .createSignedUrlsResult(paths, _photoLinkSeconds);
    return {
      for (final result in results)
        if (result is SignedUrlSuccess) result.path: result.signedUrl,
    };
  }

  // The function's result, e.g. 'sent', 'finished' or 'not_visible_to_all',
  // and the message when it was sent. Send one of: text, [imagePath] (from
  // uploadPhoto), [activityId], or [place].
  Future<({String result, ChatMessage? message})> send(
    String chatId,
    String body, {
    String? imagePath,
    String? activityId,
    PlaceSuggestion? place,
  }) async {
    final response = await _supabase.rpc(
      'send_chat_message',
      params: {
        'target_chat_id': chatId,
        'message_body': body,
        'image_path': ?imagePath,
        'shared_activity_id': ?activityId,
        if (place != null) ...{
          'latitude': place.latitude,
          'longitude': place.longitude,
          'location_name': place.name,
          'location_address': place.address,
        },
      },
    );
    if (response is! Map) return (result: '', message: null);
    final result = response['result'] as String? ?? '';
    final message = result == 'sent'
        ? ChatMessage.fromMap(
            Map<String, dynamic>.from(response['message'] as Map),
          )
        : null;
    return (result: result, message: message);
  }

  // Deletes your message for everyone. True when it was deleted.
  Future<bool> deleteMessage(String messageId) async {
    final response = await _supabase.rpc(
      'delete_chat_message',
      params: {'target_message_id': messageId},
    );
    if (response is! Map || response['result'] != 'deleted') return false;
    final photo = response['image_path'] as String?;
    if (photo != null) {
      try {
        await _supabase.storage.from(photoBucket).remove([photo]);
      } catch (_) {
        // The message is gone either way; the file just stays in storage.
      }
    }
    return true;
  }

  // Hides one message from you only; others still see it.
  Future<bool> hideMessage(String messageId) async {
    final response = await _supabase.rpc(
      'hide_chat_message',
      params: {'target_message_id': messageId},
    );
    return response is Map && response['result'] == 'hidden';
  }

  Future<bool> setMuted(String chatId, bool mute) async {
    final response = await _supabase.rpc(
      'set_chat_muted',
      params: {'target_chat_id': chatId, 'mute': mute},
    );
    return response is Map && response['result'] == 'ok';
  }

  // Hides the chat and its history for you only.
  Future<bool> deleteChatForMe(String chatId) async {
    final response = await _supabase.rpc(
      'delete_chat_for_me',
      params: {'target_chat_id': chatId},
    );
    return response is Map && response['result'] == 'deleted';
  }

  Future<void> markRead(String chatId) =>
      _supabase.rpc('mark_chat_read', params: {'target_chat_id': chatId});
}
