import 'package:supabase_flutter/supabase_flutter.dart';

// Reads and writes the signed-in user's row in the public "users" table,
// which holds the editable profile fields (full_name, bio, age, gender,
// interests, activity_type, location_preference, avatar_url/avatar_local_path).
//
// Email and password stay in Supabase Auth itself (see AuthModel) — this
// table only mirrors profile display data, seeded at signup by the
// `handle_new_user` database trigger.
class UserProfileModel {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _uid => _supabase.auth.currentUser?.id;

  // Returns the current user's profile row, or an empty map when signed
  // out or when the row hasn't been created yet.
  Future<Map<String, dynamic>> fetchProfile() async {
    final uid = _uid;
    if (uid == null) return {};

    final row = await _supabase
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return row ?? {};
  }

  // Merges the given fields into the current user's row (columns not
  // included here are left untouched).
  Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return;

    await _supabase.from('users').update(data).eq('id', uid);
  }
}
