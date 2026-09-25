import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_model.dart';

// Reads and writes the `activities` table.
//
// Row Level Security does the access control on the server:
//   select – public activities, plus your own
//   insert/update/delete – only rows where host_id = auth.uid()
// The queries here are written to match those policies, so a signed-out
// user simply gets nothing back rather than an error.
class ActivitiesModel {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _table = 'activities';

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  // Activities hosted by the signed-in user, soonest first.
  Future<List<Activity>> fetchMine() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final rows = await _supabase
        .from(_table)
        .select()
        .eq('host_id', uid)
        .order('starts_at', ascending: true);

    return _mapRows(rows);
  }

  // Public activities from every user, soonest first. Used by the Home feed.
  Future<List<Activity>> fetchPublicFeed({int limit = 50}) async {
    final rows = await _supabase
        .from(_table)
        .select()
        .eq('is_public', true)
        .order('starts_at', ascending: true)
        .limit(limit);

    return _mapRows(rows);
  }

  // A single activity, or null when it doesn't exist or isn't visible to
  // the signed-in user (RLS hides other people's private activities).
  Future<Activity?> fetchById(String id) async {
    final row = await _supabase
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();

    return row == null ? null : Activity.fromMap(row);
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  // Inserts the activity and returns it as stored, including the database
  // generated id and created_at.
  //
  // host_id is always taken from the signed-in user, never from the caller,
  // so it can't disagree with the insert policy.
  Future<Activity> create(Activity draft) async {
    final uid = currentUserId;
    if (uid == null) {
      throw StateError('Cannot create an activity while signed out.');
    }

    final payload = draft.toInsertMap()..['host_id'] = uid;

    final row = await _supabase
        .from(_table)
        .insert(payload)
        .select()
        .single();

    return Activity.fromMap(row);
  }

  // Stores the photo's public URL after a successful upload (photo workflow
  // step 3: insert, upload, then attach). Pass null to clear it.
  Future<Activity> updatePhotoUrl(String activityId, String? photoUrl) async {
    final row = await _supabase
        .from(_table)
        .update({'photo_url': photoUrl})
        .eq('id', activityId)
        .select()
        .single();

    return Activity.fromMap(row);
  }

  // Deletes an activity. RLS allows this only for its host.
  Future<void> delete(String activityId) async {
    await _supabase.from(_table).delete().eq('id', activityId);
  }

  List<Activity> _mapRows(List<dynamic> rows) {
    return rows
        .cast<Map<String, dynamic>>()
        .map(Activity.fromMap)
        .toList();
  }
}