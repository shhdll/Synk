import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ImageProvider;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';
import '../models/avatar_uploader.dart';
import '../models/user_profile_model.dart';

class EditProfileController extends ChangeNotifier {
  EditProfileController({
    AuthModel? authModel,
    UserProfileModel? profileModel,
  })  : _authModel = authModel ?? AuthModel(),
        _profileModel = profileModel ?? UserProfileModel();

  final AuthModel _authModel;
  final UserProfileModel _profileModel;

  Map<String, dynamic> _profile = {};

  Map<String, dynamic> get profile => _profile;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isUploadingPhoto = false;
  bool get isUploadingPhoto => _isUploadingPhoto;

  // ---------------------------------------------------------------------------
  // Original saved values
  // ---------------------------------------------------------------------------

  String _originalName = '';
  String _originalBio = '';
  int? _originalAge;
  String _originalGender = '';
  String _originalEmail = '';

  // ---------------------------------------------------------------------------
  // Draft values
  // ---------------------------------------------------------------------------

  String _name = '';
  String _bio = '';
  int? _age;
  String _gender = '';
  String _email = '';

  String get name => _name;
  String get bio => _bio;
  int? get age => _age;
  String get gender => _gender;

  String get email {
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  String get draftEmail => _email;

  ImageProvider? get avatarImage {
    return AvatarUploader.imageFor(_profile);
  }

  // ---------------------------------------------------------------------------
  // Load profile
  // ---------------------------------------------------------------------------

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      _profile = await _profileModel.fetchProfile();

      _originalName =
          (_profile['full_name'] as String?)?.trim() ?? '';

      _originalBio =
          (_profile['bio'] as String?)?.trim() ?? '';

      _originalAge = _parseAge(_profile['age']);

      _originalGender =
          (_profile['gender'] as String?)?.trim() ?? '';

      _originalEmail = email;

      // Start draft with saved values.
      _name = _originalName;
      _bio = _originalBio;
      _age = _originalAge;
      _gender = _originalGender;
      _email = _originalEmail;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int? _parseAge(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  // ---------------------------------------------------------------------------
  // Draft setters
  // ---------------------------------------------------------------------------

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void setBio(String value) {
    _bio = value;
    notifyListeners();
  }

  void setAge(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      _age = null;
    } else {
      _age = int.tryParse(trimmed);
    }

    notifyListeners();
  }

  void setGender(String value) {
    _gender = value;
    notifyListeners();
  }

  void setEmail(String value) {
    _email = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Unsaved changes
  // ---------------------------------------------------------------------------

  bool get hasUnsavedChanges {
    return _name.trim() != _originalName ||
        _bio.trim() != _originalBio ||
        _age != _originalAge ||
        _gender.trim() != _originalGender ||
        _email.trim() != _originalEmail;
  }

  // ---------------------------------------------------------------------------
  // Save everything
  // ---------------------------------------------------------------------------

  Future<void> saveChanges() async {
    if (_isSaving) {
      return;
    }

    _isSaving = true;
    notifyListeners();

    try {
      final trimmedName = _name.trim();
      final trimmedBio = _bio.trim();
      final trimmedGender = _gender.trim();
      final trimmedEmail = _email.trim();

      final profileChanges = <String, dynamic>{
        'full_name': trimmedName,
        'bio': trimmedBio,
        'age': _age,
        'gender':
            trimmedGender.isEmpty ? null : trimmedGender,
      };

      // Update users table.
      await _profileModel.updateProfile(profileChanges);

      // Email belongs to Supabase Auth.
      if (trimmedEmail.isNotEmpty &&
          trimmedEmail != _originalEmail) {
        await _authModel.updateEmail(trimmedEmail);
      }

      // Update local profile immediately.
      _profile = {
        ..._profile,
        ...profileChanges,
      };

      // Update original values.
      _originalName = trimmedName;
      _originalBio = trimmedBio;
      _originalAge = _age;
      _originalGender = trimmedGender;
      _originalEmail = trimmedEmail;

      // Keep draft values synchronized.
      _name = trimmedName;
      _bio = trimmedBio;
      _gender = trimmedGender;
      _email = trimmedEmail;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Photo
  // ---------------------------------------------------------------------------

  Future<String?> changePhoto() async {
    _isUploadingPhoto = true;
    notifyListeners();

    String? message;

    try {
      final result = await AvatarUploader.pickAndSave();

      message = result.warning;

      _profile = await _profileModel.fetchProfile();
    } catch (_) {
      message =
          'Unable to update your photo. Please try again.';
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }

    return message;
  }

  Future<String?> removePhoto() async {
    _isUploadingPhoto = true;
    notifyListeners();

    String? message;

    try {
      await AvatarUploader.removePhoto(_profile);

      _profile = await _profileModel.fetchProfile();
    } catch (_) {
      message =
          'Unable to remove your photo. Please try again.';
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }

    return message;
  }
}