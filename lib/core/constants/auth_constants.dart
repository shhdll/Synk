class AuthConstants {
  AuthConstants._();

    /// Minimum password length used for authentication.
  static const int minPasswordLength = 6;

 /// Email validation pattern.
  static final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  /// Redirect URL used for password recovery.
  static const String resetPasswordRedirectUrl =
      'io.supabase.synk://reset-password';

  /// Seconds the user must wait before requesting another reset email.
  static const int resendCooldownSeconds = 60;
}