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

    return response
        .map((row) => Activity.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
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
