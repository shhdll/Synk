import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';
import '../models/auth_model.dart';
import '../utils/auth_errors.dart';
import '../views/onboarding_view.dart';

// Which field a login error belongs to, so the view can show it there.
enum LoginErrorType {
  noAccount,
  wrongCredentials,
  emailNotConfirmed,
  suspended,
  other,
}

class LoginController extends ChangeNotifier {
  LoginController({AuthModel? authModel})
    : _authModel = authModel ?? AuthModel();

  final AuthModel _authModel;

  bool _isLoading = false;
  String? _errorMessage;
  LoginErrorType? _errorType;
  String? _accountEmail;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  LoginErrorType? get errorType => _errorType;

  // The account's email, set even when logging in by username. Used to send
  // unconfirmed users to the verification screen.
  String? get accountEmail => _accountEmail;

  // Clear previous error message when user retypes or switches tabs
  void clearError() {
    if (_errorMessage != null || _errorType != null) {
      _errorMessage = null;
      _errorType = null;
      notifyListeners();
    }
  }

  // Signs in strictly using email
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) {
    return _login(() async => email.trim(), password, byUsername: false);
  }

  // Signs in strictly using username
  Future<bool> loginWithUsername({
    required String username,
    required String password,
  }) {
    return _login(
      () => _authModel.emailForUsername(username),
      password,
      byUsername: true,
    );
  }

  Future<bool> _login(
    Future<String?> Function() resolveEmail,
    String password, {
    required bool byUsername,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    _errorType = null;
    _accountEmail = null;

    try {
      final email = await resolveEmail();
      if (email == null) {
        _errorType = LoginErrorType.noAccount;
        _errorMessage = appL10n.noAccountFoundWithThisUsername;
        return false;
      }
      _accountEmail = email;

      final response = await _authModel.signInWithEmail(
        email: email,
        password: password,
      );
      return response.user != null;
    } on AuthException catch (e) {
      _setAuthError(e, byUsername: byUsername);
      return false;
    } catch (e) {
      debugPrint('Login failed: $e');
      _errorType = LoginErrorType.other;
      _errorMessage = isNetworkError(e)
          ? kNetworkErrorMessage
          : appL10n.unableToLogInPleaseTry;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setAuthError(AuthException e, {required bool byUsername}) {
    final message = e.message.toLowerCase();
    if (e.code == 'email_not_confirmed' ||
        message.contains('email not confirmed')) {
      _errorType = LoginErrorType.emailNotConfirmed;
      _errorMessage = appL10n.pleaseVerifyYourEmailFirst;
    } else if (e.code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      _errorType = LoginErrorType.wrongCredentials;
      _errorMessage = byUsername
          ? appL10n.incorrectUsernameOrPassword
          : appL10n.incorrectEmailOrPassword;
    } else if (e.code == 'user_banned' || message.contains('banned')) {
      // Suspended from the admin dashboard.
      _errorType = LoginErrorType.suspended;
      _errorMessage = appL10n.accountSuspended;
    } else if (isNetworkError(e)) {
      _errorType = LoginErrorType.other;
      _errorMessage = kNetworkErrorMessage;
    } else if (isRateLimited(e)) {
      _errorType = LoginErrorType.other;
      _errorMessage = kRateLimitMessage;
    } else {
      debugPrint('Login auth error: ${e.code} ${e.message}');
      _errorType = LoginErrorType.other;
      _errorMessage = appL10n.unableToLogInPleaseTry;
    }
  }

  // Opens onboarding before account registration.
  void onSignUp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingView()),
    );
  }

  void goBack(BuildContext context) {
    Navigator.pop(context);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
