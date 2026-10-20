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

    if (!isLongEnough) {
      return 'Password must be at least 8 characters';
    }
    if (!hasUpper) {
      return 'Password must contain at least 1 uppercase letter';
    }
    if (!hasLower) {
      return 'Password must contain at least 1 lowercase letter';
    }
    if (!hasNum) {
      return 'Password must contain at least 1 number';
    }
    if (!hasSpecial) {
      return 'Password must contain at least 1 special character (e.g., @\$!%*?&)';
    }
    return null;
  }

  /// Email validation pattern.
  static final RegExp emailRegex = RegExp(
    r'^[\w.+-]+@([\w-]+\.)+[A-Za-z]{2,}$',
  );

  /// Usernames: 3–30 letters, numbers, dots or underscores.
  static final RegExp usernameRegex = RegExp(r'^[a-zA-Z0-9._]{3,30}$');

  static String? validateUsername(String username) {
    if (username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (username.length > 30) return 'Username can be at most 30 characters';
    if (!usernameRegex.hasMatch(username)) {
      return 'Username can only contain letters, numbers, underscores, and dots';
    }
    return null;
  }

  /// Custom URL scheme that opens the app. Must match AndroidManifest.xml.
  static const String appScheme = 'io.supabase.synk';

  /// Deep link hosts used by the synk.cc landing pages.
  static const String resetPasswordHost = 'reset-password';
  static const String loginCallbackHost = 'login-callback';

  /// Redirect URL used for password recovery.
  static const String resetPasswordRedirectUrl =
      'io.supabase.synk://reset-password';

  /// Redirect URL used for email confirmation / signup.
  static const String emailRedirectUrl = 'io.supabase.synk://login-callback';

  /// Seconds the user must wait before requesting another reset email.
  static const int resendCooldownSeconds = 60;
}
