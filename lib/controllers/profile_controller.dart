import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({AuthModel? authModel})
    : _authModel = authModel ?? AuthModel();

  final AuthModel _authModel;

  bool _isLoggingOut = false;
  String? _errorMessage;

  bool get isLoggingOut => _isLoggingOut;
  String? get errorMessage => _errorMessage;

  Map<String, dynamic> get metadata =>
      Supabase.instance.client.auth.currentUser?.userMetadata ?? {};

  String? get email => Supabase.instance.client.auth.currentUser?.email;

  // Signs the current user out and reports whether it succeeded.
  Future<bool> logout() async {
    _setLoggingOut(true);
    _errorMessage = null;

    try {
      await _authModel.signOut();
      return true;
    } catch (_) {
      _errorMessage = 'Unable to log out. Please try again.';
      return false;
    } finally {
      _setLoggingOut(false);
    }
  }

  void _setLoggingOut(bool value) {
    _isLoggingOut = value;
    notifyListeners();
  }
}
