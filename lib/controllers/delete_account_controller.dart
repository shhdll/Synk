import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';
import '../models/auth_model.dart';

class DeleteAccountController extends ChangeNotifier {
  DeleteAccountController({AuthModel? authModel})
    : _authModel = authModel ?? AuthModel();

  final AuthModel _authModel;

  bool _isDeleting = false;
  String? _passwordError;
  String? _errorMessage;

  bool get isDeleting => _isDeleting;
  String? get passwordError => _passwordError;
  String? get errorMessage => _errorMessage;

  void clearPasswordError() {
    if (_passwordError == null) return;
    _passwordError = null;
    notifyListeners();
  }

  // Checks the password before anything is deleted.
  Future<bool> checkPassword(String password) async {
    _passwordError = null;
    _errorMessage = null;
    _setDeleting(true);
    try {
      await _authModel.verifyCurrentPassword(password);
      return true;
    } on AuthException catch (e) {
      if (e is AuthSessionMissingException) {
        _errorMessage = appL10n.somethingWentWrongPleaseTryAgain;
      } else {
        _passwordError = appL10n.currentPasswordIsIncorrect;
      }
      return false;
    } catch (_) {
      _errorMessage = appL10n.somethingWentWrongPleaseTryAgain;
      return false;
    } finally {
      _setDeleting(false);
    }
  }

  Future<bool> deleteAccount() async {
    _errorMessage = null;
    _setDeleting(true);
    try {
      await _authModel.deleteAccount();
      return true;
    } catch (_) {
      _errorMessage = appL10n.couldNotDeleteAccount;
      return false;
    } finally {
      _setDeleting(false);
    }
  }

  void _setDeleting(bool value) {
    _isDeleting = value;
    notifyListeners();
  }
}
