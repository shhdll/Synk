import '../../l10n/l10n.dart';

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
      return appL10n.passwordIsRequired;
    }
    final isLongEnough = password.length >= minPasswordLength;
    final hasUpper = hasUppercase.hasMatch(password);
    final hasLower = hasLowercase.hasMatch(password);
    final hasNum = hasDigit.hasMatch(password);
    final hasSpecial = hasSpecialChar.hasMatch(password);

    if (!isLongEnough) {
      return appL10n.passwordMustBeAtLeast8;
    }
    if (!hasUpper) {
      return appL10n.passwordNeedsUppercase;
    }
    if (!hasLower) {
      return appL10n.passwordNeedsLowercase;
    }
    if (!hasNum) {
      return appL10n.passwordNeedsNumber;
    }
    if (!hasSpecial) {
      return appL10n.passwordNeedsSpecial;
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
    if (username.isEmpty) return appL10n.usernameIsRequired;
    if (username.length < 3) return appL10n.usernameMustBeAtLeast3;
    if (username.length > 30) return appL10n.usernameCanBeAtMost30;
    if (!usernameRegex.hasMatch(username)) {
      return appL10n.usernameCanOnlyContainLettersNumbers;
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
