import 'package:supabase_flutter/supabase_flutter.dart';

// Represents the result returned after joining or reviewing a request.
class ActivityJoinResult {
  const ActivityJoinResult({
    required this.result,
    required this.message,
    this.activityId,
    this.activityTitle,
    this.status,
  });

  final String result;
  final String message;
  final String? activityId;
  final String? activityTitle;
  final String? status;

  factory ActivityJoinResult.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'] as String? ?? 'unknown';
    final message = json['message'] as String? ?? 'Something went wrong.';

    String normalizedResult = rawResult;

    // The database returns the participation status for repeated attempts.
    // Convert it to an "already" result so the UI shows the correct message.
    if (rawResult == 'pending' &&
        message.contains('waiting for host approval')) {
      normalizedResult = 'already_pending';
    } else if (rawResult == 'joined' && message.contains('already joined')) {
      normalizedResult = 'already_joined';
    } else if (rawResult == 'waitlisted' &&
        message.contains('already on the waitlist')) {
      normalizedResult = 'already_waitlisted';
    }

    return ActivityJoinResult(
      result: normalizedResult,
      message: message,
      activityId: json['activity_id'] as String?,
      activityTitle: json['activity_title'] as String?,
      status: json['status'] as String?,
    );
  }
}

// Contains the information shown to a host for a private join request.
class PendingActivityRequest {
  const PendingActivityRequest({
    required this.participationId,
    required this.activityId,
    required this.activityTitle,
    required this.requesterId,
    required this.requesterName,
    required this.requestedAt,
    this.requesterUsername,
    this.requesterAvatarUrl,
    this.requesterGender,
  });

  final String participationId;
  final String activityId;
  final String activityTitle;
  final String requesterId;
  final String requesterName;
  final String? requesterUsername;
  // Filled from the users table when the RPC doesn't return them.
  final String? requesterAvatarUrl;
  final String? requesterGender;
  final DateTime requestedAt;

  factory PendingActivityRequest.fromJson(Map<String, dynamic> json) {
    return PendingActivityRequest(
      participationId: json['participation_id'] as String,
      activityId: json['activity_id'] as String,
      activityTitle: json['activity_title'] as String,
      requesterId: json['requester_id'] as String,
      requesterName: json['requester_name'] as String? ?? 'Synk user',
      requesterUsername: json['requester_username'] as String?,
      requesterAvatarUrl: json['requester_avatar_url'] as String?,
      requesterGender: json['requester_gender'] as String?,
      requestedAt: DateTime.parse(json['requested_at'] as String),
    );
  }

  PendingActivityRequest withProfile({String? avatarUrl, String? gender}) {
    return PendingActivityRequest(
      participationId: participationId,
      activityId: activityId,
      activityTitle: activityTitle,
      requesterId: requesterId,
      requesterName: requesterName,
      requesterUsername: requesterUsername,
      requesterAvatarUrl: requesterAvatarUrl ?? avatarUrl,
      requesterGender: requesterGender ?? gender,
      requestedAt: requestedAt,
    );
  }
}

class ActivityParticipationModel {
  ActivityParticipationModel({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Sends the six-digit activity code to Supabase.
  Future<ActivityJoinResult> joinActivityByCode(String code) async {
    final response = await _client.rpc(
      'join_activity_by_code',
      params: {'entered_code': code},
    );

    return ActivityJoinResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  // Joins a public activity directly, without its code.
  Future<ActivityJoinResult> joinPublicActivity(String activityId) async {
    final response = await _client.rpc(
      'join_public_activity',
      params: {'requested_activity_id': activityId},
    );

    return ActivityJoinResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  // Returns pending requests for private activities hosted by this user.
  Future<List<PendingActivityRequest>> getPendingRequests() async {
    final response = await _client.rpc('get_pending_activity_requests');

    final rows = response as List<dynamic>;

    final requests = rows
        .map(
          (row) => PendingActivityRequest.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();

    return _withProfiles(requests);
  }

  // The RPC has no photo, so look up each requester's avatar and gender
  // (for the default avatar) in one query. Requests still load without them.
  Future<List<PendingActivityRequest>> _withProfiles(
    List<PendingActivityRequest> requests,
  ) async {
    final ids = {
      for (final r in requests)
        if (r.requesterAvatarUrl == null) r.requesterId,
    };
    if (ids.isEmpty) return requests;

    try {
      final users = await _client
          .from('users')
          .select('id, avatar_url, gender')
          .inFilter('id', ids.toList());
      final byId = {for (final u in users) u['id'] as String: u};

      return [
        for (final r in requests)
          r.withProfile(
            avatarUrl: byId[r.requesterId]?['avatar_url'] as String?,
            gender: byId[r.requesterId]?['gender'] as String?,
          ),
      ];
    } catch (_) {
      return requests;
    }
  }

  // How many requests are waiting for the host; drives the badges.
  Future<int> countPendingRequests() async {
    final response = await _client.rpc('get_pending_activity_requests');
    return response is List ? response.length : 0;
  }

  // Allows the host to accept or reject a private activity request.
  Future<ActivityJoinResult> reviewRequest({
    required String participationId,
    required bool accept,
  }) async {
    final response = await _client.rpc(
      'review_activity_join_request',
      params: {'participation_id': participationId, 'accept_request': accept},
    );

    return ActivityJoinResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
