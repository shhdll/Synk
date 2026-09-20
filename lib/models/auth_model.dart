import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';

class AuthModel {
  // Provides access to Supabase authentication.
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Signs in directly with email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  // 2. Signs in strictly with username and password.
  Future<AuthResponse> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();

    // Look up the email mapped to this username in public.users
    final userRecord = await _supabase
        .from('users')
        .select('email')
        .ilike('username', cleanUsername)
        .maybeSingle();

    if (userRecord == null || userRecord['email'] == null) {
      throw const AuthException('No account found with this username.');
    }

    final email = userRecord['email'] as String;

    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Signs up a new user, saving their username and email in user_metadata.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim();

    return await _supabase.auth.signUp(
      email: cleanEmail,
      password: password,
      data: {'username': cleanUsername, 'email': cleanEmail},
    );
  }

  // Ends the current user's session.
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Listens for authentication state changes, including password recovery.
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sends a password reset email to the user.
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AuthConstants.resetPasswordRedirectUrl,
    );
  }

  // Updates the password during the recovery session.
  Future<UserResponse> updatePassword(String newPassword) async {
    return await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // Requests an email change. Supabase emails the new address a
  // confirmation link before the change actually takes effect.
  Future<UserResponse> updateEmail(String newEmail) async {
    return await _supabase.auth.updateUser(
      UserAttributes(email: newEmail.trim()),
    );
  }
}
