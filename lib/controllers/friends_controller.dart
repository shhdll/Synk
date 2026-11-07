import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friends_model.dart';
import 'chat_controller.dart';
import '../utils/fuzzy_search.dart';

// Friends, friend requests and blocked users for the signed-in user.
//
// Shared by the home header badge, the profile and the friends screens, so
// a change made on one screen shows everywhere. Changes show straight away,
// then the lists are reloaded from the server, which also undoes a change
// that failed.
class FriendsController extends ChangeNotifier {
  FriendsController._();

  static final FriendsController instance = FriendsController._();

  final FriendsModel _model = FriendsModel();

  List<FriendUser> _friends = [];
  List<FriendRequest> _requests = [];
  List<FriendUser> _blocked = [];

  // Friends going, per home feed activity, and which activities to ask about.
  Map<String, List<FriendUser>> _friendsGoing = {};
  List<String> _goingActivityIds = [];

  // Whose lists these are, so another account never sees them.
  String? _loadedFor;
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _refreshing = false;
  String? _error;

  List<FriendUser> get friends => List.unmodifiable(_friends);
  List<FriendUser> get blocked => List.unmodifiable(_blocked);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get error => _error;

  List<FriendRequest> get receivedRequests =>
      _requests.where((r) => r.isIncoming).toList();

  List<FriendRequest> get sentRequests =>
      _requests.where((r) => !r.isIncoming).toList();

  // The number on the home header badge.
  int get pendingCount => receivedRequests.length;

  // Quiet by default; screens show a spinner only on the first load.
  Future<void> refresh() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != _loadedFor) {
      _friends = [];
      _requests = [];
      _blocked = [];
      _friendsGoing = {};
      _hasLoaded = false;
      _loadedFor = userId;
    }
    if (userId == null || _refreshing) return;

    _refreshing = true;
    if (!_hasLoaded) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final results = await Future.wait<Object>([
        _model.fetchFriends(),
        _model.fetchRequests(),
        _model.fetchBlocked(),
      ]);
      if (_loadedFor != userId) return;
      _friends = results[0] as List<FriendUser>;
      _requests = results[1] as List<FriendRequest>;
      _blocked = results[2] as List<FriendUser>;
      _error = null;
      _hasLoaded = true;
      unawaited(_loadFriendsGoing());
    } catch (error) {
      debugPrint('SYNK: friends failed to load: $error');
      _error = error.toString();
    } finally {
      _isLoading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  FriendshipStatus statusFor(String userId) {
    if (_blocked.any((u) => u.id == userId)) return FriendshipStatus.blocked;
    if (_friends.any((u) => u.id == userId)) return FriendshipStatus.friends;
    for (final r in _requests) {
      if (r.user.id == userId) {
        return r.isIncoming
            ? FriendshipStatus.requestReceived
            : FriendshipStatus.requestSent;
      }
    }
    return FriendshipStatus.none;
  }

  // Forgives typos and unfinished words; best matches first.
  List<FriendUser> searchFriends(String query) {
    if (query.trim().isEmpty) return friends;
    final scored = [
      for (final u in _friends)
        if (FuzzySearch.score(query, title: u.name, primary: [?u.username])
            case final score?)
          (u, score),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final (u, _) in scored) u];
  }

  // Friends who host or joined an activity, for the home feed card.
  List<FriendUser> friendsGoingIn(String activityId) =>
      _friendsGoing[activityId] ?? const [];

  // Called when the home feed loads; reloaded with the friends lists, so a
  // new or removed friend shows on the cards.
  Future<void> loadFriendsGoing(Iterable<String> activityIds) {
    _goingActivityIds = activityIds.toList();
    return _loadFriendsGoing();
  }

  Future<void> _loadFriendsGoing() async {
    // Waits for refresh() to know the account; it calls this again after.
    final userId = _loadedFor;
    if (userId == null || _goingActivityIds.isEmpty) return;
    try {
      final going = await _model.fetchFriendsGoing(_goingActivityIds);
      if (userId != _loadedFor) return;
      _friendsGoing = going;
      notifyListeners();
    } catch (error) {
      debugPrint('SYNK: friends going failed to load: $error');
    }
  }

  // Everyone on Synk matching the name or username, minus blocked users.
  Future<List<FriendUser>> searchPeople(String query) async {
    if (query.trim().isEmpty) return const [];
    return _model.searchPeople(query);
  }

  // People the user may know: done activities together, mutual friends or
  // shared interests.
  Future<List<FriendUser>> suggestPeople() => _model.suggestPeople();

  // Each change below returns false when it failed.

  // True when it went through. If they had already asked, you become friends.
  Future<bool> sendRequest(FriendUser user) async {
    if (statusFor(user.id) != FriendshipStatus.none) return true;
    _requests.add(
      FriendRequest(
        id: 'pending-${user.id}',
        user: user,
        createdAt: DateTime.now(),
        isIncoming: false,
      ),
    );
    return _apply(
      () => _model.sendRequest(user.id),
      failsOn: const {'self', 'not_found'},
    );
  }

  Future<bool> cancelRequest(String userId) {
    _requests.removeWhere((r) => !r.isIncoming && r.user.id == userId);
    return _apply(() => _model.cancelRequest(userId));
  }

  Future<bool> acceptRequest(String userId) async {
    final request = _incomingFrom(userId);
    if (request != null) {
      _requests.remove(request);
      _friends.insert(0, request.user);
    }
    final ok = await _apply(
      () => _model.respondToRequest(userId, accept: true),
      failsOn: const {'not_found'},
    );
    // An old chat with them opens up again.
    if (ok) unawaited(ChatController.instance.refresh());
    return ok;
  }

  Future<bool> rejectRequest(String userId) {
    _requests.removeWhere((r) => r.isIncoming && r.user.id == userId);
    return _apply(() => _model.respondToRequest(userId, accept: false));
  }

  Future<bool> removeFriend(String userId) async {
    _friends.removeWhere((u) => u.id == userId);
    final ok = await _apply(() => _model.removeFriend(userId));
    // Their chat stays, read only.
    if (ok) unawaited(ChatController.instance.refresh());
    return ok;
  }

  // Called after a block or unblock goes through, to reload the activity
  // lists, feed and chats: either person's hosted activities appear or
  // disappear, and a block takes the non-host out of the other's
  // activities. Set by the home shell.
  VoidCallback? onBlocksChanged;

  // Blocking also ends the friendship and any request between the two.
  Future<bool> block(FriendUser user) async {
    _friends.removeWhere((u) => u.id == user.id);
    _requests.removeWhere((r) => r.user.id == user.id);
    if (!_blocked.any((u) => u.id == user.id)) _blocked.insert(0, user);
    final ok = await _apply(
      () => _model.block(user.id),
      failsOn: const {'self', 'not_found'},
    );
    if (ok) onBlocksChanged?.call();
    return ok;
  }

  // For the confirmation before blocking; false when it can't be checked.
  Future<bool> blockRemovesMeFromActivity(String userId) async {
    try {
      return await _model.blockRemovesMeFromActivity(userId);
    } catch (_) {
      return false;
    }
  }

  Future<bool> unblock(String userId) async {
    _blocked.removeWhere((u) => u.id == userId);
    final ok = await _apply(() => _model.unblock(userId));
    if (ok) onBlocksChanged?.call();
    return ok;
  }

  // Shows the local change, sends it, then reloads the real lists.
  // [failsOn] lists results that mean it didn't happen; otherwise a
  // 'not_found' just means it was already done.
  Future<bool> _apply(
    Future<String> Function() change, {
    Set<String> failsOn = const {},
  }) async {
    notifyListeners();
    var ok = true;
    try {
      final result = await change();
      ok = !failsOn.contains(result);
    } catch (error) {
      debugPrint('SYNK: friends change failed: $error');
      ok = false;
    }
    await refresh();
    return ok;
  }

  FriendRequest? _incomingFrom(String userId) {
    for (final r in _requests) {
      if (r.isIncoming && r.user.id == userId) return r;
    }
    return null;
  }
}
