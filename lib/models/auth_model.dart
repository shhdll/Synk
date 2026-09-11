import 'package:supabase_flutter/supabase_flutter.dart';

class AuthModel {
  // Provides access to Supabase authentication.
  final SupabaseClient _supabase = Supabase.instance.client;

  // Signs in an existing user with an email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Ends the current user's session.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}