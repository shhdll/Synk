import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';
import '../services/push_notification_service.dart';
import '../utils/auth_errors.dart';

class AuthModel {
  AuthModel({this.supabaseClient});

  final SupabaseClient? supabaseClient;
  SupabaseClient get _supabase => supabaseClient ?? Supabase.instance.client;

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
    final email = await emailForUsername(username);
    if (email == null) {
      throw const AuthException(
        'No account found with this username.',
        code: 'username_not_found',
      );
    }

    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Looks up the email mapped to this username in public.users.
  Future<String?> emailForUsername(String username) async {
    final userRecord = await _supabase
        .from('users')
        .select('email')
        .ilike('username', escapeLike(username.trim().toLowerCase()))
        .limit(1)
        .maybeSingle();
    return userRecord?['email'] as String?;
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
      emailRedirectTo: AuthConstants.emailRedirectUrl,
      data: {'username': cleanUsername, 'email': cleanEmail},
    );
  }

  // Ends the current user's session.
  Future<void> signOut() async {
    if (PushNotificationService.instance.isInitialized) {
      await PushNotificationService.instance.unregisterCurrentDevice(
        client: _supabase,
      );
    }
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

  // Confirms the signed-in user's current password by signing in again
  // with it. Throws AuthException when the password is wrong.
  Future<void> verifyCurrentPassword(String currentPassword) async {
    final email = _supabase.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw AuthSessionMissingException();
    }

    await _supabase.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
  }

  static String? _locallyCancelledPendingEmail;

  static void setLocallyCancelledEmail(String? email) {
    _locallyCancelledPendingEmail = email;
  }

  static bool isEmailChangeCancelled(String? pendingEmail) {
    if (pendingEmail == null || pendingEmail.isEmpty) return false;
    if (_locallyCancelledPendingEmail != null &&
        _locallyCancelledPendingEmail == pendingEmail) {
      return true;
    }
    try {
      final metaCancelled =
          Supabase
                  .instance
                  .client
                  .auth
                  .currentUser
                  ?.userMetadata?['cancelled_email_change']
              as String?;
      if (metaCancelled != null && metaCancelled == pendingEmail) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Requests an email change. Supabase emails the new address a
  // confirmation link before the change actually takes effect.
  Future<UserResponse> updateEmail(String newEmail) async {
    final cleanEmail = newEmail.trim();
    setLocallyCancelledEmail(null);
    return await _supabase.auth.updateUser(
      UserAttributes(email: cleanEmail, data: {'cancelled_email_change': null}),
    );
  }

  // Cancels a pending email change request.
  Future<void> cancelEmailChange(String pendingEmail) async {
    setLocallyCancelledEmail(pendingEmail);

    // 1. Mark as cancelled in Supabase user metadata so it persists across sessions
    try {
      await _supabase.auth.updateUser(
        UserAttributes(data: {'cancelled_email_change': pendingEmail}),
      );
    } catch (_) {}

    // 2. Attempt PostgreSQL RPC function if deployed
    try {
      await _supabase.rpc('cancel_email_change');
    } catch (_) {}

    // 3. Refresh user session
    try {
      await _supabase.auth.getUser();
    } catch (_) {}
  }
}
