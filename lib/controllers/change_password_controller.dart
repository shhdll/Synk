import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';
import '../l10n/l10n.dart';
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
      return appL10n.enterYourCurrentPassword;
    }
    return null;
  }

  String? validateNewPassword(String? value, String currentPassword) {
    final error = AuthConstants.validatePassword(value);
    if (error != null) {
      return error;
    }
    if (value == currentPassword) {
      return appL10n.newPasswordMustBeDifferentFrom;
    }
    return null;
  }

  String? validateConfirmPassword(String? value, String newPassword) {
    final confirm = value ?? '';
    if (confirm.isEmpty) {
      return appL10n.pleaseConfirmYourNewPassword;
    }
    if (confirm != newPassword) {
      return appL10n.passwordsDoNotMatch;
    }
    return null;
  }

  // Verifies the current password, then sets the new one.
  // Returns true on success; otherwise errorMessage/errorField are set.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Keep this rule at the controller boundary as well as in the form
    // validator so every caller gets the same protection.
    if (newPassword == currentPassword) {
      _setError(
        appL10n.newPasswordMustBeDifferentFrom,
        ChangePasswordErrorField.newPassword,
      );
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      try {
        await _authModel.verifyCurrentPassword(currentPassword);
      } on AuthException catch (e) {
        if (e is AuthSessionMissingException) rethrow;
        _setError(
          appL10n.currentPasswordIsIncorrect,
          ChangePasswordErrorField.current,
        );
        return false;
      }

      await _authModel.updatePassword(newPassword);
      return true;
    } on AuthWeakPasswordException {
      _setError(
        appL10n.passwordIsTooWeakPleaseChoose,
        ChangePasswordErrorField.newPassword,
      );
      return false;
    } on AuthSessionMissingException {
      _setError(
        appL10n.yourSessionHasExpiredPleaseLog,
        ChangePasswordErrorField.general,
      );
      return false;
    } on AuthException catch (e) {
      if (_isSamePasswordError(e)) {
        _setError(
          appL10n.newPasswordMustBeDifferentFrom,
          ChangePasswordErrorField.newPassword,
        );
      } else {
        _setError(
          appL10n.couldntUpdateYourPasswordPleaseTry,
          ChangePasswordErrorField.general,
        );
      }
      return false;
    } catch (_) {
      _setError(
        appL10n.couldntUpdateYourPasswordCheckYour,
        ChangePasswordErrorField.general,
      );
      return false;
    } finally {
      _setLoading(false);
    }
  }

  bool _isSamePasswordError(AuthException e) {
    final msg = e.message.toLowerCase();
    return e.code == 'same_password' ||
        msg.contains('same password') ||
        msg.contains('different from the old') ||
        msg.contains('must be different from your current');
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
