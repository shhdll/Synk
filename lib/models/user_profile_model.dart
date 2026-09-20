import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileModel {
  final SupabaseClient _supabase = Supabase.instance.client;

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

  /// Checks if a username is already taken by a different user.
  Future<bool> isUsernameTaken(String username) async {
    final uid = _uid;
    final cleanUsername = username.trim().toLowerCase();

    var query = _supabase
        .from('users')
        .select('id')
        .ilike('username', cleanUsername);

    if (uid != null) {
      query = query.neq('id', uid);
    }

    final existing = await query.maybeSingle();
    return existing != null;
  }

  /// Updates the currently signed-in user's profile.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = _uid;

    if (uid == null) {
      return;
    }

    // Clean username if provided
    if (data.containsKey('username') && data['username'] is String) {
      final cleanUsername = (data['username'] as String).trim().toLowerCase();
      data['username'] = cleanUsername;

      // Keep auth metadata in sync
      await _supabase.auth.updateUser(
        UserAttributes(data: {'username': cleanUsername}),
      );
    }

    await _supabase.from('users').update(data).eq('id', uid);
  }
}
