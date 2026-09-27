import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ImageProvider;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';
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

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  bool _isUploadingPhoto = false;
  bool get isUploadingPhoto => _isUploadingPhoto;

  // ---------------------------------------------------------------------------
  // Original saved values
  // ---------------------------------------------------------------------------

  String _originalName = '';
  String _originalUsername = '';
  String _originalBio = '';
  int? _originalAge;
  String _originalGender = '';
  String _originalEmail = '';

  // ---------------------------------------------------------------------------
  // Draft values
  // ---------------------------------------------------------------------------

  String _name = '';
  String _username = '';
  String _bio = '';
  int? _age;
  String _gender = '';
  String _email = '';

  String get name => _name;
  String get username => _username;
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

      final rawName = (_profile['full_name'] as String?)?.trim();
      final metaName =
          (Supabase.instance.client.auth.currentUser?.userMetadata?['full_name']
                  as String?)
              ?.trim();
      _originalName = (rawName != null && rawName.isNotEmpty)
          ? rawName
          : (metaName ?? '');

      final rawUsername = (_profile['username'] as String?)?.trim();
      final metaUsername =
          (Supabase.instance.client.auth.currentUser?.userMetadata?['username']
                  as String?)
              ?.trim();
      _originalUsername = (rawUsername != null && rawUsername.isNotEmpty)
          ? rawUsername
          : (metaUsername ?? '');

      _originalBio = (_profile['bio'] as String?)?.trim() ?? '';

      _originalAge = _parseAge(_profile['age']);

      _originalGender = (_profile['gender'] as String?)?.trim() ?? '';

      _originalEmail = email;

      // Start draft with saved values.
      _name = _originalName;
      _username = _originalUsername;
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

  void setUsername(String value) {
    _username = value;
    notifyListeners();
  }

  Future<String?> updateUsername(String newUsername) async {
    final clean = newUsername.trim().replaceAll('@', '').toLowerCase();

    if (clean.isEmpty) {
      return 'Please enter your username.';
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
    if (!usernameRegex.hasMatch(clean)) {
      return 'Username must be 3–30 characters and can only include letters, numbers, dots, and underscores.';
    }

    if (clean != _originalUsername.toLowerCase()) {
      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      if (currentUid != null) {
        try {
          final existing = await Supabase.instance.client
              .from('users')
              .select('id')
              .ilike('username', clean)
              .neq('id', currentUid)
              .maybeSingle();

          if (existing != null) {
            return 'This username is already taken.';
          }
        } catch (_) {
          // If query fails, continue
        }
      }
    }

    _username = clean;
    notifyListeners();
    return null;
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
        _username.trim().replaceAll('@', '') !=
            _originalUsername.replaceAll('@', '') ||
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
      final trimmedUsername = _username
          .trim()
          .replaceAll('@', '')
          .toLowerCase();
      final trimmedBio = _bio.trim();
      final trimmedGender = _gender.trim();
      final trimmedEmail = _email.trim();

      if (trimmedUsername.isNotEmpty &&
          trimmedUsername != _originalUsername.toLowerCase()) {
        final currentUid = Supabase.instance.client.auth.currentUser?.id;
        if (currentUid != null) {
          final existing = await Supabase.instance.client
              .from('users')
              .select('id')
              .ilike('username', trimmedUsername)
              .neq('id', currentUid)
              .maybeSingle();

          if (existing != null) {
            throw const AuthException('This username is already taken.');
          }
        }
      }

      final profileChanges = <String, dynamic>{
        'full_name': trimmedName,
        'username': trimmedUsername.isEmpty ? null : trimmedUsername,
        'bio': trimmedBio,
        'age': _age,
        'gender': trimmedGender.isEmpty ? null : trimmedGender,
      };

      // Update users table.
      await _profileModel.updateProfile(profileChanges);

      // Email belongs to Supabase Auth.
      if (trimmedEmail.isNotEmpty && trimmedEmail != _originalEmail) {
        if (!AuthConstants.emailRegex.hasMatch(trimmedEmail)) {
          throw const AuthException('Please enter a valid email address.');
        }
        await _authModel.updateEmail(trimmedEmail);
      }

      // Update local profile immediately.
      _profile = {..._profile, ...profileChanges};

      // Update original values.
      _originalName = trimmedName;
      _originalUsername = trimmedUsername;
      _originalBio = trimmedBio;
      _originalAge = _age;
      _originalGender = trimmedGender;
      _originalEmail = trimmedEmail;

      // Keep draft values synchronized.
      _name = trimmedName;
      _username = trimmedUsername;
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
      message = 'Unable to update your photo. Please try again.';
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
      message = 'Unable to remove your photo. Please try again.';
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }

    return message;
  }
}