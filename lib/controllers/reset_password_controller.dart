import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';
import '../models/auth_model.dart';

/// Outcome of a password update attempt on the New Password screen.
enum UpdatePasswordResult { success, failure, sessionMissing }

class ResetPasswordController extends ChangeNotifier {
  ResetPasswordController({AuthModel? authModel})
      : _authModel = authModel ?? AuthModel();

  final AuthModel _authModel;

  bool _isLoading = false;
  String? _errorMessage;

  // Forgot Password screen state.
  bool _emailSent = false;
  String _sentToEmail = '';
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get emailSent => _emailSent;
  String get sentToEmail => _sentToEmail;
  int get resendSecondsLeft => _resendSecondsLeft;
  bool get canResend => _resendSecondsLeft == 0 && !_isLoading;



  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Please enter your email';
    }
    if (!AuthConstants.emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < AuthConstants.minPasswordLength) {
      return 'Password must be at least '
          '${AuthConstants.minPasswordLength} characters';
    }
    return null;
  }

  String? validateConfirmPassword(String? value, String password) {
    final confirm = value ?? '';
    if (confirm.isEmpty) {
      return 'Please confirm your password';
    }
    if (confirm != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Live helpers for the inline indicators under the password fields.
  bool meetsMinimumLength(String password) =>
      password.length >= AuthConstants.minPasswordLength;

  bool passwordsMatch(String password, String confirm) =>
      confirm.isNotEmpty && password == confirm;

 
  // Forgot Password: send the reset email
  // ---------------------------------------------------------------------------

  // Requests a reset email. Returns true when the request was accepted.
  // Supabase accepts requests for unknown emails too (no account enumeration),
  Future<bool> sendResetLink(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authModel.sendPasswordResetEmail(email);
      _emailSent = true;
      _sentToEmail = email.trim();
      _startResendCooldown();
      return true;
    } on AuthException catch (e) {
      _errorMessage = _messageForSendError(e);
      return false;
    } catch (_) {
      _errorMessage = 'Couldn\'t send the link. Check your connection and try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sends the link again to the same address once the cooldown has passed.
  Future<bool> resendLink() async {
    if (!canResend) return false;
    return sendResetLink(_sentToEmail);
  }

  // Returns from the "sent" state to the form so the user can fix the email.
  void editEmail() {
    _emailSent = false;
    _errorMessage = null;
    notifyListeners();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendSecondsLeft = AuthConstants.resendCooldownSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsLeft <= 1) {
        _resendSecondsLeft = 0;
        timer.cancel();
      } else {
        _resendSecondsLeft--;
      }
      notifyListeners();
    });
  }

  String _messageForSendError(AuthException e) {
    if (e.code == 'over_email_send_rate_limit' ||
        e.message.toLowerCase().contains('rate limit')) {
      return 'Please wait a moment before requesting another link.';
    }
    return 'Couldn\'t send the link. Check your connection and try again.';
  }


  // New Password: update the password on the recovery session
  

  Future<UpdatePasswordResult> updatePassword(String newPassword) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authModel.updatePassword(newPassword);
      return UpdatePasswordResult.success;
    } on AuthSessionMissingException {
      // No recovery session: the link expired, was already used, or was
      // opened on a different device.
      return UpdatePasswordResult.sessionMissing;
    } on AuthWeakPasswordException {
      _errorMessage = 'Password is too weak. Please use at least '
          '${AuthConstants.minPasswordLength} characters.';
      return UpdatePasswordResult.failure;
    } on AuthException catch (e) {
      _errorMessage = _messageForUpdateError(e);
      return UpdatePasswordResult.failure;
    } catch (_) {
      _errorMessage = 'Couldn\'t update your password. Please try again.';
      return UpdatePasswordResult.failure;
    } finally {
      _setLoading(false);
    }
  }

  String _messageForUpdateError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (e.code == 'same_password' || msg.contains('different from the old')) {
      return 'That\'s your current password. Pick a new one.';
    }
    if (e.code == 'session_not_found' || msg.contains('session')) {
      return 'This link is no longer valid. Please request a new one.';
    }
    return 'Couldn\'t update your password. Please try again.';
  }

  // Ends the recovery session so the user must log in with the new password.
  // Called after a successful update and when the user backs out of the
  // New Password screen.
  Future<void> endRecoverySession() async {
    try {
      await _authModel.signOut();
    } catch (_) {
      // Ignore: the session may already be gone.
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}