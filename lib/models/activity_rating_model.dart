import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_model.dart';

// Someone who attended the same ended activity and can be rated.
class RatingParticipant {
  const RatingParticipant({
    required this.userId,
    this.name,
    this.username,
    this.avatarUrl,
    this.gender,
    this.isHost = false,
    this.previousHalfStars,
  });

  factory RatingParticipant.fromMap(Map<String, dynamic> map) {
    return RatingParticipant(
      userId: map['user_id'] as String,
      name: map['full_name'] as String?,
      username: map['username'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      gender: map['gender'] as String?,
      isHost: map['is_host'] as bool? ?? false,
      previousHalfStars: (map['my_halves'] as num?)?.toInt(),
    );
  }

  final String userId;
  final String? name;
  final String? username;
  final String? avatarUrl;
  final String? gender;
  final bool isHost;

  // What the user gave them before, in half stars; null if not rated.
  final int? previousHalfStars;
}

// An ended activity with the attendees the user has not rated yet.
class PendingActivityRating {
  const PendingActivityRating({
    required this.activity,
    required this.participants,
  });

  factory PendingActivityRating.fromMap(Map<String, dynamic> map) {
    final participants = (map['participants'] as List? ?? const [])
        .map(
          (row) => RatingParticipant.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();

    return PendingActivityRating(
      activity: Activity.fromMap(map),
      participants: participants,
    );
  }

  final Activity activity;
  final List<RatingParticipant> participants;
}

// Star ratings between attendees. All rules are enforced by the database.
class ActivityRatingModel {
  ActivityRatingModel({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  // Ended activities the signed-in user can still rate, newest first.
  Future<List<PendingActivityRating>> fetchPending() async {
    final response = await _client.rpc('get_pending_activity_ratings');
    final rows = response as List? ?? const [];

    return rows
        .map(
          (row) => PendingActivityRating.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  // An ended activity the user was in, with everyone they can rate and
  // their earlier stars. Null when the user can't rate it.
  Future<PendingActivityRating?> fetchForActivity(String activityId) async {
    final response = await _client.rpc(
      'get_activity_rating',
      params: {'requested_activity_id': activityId},
    );
    if (response is! Map) return null;
    return PendingActivityRating.fromMap(Map<String, dynamic>.from(response));
  }

  // Saves all ratings or none. [halfStarsByUser] maps a user id to 1–10
  // half stars. Returns the database result, such as 'rated'.
  Future<String> submit({
    required String activityId,
    required Map<String, int> halfStarsByUser,
  }) async {
    final ratings = [
      for (final entry in halfStarsByUser.entries)
        {'user_id': entry.key, 'stars': entry.value / 2},
    ];

    final response = await _client.rpc(
      'submit_activity_ratings',
      params: {'requested_activity_id': activityId, 'ratings': ratings},
    );

    return (response as Map?)?['result'] as String? ?? 'unknown';
  }

  // Stops offering the rating prompt for this activity.
  Future<void> dismiss(String activityId) async {
    await _client.rpc(
      'dismiss_activity_rating',
      params: {'requested_activity_id': activityId},
    );
  }
}
