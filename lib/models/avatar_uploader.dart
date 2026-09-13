import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_model.dart';

class AvatarUpdateResult {
  const AvatarUpdateResult({required this.picked, this.warning});

  final bool picked;
  final String? warning;
}

// Picks a photo from the device, keeps a local copy (so it survives app
// restarts even without a backend), and best-effort uploads it to a
// Supabase Storage bucket named 'avatars'. Shared by every screen that
// lets the user change their profile photo.
class AvatarUploader {
  AvatarUploader._();

  static final ImagePicker _picker = ImagePicker();
  static final AuthModel _authModel = AuthModel();

  static Future<AvatarUpdateResult> pickAndSave() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return const AvatarUpdateResult(picked: false);

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'me';
    final extension = picked.path.split('.').last;

    final documentsDir = await getApplicationDocumentsDirectory();
    final localFile = await File(
      picked.path,
    ).copy('${documentsDir.path}/avatar_$userId.$extension');

    String? avatarUrl;
    try {
      final storagePath = '$userId/avatar.$extension';
      await Supabase.instance.client.storage
          .from('avatars')
          .upload(
            storagePath,
            localFile,
            fileOptions: const FileOptions(upsert: true),
          );
      avatarUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(storagePath);
    } catch (_) {
      // No 'avatars' bucket yet (or no permission) — the local copy above
      // still makes the photo show up on this device.
    }

    await _authModel.updateMetadata({
      'avatar_local_path': localFile.path,
      'avatar_url': ?avatarUrl,
    });

    return AvatarUpdateResult(
      picked: true,
      warning: avatarUrl == null
          ? "Saved on this device (cloud photo storage isn't set up yet)."
          : null,
    );
  }

  static ImageProvider? imageFor(Map<String, dynamic> metadata) {
    final avatarUrl = (metadata['avatar_url'] as String?)?.trim();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return NetworkImage(avatarUrl);
    }
    final localPath = (metadata['avatar_local_path'] as String?)?.trim();
    if (localPath != null && File(localPath).existsSync()) {
      return FileImage(File(localPath));
    }
    return null;
  }
}
