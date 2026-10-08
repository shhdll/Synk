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
    return ActivityJoinResult(
      result: json['result'] as String? ?? 'unknown',
      message: json['message'] as String? ?? 'Something went wrong.',
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
  });

  final String participationId;
  final String activityId;
  final String activityTitle;
  final String requesterId;
  final String requesterName;
  final String? requesterUsername;
  final DateTime requestedAt;

  factory PendingActivityRequest.fromJson(Map<String, dynamic> json) {
    return PendingActivityRequest(
      participationId: json['participation_id'] as String,
      activityId: json['activity_id'] as String,
      activityTitle: json['activity_title'] as String,
      requesterId: json['requester_id'] as String,
      requesterName: json['requester_name'] as String? ?? 'Synk user',
      requesterUsername: json['requester_username'] as String?,
      requestedAt: DateTime.parse(json['requested_at'] as String),
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

  // Returns pending requests for private activities hosted by this user.
  Future<List<PendingActivityRequest>> getPendingRequests() async {
    final response = await _client.rpc('get_pending_activity_requests');

    final rows = response as List<dynamic>;

    return rows
        .map(
          (row) => PendingActivityRequest.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
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
