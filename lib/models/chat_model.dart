import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_model.dart';
import 'friends_model.dart';

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
    this.unreadCount = 0,
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
  final int unreadCount;

  bool get isActivity => kind == ChatKind.activity;

  String get title => activity?.title ?? otherUser?.name ?? '';

  DateTime get sortTime => lastMessageAt ?? createdAt;

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
      unreadCount: map['unread_count'] as int? ?? 0,
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

  bool get hasPhoto => imagePath != null && imagePath!.isNotEmpty;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      chatId: map['chat_id'] as String,
      senderId: map['sender_id'] as String?,
      body: map['body'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      imagePath: map['image_path'] as String?,
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

  // Calls [onMessage] for each new message in the chat.
  RealtimeChannel listenForMessages(
    String chatId,
    void Function(ChatMessage message) onMessage,
  ) {
    return _supabase
        .channel('chat:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) =>
              onMessage(ChatMessage.fromMap(payload.newRecord)),
        )
        .subscribe();
  }

  // Calls [onChange] whenever a message arrives in any of the user's chats.
  RealtimeChannel listenForAnyMessage(void Function() onChange) {
    return _supabase
        .channel('chats:inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
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
  Future<XFile?> pickPhoto() => _picker.pickImage(
    source: ImageSource.gallery,
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

  // The function's result, e.g. 'sent' or 'finished', and the message when
  // it was sent. [imagePath] comes from uploadPhoto.
  Future<({String result, ChatMessage? message})> send(
    String chatId,
    String body, {
    String? imagePath,
  }) async {
    final response = await _supabase.rpc(
      'send_chat_message',
      params: {
        'target_chat_id': chatId,
        'message_body': body,
        'image_path': ?imagePath,
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

  Future<void> markRead(String chatId) =>
      _supabase.rpc('mark_chat_read', params: {'target_chat_id': chatId});
}
