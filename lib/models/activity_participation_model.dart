import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';

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
    final message = json['message'] as String? ?? appL10n.somethingWentWrong;

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
      message: serverMessage(message),
      activityId: json['activity_id'] as String?,
      activityTitle: json['activity_title'] as String?,
      status: json['status'] as String?,
    );
  }
}

// What check_in_to_activity returned: 'checked_in', 'already_checked_in',
// 'too_far', 'not_started', 'ended', 'not_participating', 'host',
// 'no_location', 'invalid_location' or 'not_found'.
class ActivityCheckInResponse {
  const ActivityCheckInResponse({
    required this.result,
    this.checkedInAt,
    this.distanceMeters,
  });

  final String result;
  final DateTime? checkedInAt;
  final int? distanceMeters;

  factory ActivityCheckInResponse.fromJson(Map<String, dynamic> json) {
    final checkedInAt = json['checked_in_at'] as String?;
    return ActivityCheckInResponse(
      result: json['result'] as String? ?? 'unknown',
      checkedInAt: checkedInAt == null
          ? null
          : DateTime.parse(checkedInAt).toLocal(),
      distanceMeters: (json['distance_meters'] as num?)?.toInt(),
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
  final String? requesterAvatarUrl;
  final String? requesterGender;
  final DateTime requestedAt;

  factory PendingActivityRequest.fromJson(Map<String, dynamic> json) {
    return PendingActivityRequest(
      participationId: json['participation_id'] as String,
      activityId: json['activity_id'] as String,
      activityTitle: json['activity_title'] as String,
      requesterId: json['requester_id'] as String,
      requesterName: json['requester_name'] as String? ?? appL10n.synkUser,
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

  // The RPC has no photos, so fetch them separately.
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

  Future<int> countPendingRequests() async {
    final response = await _client.rpc('get_pending_activity_requests');
    return response is List ? response.length : 0;
  }

  // Returns an activity's joined participants. Errors are passed to the caller.
  Future<List<Map<String, dynamic>>> fetchJoinedParticipants(
    String activityId,
  ) async {
    final response = await _client.rpc(
      'get_activity_participants_list',
      params: {'p_activity_id': activityId},
    );

    final rows = response as List<dynamic>;

    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
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

  // Leaves an activity or its waitlist, or cancels a pending request.
  Future<ActivityJoinResult> leaveActivity(String activityId) async {
    final response = await _client.rpc(
      'leave_activity',
      params: {'requested_activity_id': activityId},
    );

    return ActivityJoinResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  // Number of waitlisted users ahead of the signed-in user, or null when
  // they are not on this activity's waitlist.
  Future<int?> fetchWaitlistPosition(String activityId) async {
    final response = await _client.rpc(
      'get_my_waitlist_position',
      params: {'requested_activity_id': activityId},
    );

    return (response as num?)?.toInt();
  }

  // Checks the signed-in member in. The server refuses unless the activity
  // is running and the given position is within 200 m of its location.
  Future<ActivityCheckInResponse> checkIn({
    required String activityId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client.rpc(
      'check_in_to_activity',
      params: {
        'requested_activity_id': activityId,
        'user_latitude': latitude,
        'user_longitude': longitude,
      },
    );

    return ActivityCheckInResponse.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  // When the signed-in user checked in to this activity, or null.
  Future<DateTime?> fetchMyCheckIn(String activityId) async {
    final response = await _client.rpc(
      'get_my_activity_check_in',
      params: {'requested_activity_id': activityId},
    );

    return response is String ? DateTime.parse(response).toLocal() : null;
  }

  // Who has checked in, by user id. Empty unless the viewer is the host or
  // a joined member.
  Future<Map<String, DateTime>> fetchCheckIns(String activityId) async {
    final response = await _client.rpc(
      'get_activity_check_ins',
      params: {'p_activity_id': activityId},
    );

    return {
      for (final row in response as List<dynamic>)
        row['user_id'] as String: DateTime.parse(
          row['checked_in_at'] as String,
        ).toLocal(),
    };
  }

  // Makes a joined participant the new host and removes the current host.
  Future<ActivityJoinResult> transferHostAndLeave({
    required String activityId,
    required String newHostUserId,
  }) async {
    final response = await _client.rpc(
      'transfer_host_and_leave',
      params: {
        'requested_activity_id': activityId,
        'new_host_user_id': newHostUserId,
      },
    );

    return ActivityJoinResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  // Lets the host remove a joined participant before the activity starts.
  Future<ActivityJoinResult> removeParticipant({
    required String activityId,
    required String participantUserId,
  }) async {
    final response = await _client.rpc(
      'remove_participant',
      params: {
        'requested_activity_id': activityId,
        'participant_user_id': participantUserId,
      },
    );

    return ActivityJoinResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}
