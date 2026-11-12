import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';
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
    this.lastMessageSenderHidden = false,
    this.lastMessageAt,
    this.lastMessageIsDeleted = false,
    this.lastMessageHasPhoto = false,
    this.lastMessageKind = 'text',
    this.lastMessageLabel,
    this.unreadCount = 0,
    this.isMuted = false,
    this.isFriend = true,
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

  // The sender blocked the viewer; the server left their name out.
  final bool lastMessageSenderHidden;
  final DateTime? lastMessageAt;
  final bool lastMessageIsDeleted;
  final bool lastMessageHasPhoto;

  // 'text', 'photo', 'activity', 'location', 'sticker', 'voice', 'contact'
  // or 'poll'.
  final String lastMessageKind;

  // The shared activity's title or the place's name.
  final String? lastMessageLabel;
  final int unreadCount;

  // Left out of the Chat tab badge.
  final bool isMuted;

  // Direct chats: false once either person removes the other as a friend.
  final bool isFriend;

  // A direct chat with someone who's no longer a friend. Readable, but
  // neither of you can send.
  bool get isUnfriended => !isActivity && !isFriend;

  bool get isActivity => kind == ChatKind.activity;

  // A message the user can still see; none after deleting the chat.
  bool get hasMessages => lastMessageBody != null;

  // Activity chats stay readable, but sending stops a day after it ends.
  bool get isClosed =>
      activity != null &&
      !DateTime.now().isBefore(activity!.endsAt.add(const Duration(days: 1)));

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
      lastMessageSenderHidden: lastMessageSenderHidden,
      lastMessageAt: lastMessageAt,
      lastMessageIsDeleted: lastMessageIsDeleted,
      lastMessageHasPhoto: lastMessageHasPhoto,
      lastMessageKind: lastMessageKind,
      lastMessageLabel: lastMessageLabel,
      unreadCount: unreadCount ?? this.unreadCount,
      isMuted: isMuted ?? this.isMuted,
      isFriend: isFriend,
    );
  }

  factory ChatSummary.fromMap(Map<String, dynamic> map) {
    final kind = map['kind'] == 'direct' ? ChatKind.direct : ChatKind.activity;
    final startsAt = map['activity_starts_at'] as String?;
    final endsAt = map['activity_ends_at'] as String?;
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
              endsAt: endsAt == null ? null : DateTime.parse(endsAt).toLocal(),
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
      lastMessageSenderHidden: map['last_message_sender_hidden'] == true,
      lastMessageAt: lastAt == null ? null : DateTime.parse(lastAt).toLocal(),
      lastMessageIsDeleted: map['last_message_is_deleted'] == true,
      lastMessageHasPhoto: map['last_message_has_photo'] == true,
      lastMessageKind: map['last_message_kind'] as String? ?? 'text',
      lastMessageLabel: map['last_message_label'] as String?,
      unreadCount: map['unread_count'] as int? ?? 0,
      isMuted: map['is_muted'] == true,
      // Missing on servers without the column yet: treat as a friend.
      isFriend: map['is_friend'] != false,
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
    this.replyToId,
    this.stickerId,
    this.audioPath,
    this.audioDuration,
    this.audioWaveform = const [],
    this.sharedUserId,
    this.sharedUser,
    this.viewOnce = false,
  });

  final String id;
  final String chatId;

  // A photo or voice message each other member can open one time.
  final bool viewOnce;

  // Null when the sender deleted their account. For a sender who blocked
  // the viewer, the stand-in id from get_chat_members, not the real one.
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

  // 'text', 'photo', 'activity', 'location', 'sticker', 'voice', 'contact'
  // or 'poll'.
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

  // The message this one replies to; null once that message is gone.
  final String? replyToId;

  // Sticker messages: the sticker's id in the built-in pack.
  final String? stickerId;

  // Voice messages: the recording in the chat-voice bucket, how long it is,
  // and its loudness (0-100 per bar) for the waveform.
  final String? audioPath;
  final Duration? audioDuration;
  final List<int> audioWaveform;

  // Contact messages: the friend who was shared. The id is null once their
  // account is gone; the snapshot still has the name for the card.
  final String? sharedUserId;
  final FriendUser? sharedUser;

  bool get isActivityShare => kind == 'activity' && sharedActivity != null;

  bool get isSticker => !isDeleted && kind == 'sticker' && stickerId != null;

  bool get isVoice => !isDeleted && kind == 'voice' && audioPath != null;

  bool get isContact => !isDeleted && kind == 'contact' && sharedUser != null;

  bool get isPoll => !isDeleted && poll != null;

  // What the user typed; empty for stickers, polls and the like.
  String get text => kind == 'text' || kind == 'photo' ? body : '';

  // Poll messages keep the question and options as JSON in the text.
  ChatPoll? get poll => kind == 'poll' ? ChatPoll.tryParse(body) : null;

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
      replyToId: map['reply_to_id'] as String?,
      stickerId: map['sticker_id'] as String?,
      audioPath: map['audio_path'] as String?,
      audioDuration: map['audio_duration_ms'] == null
          ? null
          : Duration(milliseconds: (map['audio_duration_ms'] as num).toInt()),
      audioWaveform: [
        for (final v in (map['audio_waveform'] as List?) ?? const [])
          (v as num).toInt(),
      ],
      sharedUserId: map['shared_user_id'] as String?,
      sharedUser: map['shared_user'] is Map
          ? FriendUser.fromMap(
              Map<String, dynamic>.from(map['shared_user'] as Map),
            )
          : null,
      viewOnce: map['view_once'] == true,
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

// A poll's question and options, kept as JSON in the message text.
class ChatPoll {
  const ChatPoll({
    required this.question,
    required this.options,
    this.multiple = false,
  });

  final String question;
  final List<String> options;

  // Voters may pick more than one option.
  final bool multiple;

  String toJson() => jsonEncode({
    'question': question,
    'options': options,
    'multiple': multiple,
  });

  static ChatPoll? tryParse(String text) {
    try {
      final map = jsonDecode(text);
      if (map is! Map) return null;
      final options = (map['options'] as List?)?.whereType<String>().toList();
      final question = map['question'];
      if (question is! String || options == null || options.length < 2) {
        return null;
      }
      return ChatPoll(
        question: question,
        options: options,
        multiple: map['multiple'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

// Poll votes and voice listens in a chat, from get_chat_message_extras.
class ChatMessageExtras {
  const ChatMessageExtras({
    this.votes = const {},
    this.plays = const {},
    this.opens = const {},
  });

  // Message id -> voter id -> the options they picked.
  final Map<String, Map<String, List<int>>> votes;

  // Message id -> who has listened to it.
  final Map<String, Set<String>> plays;

  // View-once message id -> who has opened it.
  final Map<String, Set<String>> opens;

  ChatMessageExtras copyWith({
    Map<String, Map<String, List<int>>>? votes,
    Map<String, Set<String>>? plays,
    Map<String, Set<String>>? opens,
  }) => ChatMessageExtras(
    votes: votes ?? this.votes,
    plays: plays ?? this.plays,
    opens: opens ?? this.opens,
  );

  factory ChatMessageExtras.fromMap(Map<String, dynamic> map) {
    final votes = <String, Map<String, List<int>>>{};
    for (final row in (map['votes'] as List?) ?? const []) {
      final picked = [
        for (final i in (row['option_indexes'] as List?) ?? const [])
          (i as num).toInt(),
      ];
      if (picked.isEmpty) continue;
      (votes[row['message_id'] as String] ??= {})[row['user_id'] as String] =
          picked;
    }
    final plays = <String, Set<String>>{};
    for (final row in (map['plays'] as List?) ?? const []) {
      (plays[row['message_id'] as String] ??= {}).add(row['user_id'] as String);
    }
    final opens = <String, Set<String>>{};
    for (final row in (map['opens'] as List?) ?? const []) {
      (opens[row['message_id'] as String] ??= {}).add(row['user_id'] as String);
    }
    return ChatMessageExtras(votes: votes, plays: plays, opens: opens);
  }
}

// How far one member has read a chat.
class ChatReadState {
  const ChatReadState({
    required this.userId,
    required this.joinedAt,
    required this.lastReadAt,
  });

  final String userId;
  final DateTime joinedAt;
  final DateTime lastReadAt;

  factory ChatReadState.fromMap(Map<String, dynamic> map) {
    return ChatReadState(
      userId: map['user_id'] as String,
      joinedAt: DateTime.parse(map['joined_at'] as String).toLocal(),
      lastReadAt: DateTime.parse(map['last_read_at'] as String).toLocal(),
    );
  }
}

class ChatModel {
  static const photoBucket = 'chat-photos';
  static const voiceBucket = 'chat-voice';

  // Voice messages stop recording here.
  static const maxVoiceLength = Duration(minutes: 2);

  // How long a photo's link works; the chat asks for new ones when reopened.
  static const _photoLinkSeconds = 60 * 60;

  final ImagePicker _picker = ImagePicker();
  final Random _random = Random();

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
    return response.map((row) {
      final user = FriendUser.fromMap(row as Map<String, dynamic>);
      // Someone who blocked the viewer: the server sent no name.
      if (!user.isHidden) return user;
      return FriendUser(
        id: user.id,
        name: appL10n.synkUser,
        gender: user.gender,
        isHidden: true,
      );
    }).toList();
  }

  // How far each member has read the chat.
  Future<List<ChatReadState>> fetchReadStates(String chatId) async {
    final rows = await _supabase
        .from('chat_members')
        .select('user_id, joined_at, last_read_at')
        .eq('chat_id', chatId);
    return rows.map(ChatReadState.fromMap).toList();
  }

  // Calls [onChange] when a member reads further.
  RealtimeChannel listenForReadStates(
    String chatId,
    void Function(ChatReadState state) onChange,
  ) {
    return _supabase
        .channel('chat-reads:$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (payload) =>
              onChange(ChatReadState.fromMap(payload.newRecord)),
        )
        .subscribe();
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

  // The latest [limit] messages, oldest first. The text is stored
  // encrypted, so this goes through get_chat_messages, which decrypts it
  // and leaves out the real id of anyone who blocked the viewer
  // (supabase/migrations/20261104180000_block_chats.sql).
  Future<List<ChatMessage>> fetchMessages(
    String chatId, {
    int limit = 200,
    List<String>? ids,
  }) async {
    final response = await _supabase.rpc(
      'get_chat_messages',
      params: {
        'target_chat_id': chatId,
        'message_ids': ?ids,
        'max_count': limit,
      },
    );
    if (response is! List) return const [];
    return response.reversed
        .map(
          (row) => ChatMessage.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
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
    // Realtime only has the encrypted text and no sender, so load the
    // message itself.
    Future<void> deliver(PostgresChangePayload payload) async {
      final id = payload.newRecord['id'] as String?;
      if (id == null) return;
      try {
        final messages = await fetchMessages(chatId, ids: [id], limit: 1);
        if (messages.isNotEmpty) onMessage(messages.first);
      } catch (error) {
        debugPrint('SYNK: new chat message failed to load: $error');
      }
    }

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
    final extension = file.path.split('.').last.toLowerCase();
    final type = switch (extension) {
      'png' => 'png',
      'heic' => 'heic',
      'webp' => 'webp',
      _ => 'jpeg',
    };
    // No user id in the name: everyone in the chat sees the path, including
    // people the sender blocked.
    final path =
        '$chatId/${DateTime.now().microsecondsSinceEpoch}'
        '_${_random.nextInt(1 << 32)}'
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
  // uploadPhoto), [activityId], or [place]. [replyToId] quotes an earlier
  // message from the same chat.
  Future<({String result, ChatMessage? message})> send(
    String chatId,
    String body, {
    String? imagePath,
    String? activityId,
    PlaceSuggestion? place,
    String? replyToId,
  }) async {
    final response = await _supabase.rpc(
      'send_chat_message',
      params: {
        'target_chat_id': chatId,
        'message_body': body,
        'reply_to_id': ?replyToId,
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

  // Uploads a recording (AAC in .m4a) into the chat's folder and returns the
  // path to send.
  Future<String> uploadVoice(String chatId, String filePath) async {
    final path =
        '$chatId/${DateTime.now().microsecondsSinceEpoch}'
        '_${_random.nextInt(1 << 32)}.m4a';
    await _supabase.storage
        .from(voiceBucket)
        .upload(
          path,
          File(filePath),
          fileOptions: const FileOptions(contentType: 'audio/mp4'),
        );
    return path;
  }

  // A temporary link for a voice message, or null when it's missing.
  Future<String?> voiceLink(String path) async {
    final results = await _supabase.storage
        .from(voiceBucket)
        .createSignedUrlsResult([path], _photoLinkSeconds);
    for (final result in results) {
      if (result is SignedUrlSuccess) return result.signedUrl;
    }
    return null;
  }

  // Sends a sticker, a voice message, a friend's account or a poll, through
  // send_chat_extra_message
  // (supabase/migrations/20261112100000_stickers_voice_contacts_polls.sql).
  Future<({String result, ChatMessage? message})> sendExtra(
    String chatId, {
    String? stickerId,
    String? audioPath,
    Duration? audioDuration,
    List<int>? waveform,
    String? sharedUserId,
    ChatPoll? poll,
    String? replyToId,
  }) async {
    final kind = stickerId != null
        ? 'sticker'
        : audioPath != null
        ? 'voice'
        : sharedUserId != null
        ? 'contact'
        : 'poll';
    final response = await _supabase.rpc(
      'send_chat_extra_message',
      params: {
        'target_chat_id': chatId,
        'message_kind': kind,
        'message_body': poll?.toJson() ?? '',
        'sticker_id': ?stickerId,
        'audio_path': ?audioPath,
        'audio_duration_ms': ?audioDuration?.inMilliseconds,
        'audio_waveform': ?waveform,
        'shared_user_id': ?sharedUserId,
        'reply_to_id': ?replyToId,
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

  // A view-once photo ([imagePath] from uploadPhoto) or voice message
  // ([audioPath] from uploadVoice), through send_chat_view_once
  // (supabase/migrations/20261113100000_view_once.sql).
  Future<({String result, ChatMessage? message})> sendViewOnce(
    String chatId, {
    String? imagePath,
    String? audioPath,
    Duration? audioDuration,
    List<int>? waveform,
    String? replyToId,
  }) async {
    final response = await _supabase.rpc(
      'send_chat_view_once',
      params: {
        'target_chat_id': chatId,
        'message_kind': imagePath != null ? 'photo' : 'voice',
        'image_path': ?imagePath,
        'audio_path': ?audioPath,
        'audio_duration_ms': ?audioDuration?.inMilliseconds,
        'audio_waveform': ?waveform,
        'reply_to_id': ?replyToId,
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

  // Opens a view-once message: 'opened' (its file can be fetched for a few
  // minutes), 'already_opened' or 'not_found'.
  Future<String> openViewOnce(String messageId) async {
    final response = await _supabase.rpc(
      'open_chat_view_once',
      params: {'target_message_id': messageId},
    );
    return response is Map ? response['result'] as String? ?? '' : '';
  }

  // Your options on a poll; an empty list takes your vote back.
  Future<bool> votePoll(String messageId, List<int> optionIndexes) async {
    final response = await _supabase.rpc(
      'vote_chat_poll',
      params: {'target_message_id': messageId, 'option_indexes': optionIndexes},
    );
    return response is Map && response['result'] == 'voted';
  }

  // Lets the sender see you listened to their voice message.
  Future<void> markVoicePlayed(String messageId) => _supabase.rpc(
    'mark_chat_voice_played',
    params: {'target_message_id': messageId},
  );

  Future<ChatMessageExtras> fetchExtras(String chatId) async {
    final response = await _supabase.rpc(
      'get_chat_message_extras',
      params: {'target_chat_id': chatId},
    );
    if (response is! Map) return const ChatMessageExtras();
    return ChatMessageExtras.fromMap(Map<String, dynamic>.from(response));
  }

  // Calls [onChange] when someone votes or listens to a voice message.
  // Realtime leaves out who, so reload with fetchExtras.
  RealtimeChannel listenForExtras(String chatId, void Function() onChange) {
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'chat_id',
      value: chatId,
    );
    var channel = _supabase.channel('chat-extras:$chatId');
    for (final table in [
      'chat_poll_votes',
      'chat_voice_plays',
      'chat_view_once_opens',
    ]) {
      for (final event in [
        PostgresChangeEvent.insert,
        PostgresChangeEvent.update,
      ]) {
        channel = channel.onPostgresChanges(
          event: event,
          schema: 'public',
          table: table,
          filter: filter,
          callback: (_) => onChange(),
        );
      }
    }
    return channel.subscribe();
  }

  // Deletes your message for everyone. True when it was deleted.
  Future<bool> deleteMessage(String messageId) async {
    final response = await _supabase.rpc(
      'delete_chat_message',
      params: {'target_message_id': messageId},
    );
    if (response is! Map || response['result'] != 'deleted') return false;
    final photo = response['image_path'] as String?;
    final audio = response['audio_path'] as String?;
    try {
      if (photo != null) {
        await _supabase.storage.from(photoBucket).remove([photo]);
      }
      if (audio != null) {
        await _supabase.storage.from(voiceBucket).remove([audio]);
      }
    } catch (_) {
      // The message is gone either way; the file just stays in storage.
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
