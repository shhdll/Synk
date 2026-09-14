import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ImageProvider;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';
import '../models/avatar_uploader.dart';
import '../models/user_profile_model.dart';

class EditProfileController extends ChangeNotifier {
  EditProfileController({AuthModel? authModel, UserProfileModel? profileModel})
    : _authModel = authModel ?? AuthModel(),
      _profileModel = profileModel ?? UserProfileModel();

  final AuthModel _authModel;
  final UserProfileModel _profileModel;

  Map<String, dynamic> _profile = {};
  Map<String, dynamic> get profile => _profile;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isUploadingPhoto = false;
  bool get isUploadingPhoto => _isUploadingPhoto;

  String get email => Supabase.instance.client.auth.currentUser?.email ?? '';

  ImageProvider? get avatarImage => AvatarUploader.imageFor(_profile);

  // Loads the current user's row from the public "users" table.
  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    _profile = await _profileModel.fetchProfile();

    _isLoading = false;
    notifyListeners();
  }

  // Picks a new photo and saves it. Returns a message to show the user
  // (e.g. when the cloud upload fell back to local-only), or null.
  Future<String?> changePhoto() async {
    _isUploadingPhoto = true;
    notifyListeners();

    String? message;
    try {
      final result = await AvatarUploader.pickAndSave();
      message = result.warning;
      _profile = await _profileModel.fetchProfile();
    } catch (_) {
      message = 'Unable to update your photo. Please try again.';
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
    return message;
  }

  // Removes the current photo and returns a message to show the user on
  // failure, or null on success.
  Future<String?> removePhoto() async {
    _isUploadingPhoto = true;
    notifyListeners();

    String? message;
    try {
      await AvatarUploader.removePhoto(_profile);
      _profile = await _profileModel.fetchProfile();
    } catch (_) {
      message = 'Unable to remove your photo. Please try again.';
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
    return message;
  }

  Future<void> updateName(String value) async {
    await _profileModel.updateProfile({'full_name': value});
    _profile = {..._profile, 'full_name': value};
    notifyListeners();
  }

  Future<void> updateBio(String value) async {
    await _profileModel.updateProfile({'bio': value});
    _profile = {..._profile, 'bio': value};
    notifyListeners();
  }

  Future<void> updateAge(int value) async {
    await _profileModel.updateProfile({'age': value});
    _profile = {..._profile, 'age': value};
    notifyListeners();
  }

  // Requests an email change when the value actually changed. Supabase
  // emails the new address a confirmation link before it takes effect, so
  // [email] keeps returning the old address until that's confirmed. Note
  // this only updates Supabase Auth — the "users" table's email column
  // (set once at signup) isn't kept in sync with later changes.
  Future<void> updateEmail(String value) async {
    if (value.trim() == email) return;
    await _authModel.updateEmail(value.trim());
    notifyListeners();
  }
}
