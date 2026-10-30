import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_model.dart';

// The signed-in user's chats, for the Chat tab and its unread badge.
//
// Reloads whenever a message arrives in any of the user's chats, and when
// MainShell polls or the app comes back to the foreground.
class ChatController extends ChangeNotifier {
  ChatController._();

  static final ChatController instance = ChatController._();

  final ChatModel _model = ChatModel();

  List<ChatSummary> _chats = [];
  RealtimeChannel? _inbox;
  Timer? _reloadSoon;

  // Whose chats these are, so another account never sees them.
  String? _loadedFor;
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _refreshing = false;
  bool _refreshQueued = false;
  String? _error;

  ChatModel get model => _model;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  List<ChatSummary> get activityChats =>
      _chats.where((c) => c.isActivity).toList();

  List<ChatSummary> get directChats =>
      _chats.where((c) => !c.isActivity).toList();

  // The number on the Chat tab badge: unmuted chats with unread messages.
  int get unreadChatCount =>
      _chats.where((c) => c.unreadCount > 0 && !c.isMuted).length;

  ChatSummary? byId(String chatId) {
    for (final chat in _chats) {
      if (chat.id == chatId) return chat;
    }
    return null;
  }

  ChatSummary? directChatWith(String userId) {
    for (final chat in _chats) {
      if (chat.otherUser?.id == userId) return chat;
    }
    return null;
  }

  // Quiet by default; the Chat tab shows a spinner only on the first load.
  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != _loadedFor) {
      _chats = [];
      _hasLoaded = false;
      _loadedFor = userId;
      _stopListening();
    }
    if (userId == null) return;
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }

    _inbox ??= _model.listenForAnyMessage(_scheduleRefresh);
    _refreshing = true;
    if (!_hasLoaded) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      do {
        _refreshQueued = false;
        final chats = await _model.fetchChats();
        if (_loadedFor != userId) return;
        _chats = chats;
        _error = null;
        _hasLoaded = true;
      } while (_refreshQueued);
    } catch (error) {
      debugPrint('SYNK: chats failed to load: $error');
      _error = error.toString();
    } finally {
      _isLoading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  // Shows a chat as read straight away, then tells the server.
  Future<void> markRead(String chatId) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1 && _chats[index].unreadCount > 0) {
      _chats[index] = _chats[index].copyWith(unreadCount: 0);
      notifyListeners();
    }
    try {
      await _model.markRead(chatId);
    } catch (error) {
      debugPrint('SYNK: marking chat read failed: $error');
    }
  }

  // Shows the change straight away; false when it failed, and the reload
  // puts it back.
  Future<bool> setMuted(String chatId, bool mute) async {
    final index = _chats.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      _chats[index] = _chats[index].copyWith(isMuted: mute);
      notifyListeners();
    }
    var ok = false;
    try {
      ok = await _model.setMuted(chatId, mute);
    } catch (error) {
      debugPrint('SYNK: muting chat failed: $error');
    }
    await refresh();
    return ok;
  }

  // Removes the chat from your list straight away; false when it failed, and
  // the reload puts it back.
  Future<bool> deleteChatForMe(String chatId) async {
    _chats.removeWhere((c) => c.id == chatId);
    notifyListeners();
    var ok = false;
    try {
      ok = await _model.deleteChatForMe(chatId);
    } catch (error) {
      debugPrint('SYNK: deleting chat failed: $error');
    }
    await refresh();
    return ok;
  }

  // The chat id with a friend, or null when it can't be opened.
  Future<String?> openDirectChat(String userId) async {
    final existing = directChatWith(userId);
    if (existing != null) return existing.id;
    try {
      final chatId = await _model.openDirectChat(userId);
      unawaited(refresh());
      return chatId;
    } catch (error) {
      debugPrint('SYNK: opening chat failed: $error');
      return null;
    }
  }

  // Several messages often land together; reload once for all of them.
  void _scheduleRefresh() {
    _reloadSoon?.cancel();
    _reloadSoon = Timer(const Duration(milliseconds: 400), () {
      unawaited(refresh());
    });
  }

  void _stopListening() {
    _reloadSoon?.cancel();
    final inbox = _inbox;
    _inbox = null;
    if (inbox != null) unawaited(_model.removeChannel(inbox));
  }
}
