import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_profile_model.dart';

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
  static final UserProfileModel _profileModel = UserProfileModel();

  // Default avatar images based on gender.
  static const ImageProvider defaultFemaleImage = AssetImage(
    'assets/avatar_female.png',
  );

  static const ImageProvider defaultMaleImage = AssetImage(
    'assets/avatar_male.png',
  );

  static const ImageProvider defaultImage = AssetImage(
    'assets/avatar_female.png',
  );

  static ImageProvider defaultImageForGender(String? gender) {
    final clean = gender?.trim().toLowerCase();
    if (clean == 'male') {
      return defaultMaleImage;
    }
    return defaultFemaleImage;
  }

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
    final localFile = await File(picked.path)
        .copy('${documentsDir.path}/avatar_$userId.$extension');

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

    await _profileModel.updateProfile({
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

  // Picks a photo for an edit form without changing the saved profile.
  static Future<String?> pickDraft() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'me';
    final extension = picked.path.split('.').last;
    final documentsDir = await getApplicationDocumentsDirectory();
    final draftPath =
        '${documentsDir.path}/avatar_${userId}_draft_${DateTime.now().microsecondsSinceEpoch}.$extension';
    return (await File(picked.path).copy(draftPath)).path;
  }

  // Commits a previously picked draft photo and returns its profile metadata.
  static Future<Map<String, dynamic>> saveDraft(String draftPath) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'me';
    final draftFile = File(draftPath);
    final extension = draftPath.split('.').last;
    final documentsDir = await getApplicationDocumentsDirectory();
    final localFile = await draftFile.copy(
      '${documentsDir.path}/avatar_$userId.$extension',
    );

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
      // Local avatar still works when cloud storage is unavailable.
    }
    if (await draftFile.exists()) await draftFile.delete();
    return {'avatar_local_path': localFile.path, 'avatar_url': ?avatarUrl};
  }

  static Future<void> discardDraft(String? draftPath) async {
    if (draftPath == null) return;
    final file = File(draftPath);
    if (await file.exists()) await file.delete();
  }

  // Deletes the local copy, best-effort clears the cloud copy, and clears
  // the profile's avatar fields so the UI falls back to the default icon.
  static Future<void> removePhoto(Map<String, dynamic> metadata) async {
    final localPath = (metadata['avatar_local_path'] as String?)?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {
          // Fine either way — the profile fields below are the source of
          // truth for whether an avatar is set.
        }
      }
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final objects = await Supabase.instance.client.storage
            .from('avatars')
            .list(path: userId);
        final paths = objects.map((o) => '$userId/${o.name}').toList();
        if (paths.isNotEmpty) {
          await Supabase.instance.client.storage.from('avatars').remove(paths);
        }
      } catch (_) {
        // No 'avatars' bucket, no permission, or nothing to remove.
      }
    }

    await _profileModel.updateProfile({
      'avatar_local_path': null,
      'avatar_url': null,
    });
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

  static ImageProvider? imageForPath(String path) {
    final file = File(path);
    return file.existsSync() ? FileImage(file) : null;
  }
}
