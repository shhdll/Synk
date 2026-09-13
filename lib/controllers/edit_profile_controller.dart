import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ImageProvider;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_model.dart';
import '../models/avatar_uploader.dart';

class EditProfileController extends ChangeNotifier {
  EditProfileController({AuthModel? authModel})
    : _authModel = authModel ?? AuthModel();

  final AuthModel _authModel;

  bool _isUploadingPhoto = false;
  bool get isUploadingPhoto => _isUploadingPhoto;

  Map<String, dynamic> get metadata =>
      Supabase.instance.client.auth.currentUser?.userMetadata ?? {};

  String get email => Supabase.instance.client.auth.currentUser?.email ?? '';

  ImageProvider? get avatarImage => AvatarUploader.imageFor(metadata);

  // Picks a new photo and saves it. Returns a message to show the user
  // (e.g. when the cloud upload fell back to local-only), or null.
  Future<String?> changePhoto() async {
    _isUploadingPhoto = true;
    notifyListeners();

    String? message;
    try {
      final result = await AvatarUploader.pickAndSave();
      message = result.warning;
    } catch (_) {
      message = 'Unable to update your photo. Please try again.';
    } finally {
      _isUploadingPhoto = false;
      notifyListeners();
    }
    return message;
  }

  Future<void> updateName(String value) async {
    await _authModel.updateMetadata({'full_name': value});
    notifyListeners();
  }

  Future<void> updateBio(String value) async {
    await _authModel.updateMetadata({'bio': value});
    notifyListeners();
  }

  // Requests an email change when the value actually changed. Supabase
  // emails the new address a confirmation link before it takes effect, so
  // [email] keeps returning the old address until that's confirmed.
  Future<void> updateEmail(String value) async {
    if (value.trim() == email) return;
    await _authModel.updateEmail(value.trim());
    notifyListeners();
  }
}
