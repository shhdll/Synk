import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';
import '../views/onboarding_view.dart';

class LoginController extends ChangeNotifier {
  LoginController({AuthModel? authModel})
    : _authModel = authModel ?? AuthModel();

  final AuthModel _authModel;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Clear previous error message when user retypes or switches tabs
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // Signs in strictly using email
  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final response = await _authModel.signInWithEmail(
        email: email,
        password: password,
      );

      return response.user != null;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Unable to log in. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Signs in strictly using username
  Future<bool> loginWithUsername({
    required String username,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final response = await _authModel.signInWithUsername(
        username: username,
        password: password,
      );

      return response.user != null;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Unable to log in. Please try again.';
      return false;
    } finally {
      _setLoading(false);
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
