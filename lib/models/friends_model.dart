import 'package:supabase_flutter/supabase_flutter.dart';

// Friends, friend requests and blocks. Changes go through database functions
// (supabase/migrations/20261028200000_friends.sql), which enforce the rules.

// Where the signed-in user stands with someone else.
enum FriendshipStatus { none, requestSent, requestReceived, friends, blocked }

// Another Synk user, as shown in the friends screens.
class FriendUser {
  const FriendUser({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
    this.gender,
  });

  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? gender;

  // [idKey] is 'user_id' for request rows, whose 'id' is the request's.
  factory FriendUser.fromMap(Map<String, dynamic> map, {String idKey = 'id'}) {
    final username = (map['username'] as String?)?.trim();
    final fullName = (map['full_name'] as String?)?.trim();
    return FriendUser(
      id: map[idKey] as String,
      name: fullName != null && fullName.isNotEmpty
          ? fullName
          : (username ?? ''),
      username: username,
      avatarUrl: map['avatar_url'] as String?,
      gender: map['gender'] as String?,
    );
  }
}

// A pending friend request, sent by or to the signed-in user.
class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.user,
    required this.createdAt,
    required this.isIncoming,
  });

  final String id;

  // The other person: the sender when incoming, the receiver when sent.
  final FriendUser user;
  final DateTime createdAt;
  final bool isIncoming;

  factory FriendRequest.fromMap(Map<String, dynamic> map) {
    return FriendRequest(
      id: map['id'] as String,
      user: FriendUser.fromMap(map, idKey: 'user_id'),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      isIncoming: map['is_incoming'] == true,
    );
  }
}

class FriendsModel {
  // Looked up on use, so widgets can build without Supabase (e.g. in tests).
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<List<FriendUser>> fetchFriends() => _fetchUsers('get_my_friends');

  Future<List<FriendUser>> fetchBlocked() =>
      _fetchUsers('get_my_blocked_users');

  Future<List<FriendRequest>> fetchRequests() async {
    final response = await _supabase.rpc('get_my_friend_requests');
    if (response is! List) return const [];
    return response
        .map((row) => FriendRequest.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendUser>> searchPeople(String query) async {
    final response = await _supabase.rpc(
      'search_users',
      params: {'search_query': query},
    );
    if (response is! List) return const [];
    return response
        .map((row) => FriendUser.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // Friends who host or joined each activity, keyed by activity id.
  Future<Map<String, List<FriendUser>>> fetchFriendsGoing(
    List<String> activityIds,
  ) async {
    if (activityIds.isEmpty) return const {};
    final response = await _supabase.rpc(
      'get_friends_going',
      params: {'activity_ids': activityIds},
    );
    if (response is! List) return const {};
    final going = <String, List<FriendUser>>{};
    for (final row in response.cast<Map<String, dynamic>>()) {
      going
          .putIfAbsent(row['activity_id'] as String, () => [])
          .add(FriendUser.fromMap(row, idKey: 'user_id'));
    }
    return going;
  }

  // Each returns the function's result, e.g. 'sent' or 'now_friends'.

  Future<String> sendRequest(String userId) =>
      _change('send_friend_request', {'target_user_id': userId});

  Future<String> cancelRequest(String userId) =>
      _change('cancel_friend_request', {'target_user_id': userId});

  Future<String> respondToRequest(String userId, {required bool accept}) =>
      _change('respond_to_friend_request', {
        'requester_id': userId,
        'accept': accept,
      });

  Future<String> removeFriend(String userId) =>
      _change('remove_friend', {'friend_id': userId});

  Future<String> block(String userId) =>
      _change('block_user', {'target_user_id': userId});

  Future<String> unblock(String userId) =>
      _change('unblock_user', {'target_user_id': userId});

  Future<List<FriendUser>> _fetchUsers(String function) async {
    final response = await _supabase.rpc(function);
    if (response is! List) return const [];
    return response
        .map((row) => FriendUser.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<String> _change(String function, Map<String, dynamic> params) async {
    final response = await _supabase.rpc(function, params: params);
    if (response is Map && response['result'] is String) {
      return response['result'] as String;
    }
    return '';
  }
}
