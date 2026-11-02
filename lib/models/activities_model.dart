import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';
import 'activity_model.dart';

// Reads and writes activity data stored in Supabase.
class ActivitiesModel {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'activities';

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  // Activities hosted by the signed-in user.
  Future<List<Activity>> fetchMine() async {
    final uid = currentUserId;

    if (uid == null) {
      return [];
    }

    final rows = await _supabase
        .from(_table)
        .select()
        .eq('host_id', uid)
        .order('starts_at', ascending: true);

    return _mapRows(rows);
  }

  // Returns joined, pending, and waitlisted activities for the current user.
  Future<List<Activity>> fetchParticipating() async {
    if (currentUserId == null) {
      return [];
    }

    final response = await _supabase.rpc('get_my_activity_participations');

    if (response is! List) {
      return [];
    }

    final activities = response
        .map((row) => Activity.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();

    return _withActivityCodes(activities);
  }

  Future<Activity?> resolveActivityCode(String code) async {
    final response = await _supabase.rpc(
      'resolve_activity_code',
      params: {'entered_code': code},
    );
    final row = Map<String, dynamic>.from(response as Map);
    if (row['found'] != true) return null;
    return Activity.fromMap(Map<String, dynamic>.from(row['activity'] as Map));
  }

  static bool hasPendingOverlap(Activity target, Iterable<Activity> activities) {
    return activities.any((existing) {
      if (existing.id == target.id ||
          (existing.participationStatus != 'pending' &&
              existing.participationStatus != 'waitlisted')) return false;
      return target.dateTime.isBefore(existing.endsAt) &&
          target.endsAt.isAfter(existing.dateTime);
    });
  }

  // The RPC strips codes, so read them for joined activities.
  Future<List<Activity>> _withActivityCodes(List<Activity> activities) async {
    final ids = [
      for (final a in activities)
        if (a.isJoined && !a.hasActivityCode) a.id,
    ];
    if (ids.isEmpty) return activities;

    try {
      final rows = await _supabase
          .from(_table)
          .select('id, activity_code')
          .inFilter('id', ids);
      final codes = {
        for (final row in rows)
          row['id'] as String: row['activity_code'] as String?,
      };
      return [
        for (final a in activities)
          codes[a.id] == null ? a : a.copyWith(activityCode: codes[a.id]),
      ];
    } catch (_) {
      return activities;
    }
  }

  // Completed activities count for any user, computed on the server.
  // Defaults to the signed-in user. Needs the
  // 20261018_completed_activities_count migration.
  Future<int> fetchCompletedCount({String? userId}) async {
    final response = await _supabase.rpc(
      'get_completed_activities_count',
      params: {'target_user_id': ?userId},
    );

    return (response as num?)?.toInt() ?? 0;
  }

  // A page of a user's ended activities, newest first. Only the user and
  // their friends get results; locations are never included.
  Future<UserActivityHistoryPage> fetchUserRecentActivities({
    required String userId,
    int limit = 10,
    int offset = 0,
  }) async {
    final response = await _supabase.rpc(
      'get_user_recent_activities',
      params: {
        'target_user_id': userId,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    final map = Map<String, dynamic>.from(response as Map);

    return UserActivityHistoryPage(
      allowed: map['allowed'] as bool? ?? false,
      activities: _mapRows(map['activities'] as List? ?? const []),
      hasMore: map['has_more'] as bool? ?? false,
    );
  }

  // Kept temporarily for callers that still use the previous method name.
  Future<List<Activity>> fetchJoined() {
    return fetchParticipating();
  }

  // Upcoming public activities from every user.
  Future<List<Activity>> fetchPublicFeed({int limit = 50}) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    final rows = await _supabase
        .from(_table)
        .select()
        .eq('is_public', true)
        .gte('starts_at', nowUtc)
        .order('starts_at', ascending: true)
        .limit(limit);

    return _mapRows(rows);
  }

  // Discovery Feed for Home Page:
  // - Excludes activities hosted by current user (host_id != currentUserId).
  // - Enforces Gender Visibility Rule: activities are only visible to users
  //   whose profile gender matches the host's (men see men's activities,
  //   women see women's).
  // - Batches host profiles and participant counts.
  Future<List<Activity>> fetchDiscoveryFeed({
    String? currentUserId,
    String? currentUserGender,
    int limit = 60,
  }) async {
    // Preferred path: the server applies the exclusion and gender rules.
    try {
      final response = await _supabase.rpc(
        'get_discovery_feed',
        params: {'p_limit': limit},
      );
      if (response is List) {
        return response
            .map(
              (row) => Activity.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
      }
    } catch (_) {
      // RPC not deployed yet; fall back to the client-side query below.
    }

    final nowUtc = DateTime.now().toUtc().toIso8601String();

    var query = _supabase
        .from(_table)
        .select()
        .eq('is_public', true)
        .gte('starts_at', nowUtc);

    final uid = currentUserId ?? this.currentUserId;
    if (uid != null) {
      query = query.neq('host_id', uid);
    }

    final rows = await query.order('starts_at', ascending: true).limit(limit);

    if (rows.isEmpty) return [];

    // Collect distinct host IDs and activity IDs
    final hostIds = <String>{};
    final activityIds = <String>{};

    for (final row in rows) {
      final hostId = row['host_id'] as String?;
      if (hostId != null && hostId.isNotEmpty) {
        hostIds.add(hostId);
      }
      final activityId = row['id'] as String?;
      if (activityId != null && activityId.isNotEmpty) {
        activityIds.add(activityId);
      }
    }

    // 1. Batch fetch host profiles
    final hostProfiles = <String, Map<String, dynamic>>{};
    if (hostIds.isNotEmpty) {
      try {
        final profileRows = await _supabase
            .from('users')
            .select('id, full_name, username, avatar_url, gender')
            .inFilter('id', hostIds.toList());

        for (final p in profileRows) {
          final id = p['id'] as String?;
          if (id != null) {
            hostProfiles[id] = p;
          }
        }
      } catch (_) {
        // Host genders are unknown, so the gender rule cannot be checked.
        // Fail closed.
        return [];
      }
    }

    // 2. Batch fetch joined participant counts
    final participantCounts = <String, int>{};
    if (activityIds.isNotEmpty) {
      try {
        final participantRows = await _supabase
            .from('activity_participants')
            .select('activity_id')
            .inFilter('activity_id', activityIds.toList())
            .eq('status', 'joined');

        for (final pr in participantRows) {
          final actId = pr['activity_id'] as String?;
          if (actId != null) {
            participantCounts[actId] = (participantCounts[actId] ?? 0) + 1;
          }
        }
      } catch (_) {
        // Fallback gracefully
      }
    }

    // 3. Filter by Gender Visibility Rule:
    // Only activities whose host has the same gender as the viewer.
    final viewerGender = currentUserGender?.trim().toLowerCase() ?? '';

    final result = <Activity>[];

    for (final row in rows) {
      final hostId = row['host_id'] as String?;
      final hostProfile = hostId != null ? hostProfiles[hostId] : null;

      final hostGender = (hostProfile?['gender'] as String?)
          ?.trim()
          .toLowerCase();
      if (viewerGender.isEmpty || hostGender != viewerGender) {
        // Excluded by Gender Visibility Rule (unknown genders fail closed)
        continue;
      }

      final activityId = row['id'] as String;
      // Host counts as 1 participant + joined participants count
      final joinedCount = 1 + (participantCounts[activityId] ?? 0);

      final activity = Activity.fromMap(row).copyWith(
        hostName: hostProfile?['full_name'] as String?,
        hostUsername: hostProfile?['username'] as String?,
        hostAvatarUrl: hostProfile?['avatar_url'] as String?,
        hostGender: hostProfile?['gender'] as String?,
        participantsCount: joinedCount,
      );

      result.add(activity);
    }

    return result;
  }

  // Returns joined participants list for activity details view
  Future<List<Map<String, dynamic>>> fetchParticipantsList(
    String activityId,
  ) async {
    try {
      final response = await _supabase.rpc(
        'get_activity_participants_list',
        params: {'p_activity_id': activityId},
      );
      if (response is List) {
        return response
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
    } catch (_) {}

    // Fallback: Query activity_participants & users directly
    try {
      final rows = await _supabase
          .from('activity_participants')
          .select('user_id, status')
          .eq('activity_id', activityId)
          .eq('status', 'joined');

      final userIds = rows
          .map((r) => r['user_id'] as String?)
          .whereType<String>()
          .toList();

      if (userIds.isNotEmpty) {
        final users = await _supabase
            .from('users')
            .select('id, full_name, username, avatar_url, gender')
            .inFilter('id', userIds);

        return users
            .map(
              (u) => {
                'user_id': u['id'],
                'full_name': u['full_name'] ?? appL10n.synkMember,
                'username': u['username'],
                'avatar_url': u['avatar_url'],
                'gender': u['gender'],
                'status': 'joined',
              },
            )
            .toList();
      }
    } catch (_) {}

    return [];
  }

  // Returns one activity visible to the signed-in user.
  Future<Activity?> fetchById(String id) async {
    final row = await _supabase
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return Activity.fromMap(row);
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  // Client preflight for the server's authoritative schedule guard. The
  // database repeats this check under a per-user lock to cover races.
  Future<String?> checkScheduleConflict({
    required DateTime startsAt,
    required DateTime endsAt,
    String? excludedActivityId,
  }) async {
    final response = await _supabase.rpc(
      'check_activity_schedule',
      params: {
        'proposed_start': startsAt.toUtc().toIso8601String(),
        'proposed_end': endsAt.toUtc().toIso8601String(),
        'excluded_activity_id': excludedActivityId,
      },
    );
    final result = Map<String, dynamic>.from(response as Map);
    return result['conflict'] == true ? result['message'] as String? : null;
  }

  Future<List<Map<String, dynamic>>> fetchScheduleConflicts() async {
    final response = await _supabase.rpc('get_my_schedule_conflicts');
    if (response is! List) return const [];
    return response
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<int> fetchConfirmedParticipantCount(String activityId) async {
    final response = await _supabase.rpc(
      'get_activity_participants_list',
      params: {'p_activity_id': activityId},
    );
    if (response is! List) {
      throw StateError('Could not load confirmed activity participants.');
    }
    return 1 + response.length;
  }

  Future<Map<String, dynamic>> resolveScheduleConflicts(
    List<String> keepActivityIds,
  ) async {
    final response = await _supabase.rpc(
      'resolve_my_schedule_conflicts',
      params: {'keep_activity_ids': keepActivityIds},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  // Creates an activity owned by the signed-in user.
  Future<Activity> create(Activity draft) async {
    final uid = currentUserId;

    if (uid == null) {
      throw StateError(appL10n.cannotCreateAnActivityWhileSigned);
    }

    final payload = draft.toInsertMap()..['host_id'] = uid;

    final row = await _supabase.from(_table).insert(payload).select().single();

    return Activity.fromMap(row);
  }

  // Updates editable fields on an activity owned by the signed-in user.
  Future<Activity> update(Activity draft) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError(appL10n.cannotUpdateActivitySignedOut);
    }

    final payload = draft.toInsertMap()..remove('host_id');
    final rows = await _supabase
        .from(_table)
        .update(payload)
        .eq('id', draft.id)
        .eq('host_id', uid)
        .select();
    if (rows.isEmpty) {
      throw StateError(appL10n.activityNotFoundOrCannotUpdate);
    }
    return Activity.fromMap(rows.first).copyWith(
      hostName: draft.hostName,
      hostUsername: draft.hostUsername,
      hostAvatarUrl: draft.hostAvatarUrl,
      hostGender: draft.hostGender,
      participantsCount: draft.participantsCount,
    );
  }

  // Updates or removes the activity photo URL.
  Future<Activity> updatePhotoUrl(String activityId, String? photoUrl) async {
    final row = await _supabase
        .from(_table)
        .update({'photo_url': photoUrl})
        .eq('id', activityId)
        .select()
        .single();

    return Activity.fromMap(row);
  }

  // Deletes an activity owned by the signed-in user.
  // Related participation records are removed by ON DELETE CASCADE.
  Future<void> delete(String activityId) async {
    final uid = currentUserId;

    if (uid == null) {
      throw StateError(appL10n.cannotDeleteAnActivityWhileSigned);
    }

    final deletedRows = await _supabase
        .from(_table)
        .delete()
        .eq('id', activityId)
        .eq('host_id', uid)
        .select('id');

    // RLS or the host filter prevents deleting another user's activity.
    if (deletedRows.isEmpty) {
      throw StateError(appL10n.theActivityWasNotFoundOr);
    }
  }

  List<Activity> _mapRows(List<dynamic> rows) {
    return rows.cast<Map<String, dynamic>>().map(Activity.fromMap).toList();
  }
}

// One page of another user's activity history.
class UserActivityHistoryPage {
  const UserActivityHistoryPage({
    required this.allowed,
    required this.activities,
    required this.hasMore,
  });

  // False when the viewer may not see this user's history.
  final bool allowed;
  final List<Activity> activities;
  final bool hasMore;
}
