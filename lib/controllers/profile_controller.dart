import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';
import '../models/user_profile_model.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({UserProfileModel? profileModel})
    : _profileModel = profileModel ?? UserProfileModel();

  final UserProfileModel _profileModel;

  Map<String, dynamic> _profile = {};
  Map<String, dynamic> get profile => _profile;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? get email => Supabase.instance.client.auth.currentUser?.email;

  String? get newEmail {
    final pending = Supabase.instance.client.auth.currentUser?.newEmail;
    if (pending == null || pending.isEmpty) return null;
    if (AuthModel.isEmailChangeCancelled(pending)) return null;
    return pending;
  }

  bool get hasPendingEmailChange => newEmail != null && newEmail!.isNotEmpty;

  // Reads username from profile map or auth metadata
  String? get username {
    final name = _profile['username'] as String?;
    if (name != null && name.isNotEmpty) return name;
    return Supabase.instance.client.auth.currentUser?.userMetadata?['username']
        as String?;
  }

  // Loads the current user's row from the public "users" table.
  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    _profile = await _profileModel.fetchProfile();

    _isLoading = false;
    notifyListeners();
  }

  /// Updates the username after format validation and uniqueness check.
  /// Returns null on success, or an error message string on failure.
  Future<String?> updateUsername(String newUsername) async {
    final cleanUsername = newUsername.trim().toLowerCase();

    final usernameRegex = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
    if (cleanUsername.isEmpty) {
      return 'Username cannot be empty';
    }
    if (!usernameRegex.hasMatch(cleanUsername)) {
      return 'Username must be 3–30 characters and can only include letters, numbers, dots, and underscores.';
    }

    if (cleanUsername == username?.toLowerCase()) {
      return null; // No change
    }

    final isTaken = await _profileModel.isUsernameTaken(cleanUsername);
    if (isTaken) {
      return 'This username is already taken';
    }

    await _profileModel.updateProfile({'username': cleanUsername});
    _profile = {..._profile, 'username': cleanUsername};
    notifyListeners();
    return null;
  }

  Future<void> updateBio(String value) async {
    final cleanBio = value.trim();
    await _profileModel.updateProfile({'bio': cleanBio});
    _profile = {..._profile, 'bio': cleanBio};
    notifyListeners();
  }

  Future<void> updateActivityType(String value) async {
    await _profileModel.updateProfile({'activity_type': value});
    _profile = {..._profile, 'activity_type': value};
    notifyListeners();
  }

  Future<void> updateLocationPreference(String value) async {
    await _profileModel.updateProfile({'location_preference': value});
    _profile = {..._profile, 'location_preference': value};
    notifyListeners();
  }
}
