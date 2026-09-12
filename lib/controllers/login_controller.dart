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

  // Attempts to sign in and returns true when authentication succeeds.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final response = await _authModel.signIn(
        email: email,
        password: password,
      );

      return response.user != null;
    } on AuthException {
      _errorMessage = 'Invalid email or password.';
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
      MaterialPageRoute(
        builder: (context) => const OnboardingView(),
      ),
    );
  }

  void goBack(BuildContext context) {
  Navigator.pop(context);
}

  // Signs out the current user.
  Future<bool> logout() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authModel.signOut();
      return true;
    } catch (_) {
      _errorMessage = 'Unable to log out. Please try again.';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}