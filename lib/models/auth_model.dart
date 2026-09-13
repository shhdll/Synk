import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/auth_constants.dart'; 

class AuthModel {
  // Provides access to Supabase authentication.
  final SupabaseClient _supabase = Supabase.instance.client;

  // Email of the currently signed-in user, if any.
  String? get currentUserEmail => _supabase.auth.currentUser?.email;

  // Display name of the currently signed-in user, set at sign-up.
  String? get currentUserName =>
      _supabase.auth.currentUser?.userMetadata?['full_name'] as String?;

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
    // Password recovery

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
}