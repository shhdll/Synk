import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileModel {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  String? get _uid {
    return _supabase.auth.currentUser?.id;
  }

  /// Gets the currently signed-in user's profile.
  Future<Map<String, dynamic>> fetchProfile() async {
    final uid = _uid;

    if (uid == null) {
      return {};
    }

    final row = await _supabase
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();

    return row ?? {};
  }

  /// Updates the currently signed-in user's profile.
  Future<void> updateProfile(
    Map<String, dynamic> data,
  ) async {
    final uid = _uid;

    if (uid == null) {
      return;
    }

    await _supabase
        .from('users')
        .update(data)
        .eq('id', uid);
  }
}