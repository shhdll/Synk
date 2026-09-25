class AuthConstants {
  AuthConstants._();

  /// Minimum password length used for authentication.
  static const int minPasswordLength = 8;

  /// Password complexity regex patterns.
  static final RegExp hasUppercase = RegExp(r'[A-Z]');
  static final RegExp hasLowercase = RegExp(r'[a-z]');
  static final RegExp hasDigit = RegExp(r'[0-9]');
  static final RegExp hasSpecialChar = RegExp(
    r'[@$!%*?&_\-#^~+=<>.,:;/\\]|[^a-zA-Z0-9]',
  );

  /// Validates password against standard security rules:
  /// - At least 8 characters
  /// - At least 1 uppercase letter
  /// - At least 1 lowercase letter
  /// - At least 1 number
  /// - At least 1 special character
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    final isLongEnough = password.length >= minPasswordLength;
    final hasUpper = hasUppercase.hasMatch(password);
    final hasLower = hasLowercase.hasMatch(password);
    final hasNum = hasDigit.hasMatch(password);
    final hasSpecial = hasSpecialChar.hasMatch(password);

    if (!isLongEnough || !hasUpper || !hasLower || !hasNum || !hasSpecial) {
      return 'Password must be at least 8 characters and include uppercase, lowercase, a number, and a special character';
    }
    return null;
  }

  /// Email validation pattern.
  static final RegExp emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  /// Redirect URL used for password recovery.
  static const String resetPasswordRedirectUrl =
      'io.supabase.synk://reset-password';

  /// Seconds the user must wait before requesting another reset email.
  static const int resendCooldownSeconds = 60;
}
