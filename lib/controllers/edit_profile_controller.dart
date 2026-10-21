import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show FileImage, ImageProvider, NetworkImage;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/auth_constants.dart';
import '../l10n/l10n.dart';
import '../models/auth_model.dart';
import '../models/avatar_uploader.dart';
import '../models/header_uploader.dart';
import '../models/profile_header.dart';
import '../models/user_profile_model.dart';
import '../utils/auth_errors.dart';

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
  String? _draftAvatarPath;
  // Uncropped photo the draft was cut from, for adjusting again.
  String? _draftSourcePath;
  bool _removeAvatarDraft = false;

  // Header: a preset color, or a photo that replaces it.
  String _originalHeaderStyle = ProfileHeaders.defaultId;
  String _headerStyle = ProfileHeaders.defaultId;
  String? _draftHeaderPath;
  String? _draftHeaderSource;
  bool _removeHeaderPhoto = false;

  String get name => _name;
  String get username => _username;
  String get bio => _bio;
  int? get age => _age;
  String get gender => _gender;

  String get email {
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  String? get newEmail {
    final pending = Supabase.instance.client.auth.currentUser?.newEmail;
    if (pending == null || pending.isEmpty) return null;
    if (AuthModel.isEmailChangeCancelled(pending)) return null;
    return pending;
  }

  bool get hasPendingEmailChange {
    final pending = newEmail;
    return pending != null && pending.isNotEmpty;
  }

  String get draftEmail => _email;

  ImageProvider? get avatarImage {
    if (_removeAvatarDraft) return null;
    if (_draftAvatarPath != null) {
      return AvatarUploader.imageForPath(_draftAvatarPath!);
    }
    return AvatarUploader.imageFor(_profile);
  }

  String get headerStyle => _headerStyle;

  String? get _savedHeaderUrl {
    final url = (_profile['header_url'] as String?)?.trim();
    return url == null || url.isEmpty ? null : url;
  }

  // The header photo to show, or null for the preset color.
  ImageProvider? get headerImage {
    final draft = _draftHeaderPath;
    if (draft != null) return FileImage(File(draft));
    final url = _savedHeaderUrl;
    if (_removeHeaderPhoto || url == null) return null;
    return NetworkImage(url);
  }

  // ---------------------------------------------------------------------------
  // Load profile
  // ---------------------------------------------------------------------------

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      try {
        await Supabase.instance.client.auth.getUser();
      } catch (_) {}

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

      _originalHeaderStyle = ProfileHeaders.styleFor(
        _profile['header_style'] as String?,
      ).id;

      _originalEmail = email;

      // Start draft with saved values.
      _name = _originalName;
      _username = _originalUsername;
      _bio = _originalBio;
      _age = _originalAge;
      _gender = _originalGender;
      _email = _originalEmail;
      _headerStyle = _originalHeaderStyle;
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
      return appL10n.profileUsernameRequired;
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9._]{3,30}$');
    if (!usernameRegex.hasMatch(clean)) {
      return appL10n.usernameMustBe330Characters;
    }

    if (clean != _originalUsername.toLowerCase()) {
      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      if (currentUid != null) {
        try {
          final existing = await Supabase.instance.client
              .from('users')
              .select('id')
              .ilike('username', escapeLike(clean))
              .neq('id', currentUid)
              .maybeSingle();

          if (existing != null) {
            return appL10n.thisUsernameIsAlreadyTaken;
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

  // Picks up an email change confirmed outside the app, without touching
  // the other drafts.
  void syncEmailFromSession() {
    _originalEmail = email;
    _email = _originalEmail;
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
        _email.trim() != _originalEmail ||
        _draftAvatarPath != null ||
        (_removeAvatarDraft &&
            (((_profile['avatar_local_path'] as String?)?.isNotEmpty ??
                    false) ||
                ((_profile['avatar_url'] as String?)?.isNotEmpty ?? false))) ||
        _headerStyle != _originalHeaderStyle ||
        _draftHeaderPath != null ||
        (_removeHeaderPhoto && _savedHeaderUrl != null);
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
            throw AuthException(appL10n.thisUsernameIsAlreadyTaken);
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

      if (_draftAvatarPath != null) {
        profileChanges.addAll(
          await AvatarUploader.saveDraft(_draftAvatarPath!),
        );
      } else if (_removeAvatarDraft) {
        await AvatarUploader.removePhoto(_profile);
        profileChanges.addAll({'avatar_local_path': null, 'avatar_url': null});
      }

      if (_headerStyle != _originalHeaderStyle) {
        profileChanges['header_style'] = _headerStyle;
      }
      if (_draftHeaderPath != null) {
        try {
          profileChanges['header_url'] = await HeaderUploader.upload(
            _draftHeaderPath!,
          );
        } catch (error) {
          debugPrint('Header upload failed: $error');
          throw AuthException(appL10n.couldntUploadYourHeaderPhoto);
        }
      } else if (_removeHeaderPhoto && _savedHeaderUrl != null) {
        await HeaderUploader.removeUploaded();
        profileChanges['header_url'] = null;
      }

      // Update users table.
      await _profileModel.updateProfile(profileChanges);
      await HeaderUploader.discard(_draftHeaderPath);
      await HeaderUploader.discard(_draftHeaderSource);
      _draftHeaderPath = null;
      _draftHeaderSource = null;
      _removeHeaderPhoto = false;
      if (_draftAvatarPath != null) {
        await AvatarUploader.discardDraft(_draftAvatarPath);
        _draftAvatarPath = null;
      }
      if (_draftSourcePath != null) {
        await AvatarUploader.saveSource(_draftSourcePath!);
        _draftSourcePath = null;
      }
      _removeAvatarDraft = false;

      // Email belongs to Supabase Auth.
      if (trimmedEmail.isNotEmpty && trimmedEmail != _originalEmail) {
        if (!AuthConstants.emailRegex.hasMatch(trimmedEmail)) {
          throw AuthException(appL10n.profileEmailInvalid);
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
      _originalHeaderStyle = _headerStyle;

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
      final picked = await AvatarUploader.pickDraft();
      if (picked != null) {
        await AvatarUploader.discardDraft(_draftAvatarPath);
        await AvatarUploader.discardSourceDraft(_draftSourcePath);
        _draftAvatarPath = picked.cropped;
        _draftSourcePath = picked.source;
        _removeAvatarDraft = false;
      }
    } catch (_) {
      message = appL10n.unableToUpdateYourPhotoPlease;
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }

    return message;
  }

  // Re-opens Move and Scale on the current photo.
  Future<String?> adjustPhoto() async {
    _isUploadingPhoto = true;
    notifyListeners();

    String? message;

    try {
      final source =
          _draftSourcePath ?? await AvatarUploader.adjustableSource(_profile);
      if (source == null) {
        message = appL10n.couldntLoadYourPhotoPleaseTry;
      } else {
        final cropped = await AvatarUploader.cropDraft(source);
        if (cropped != null) {
          await AvatarUploader.discardDraft(_draftAvatarPath);
          _draftAvatarPath = cropped;
          _draftSourcePath = source;
          _removeAvatarDraft = false;
        }
      }
    } catch (_) {
      message = appL10n.unableToAdjustYourPhotoPlease;
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
      await AvatarUploader.discardDraft(_draftAvatarPath);
      await AvatarUploader.discardSourceDraft(_draftSourcePath);
      _draftAvatarPath = null;
      _draftSourcePath = null;
      _removeAvatarDraft = true;
    } catch (_) {
      message = appL10n.unableToRemoveYourPhotoPlease;
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }

    return message;
  }

  Future<void> discardPhotoChanges() async {
    await AvatarUploader.discardDraft(_draftAvatarPath);
    await AvatarUploader.discardSourceDraft(_draftSourcePath);
    _draftAvatarPath = null;
    _draftSourcePath = null;
    _removeAvatarDraft = false;
    await _discardHeaderDraft();
    _headerStyle = _originalHeaderStyle;
    _removeHeaderPhoto = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  // Picking a color replaces any header photo.
  Future<void> selectHeaderStyle(String id) async {
    await _discardHeaderDraft();
    _headerStyle = id;
    _removeHeaderPhoto = true;
    notifyListeners();
  }

  Future<String?> changeHeaderPhoto() async {
    _isUploadingPhoto = true;
    notifyListeners();

    String? message;
    try {
      final picked = await HeaderUploader.pickDraft();
      if (picked != null) {
        await _discardHeaderDraft();
        _draftHeaderPath = picked.cropped;
        _draftHeaderSource = picked.source;
        _removeHeaderPhoto = false;
      }
    } catch (_) {
      message = appL10n.unableToUpdateYourPhotoPlease;
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
    return message;
  }

  // Re-opens Move and Scale on the header photo.
  Future<String?> adjustHeaderPhoto() async {
    _isUploadingPhoto = true;
    notifyListeners();

    String? message;
    try {
      final source =
          _draftHeaderSource ??
          await HeaderUploader.downloadForAdjusting(_savedHeaderUrl);
      if (source == null) {
        message = appL10n.couldntLoadYourPhotoPleaseTry;
      } else {
        final cropped = await HeaderUploader.cropDraft(source);
        if (cropped != null) {
          await HeaderUploader.discard(_draftHeaderPath);
          _draftHeaderPath = cropped;
          _draftHeaderSource = source;
          _removeHeaderPhoto = false;
        } else if (_draftHeaderSource == null) {
          await HeaderUploader.discard(source);
        }
      }
    } catch (_) {
      message = appL10n.unableToAdjustYourPhotoPlease;
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
    return message;
  }

  Future<void> removeHeaderPhoto() async {
    await _discardHeaderDraft();
    _removeHeaderPhoto = true;
    notifyListeners();
  }

  Future<void> _discardHeaderDraft() async {
    await HeaderUploader.discard(_draftHeaderPath);
    await HeaderUploader.discard(_draftHeaderSource);
    _draftHeaderPath = null;
    _draftHeaderSource = null;
  }
}
