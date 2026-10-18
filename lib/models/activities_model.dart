import 'package:supabase_flutter/supabase_flutter.dart';

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

  // The participations RPC leaves out activity codes. Activities the user
  // has joined are readable directly (public ones, and private ones via
  // the "Joined users can view private activities" policy), so fetch their
  // codes from there. Pending requests stay without one.
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
  // - Enforces Gender Visibility Rule: Activities hosted by female users are
  //   ONLY visible to users whose profile gender is 'Female'.
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
        // Fail closed for viewers who are not female.
        if (currentUserGender?.trim().toLowerCase() != 'female') return [];
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
    // Activities hosted by female users are ONLY visible to users whose profile gender is 'Female'.
    final isViewerFemale = currentUserGender?.trim().toLowerCase() == 'female';

    final result = <Activity>[];

    for (final row in rows) {
      final hostId = row['host_id'] as String?;
      final hostProfile = hostId != null ? hostProfiles[hostId] : null;

      final hostGender = (hostProfile?['gender'] as String?)
          ?.trim()
          .toLowerCase();
      final isHostFemale = hostGender == 'female';

      if (!isViewerFemale && (hostProfile == null || isHostFemale)) {
        // Excluded by Gender Visibility Rule (unknown hosts fail closed)
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
                'full_name': u['full_name'] ?? 'Synk member',
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

  // Creates an activity owned by the signed-in user.
  Future<Activity> create(Activity draft) async {
    final uid = currentUserId;

    if (uid == null) {
      throw StateError('Cannot create an activity while signed out.');
    }

    final payload = draft.toInsertMap()..['host_id'] = uid;

    final row = await _supabase.from(_table).insert(payload).select().single();

    return Activity.fromMap(row);
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
      throw StateError('Cannot delete an activity while signed out.');
    }

    final deletedRows = await _supabase
        .from(_table)
        .delete()
        .eq('id', activityId)
        .eq('host_id', uid)
        .select('id');

    // RLS or the host filter prevents deleting another user's activity.
    if (deletedRows.isEmpty) {
      throw StateError('The activity was not found or cannot be deleted.');
    }
  }

  List<Activity> _mapRows(List<dynamic> rows) {
    return rows.cast<Map<String, dynamic>>().map(Activity.fromMap).toList();
  }
}
