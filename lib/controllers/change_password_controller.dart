import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';
import '../models/auth_model.dart';

/// Which field a change-password error belongs to, so the view can show it
/// under the right input.
enum ChangePasswordErrorField { current, newPassword, general }

class ChangePasswordController extends ChangeNotifier {
  ChangePasswordController({AuthModel? authModel})
    : _authModel = authModel ?? AuthModel();

  final AuthModel _authModel;

  bool _isLoading = false;
  String? _errorMessage;
  ChangePasswordErrorField _errorField = ChangePasswordErrorField.general;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ChangePasswordErrorField get errorField => _errorField;

  String? validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your current password';
    }
    return null;
  }

  String? validateNewPassword(String? value, String currentPassword) {
    final error = AuthConstants.validatePassword(value);
    if (error != null) {
      return error;
    }
    if (value == currentPassword) {
      return 'New password must be different from your current one';
    }
    return null;
  }

  String? validateConfirmPassword(String? value, String newPassword) {
    final confirm = value ?? '';
    if (confirm.isEmpty) {
      return 'Please confirm your new password';
    }
    if (confirm != newPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Verifies the current password, then sets the new one.
  // Returns true on success; otherwise errorMessage/errorField are set.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      try {
        await _authModel.verifyCurrentPassword(currentPassword);
      } on AuthException catch (e) {
        if (e is AuthSessionMissingException) rethrow;
        _setError(
          'Current password is incorrect',
          ChangePasswordErrorField.current,
        );
        return false;
      }

      await _authModel.updatePassword(newPassword);
      return true;
    } on AuthWeakPasswordException {
      _setError(
        'Password is too weak. Please choose a stronger one.',
        ChangePasswordErrorField.newPassword,
      );
      return false;
    } on AuthSessionMissingException {
      _setError(
        'Your session has expired. Please log in again.',
        ChangePasswordErrorField.general,
      );
      return false;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (e.code == 'same_password' || msg.contains('different from the old')) {
        _setError(
          'New password must be different from your current one',
          ChangePasswordErrorField.newPassword,
        );
      } else {
        _setError(
          'Couldn\'t update your password. Please try again.',
          ChangePasswordErrorField.general,
        );
      }
      return false;
    } catch (_) {
      _setError(
        'Couldn\'t update your password. Check your connection and try again.',
        ChangePasswordErrorField.general,
      );
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message, ChangePasswordErrorField field) {
    _errorMessage = message;
    _errorField = field;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
