import 'package:flutter/material.dart';

import '../models/auth_model.dart';
import '../views/welcome_view.dart';

class HomeController extends ChangeNotifier {
  HomeController({AuthModel? authModel}) : _authModel = authModel ?? AuthModel();

  final AuthModel _authModel;

  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Email of the signed-in user, if any.
  String? get userEmail => _authModel.currentUserEmail;

  // Display name of the signed-in user, if any.
  String? get userName => _authModel.currentUserName;

  // Signs the user out and returns to the Welcome screen, clearing the
  // navigation stack so Back cannot return to an authenticated screen.
  Future<void> logout(BuildContext context) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _authModel.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeView()),
        (route) => false,
      );
    } catch (_) {
      _errorMessage = 'Unable to log out. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
