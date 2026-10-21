import 'dart:io';

import 'package:flutter/foundation.dart'
    show consolidateHttpClientResponseBytes;
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/l10n.dart';
import '../utils/photo_cropper.dart';
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

    final croppedPath = await _crop(picked.path);
    if (croppedPath == null) return const AvatarUpdateResult(picked: false);

    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'me';
    final extension = croppedPath.split('.').last;

    final documentsDir = await getApplicationDocumentsDirectory();
    final localFile = await File(croppedPath)
        .copy('${documentsDir.path}/avatar_$userId.$extension');

    final avatarUrl = await _upload(userId, localFile);

    await _profileModel.updateProfile({
      'avatar_local_path': localFile.path,
      'avatar_url': ?avatarUrl,
    });

    return AvatarUpdateResult(
      picked: true,
      warning: avatarUrl == null
          ? appL10n.savedOnThisDeviceCloudPhoto
          : null,
    );
  }

  // Picks a photo for an edit form without changing the saved profile.
  // Keeps the uncropped original too, so the photo can be adjusted again.
  static Future<({String cropped, String source})?> pickDraft() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final source = await _copyToDocuments(picked.path, 'src_draft');
    final cropped = await cropDraft(source);
    if (cropped == null) {
      await discardSourceDraft(source);
      return null;
    }
    return (cropped: cropped, source: source);
  }

  // Opens Move and Scale on [sourcePath]. Returns a new draft, or null if
  // the user cancels.
  static Future<String?> cropDraft(String sourcePath) async {
    final croppedPath = await _crop(sourcePath);
    if (croppedPath == null) return null;
    return _copyToDocuments(croppedPath, 'draft');
  }

  static Future<String> _copyToDocuments(String path, String kind) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'me';
    final extension = path.split('.').last;
    final documentsDir = await getApplicationDocumentsDirectory();
    final copyPath =
        '${documentsDir.path}/avatar_${userId}_${kind}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    return (await File(path).copy(copyPath)).path;
  }

  // Where the uncropped original of the saved photo is kept on this device.
  static Future<String> _savedSourcePath() async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'me';
    final documentsDir = await getApplicationDocumentsDirectory();
    return '${documentsDir.path}/avatar_${userId}_source';
  }

  // What to start from when adjusting: the uncropped original if this phone
  // has it, otherwise the current photo itself.
  static Future<String?> adjustableSource(Map<String, dynamic> profile) async {
    final saved = await _savedSourcePath();
    if (File(saved).existsSync()) return saved;

    final localPath = (profile['avatar_local_path'] as String?)?.trim();
    if (localPath != null && File(localPath).existsSync()) return localPath;

    final url = (profile['avatar_url'] as String?)?.trim();
    if (url == null || url.isEmpty) return null;
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);
      final file = File(
        '${(await getTemporaryDirectory()).path}/avatar_download.jpg',
      );
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  // Keeps the original of a photo that was just saved.
  static Future<void> saveSource(String sourcePath) async {
    final saved = await _savedSourcePath();
    if (sourcePath == saved) return;
    await File(sourcePath).copy(saved);
    await discardSourceDraft(sourcePath);
  }

  // Deletes an unsaved original. Never touches the saved one.
  static Future<void> discardSourceDraft(String? path) async {
    if (path == null || !path.contains('_src_draft_')) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
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

    final avatarUrl = await _upload(userId, localFile);
    if (await draftFile.exists()) await draftFile.delete();
    return {'avatar_local_path': localFile.path, 'avatar_url': ?avatarUrl};
  }

  static Future<String?> _crop(String path) => cropPhoto(
    path,
    circle: true,
    maxWidth: 1024,
  );

  // Uploads to avatars/<userId>/avatar.<ext> and returns its public URL, or
  // null when the upload fails (the local copy still shows on this device).
  static Future<String?> _upload(String userId, File file) async {
    final extension = file.path.split('.').last.toLowerCase();
    final storagePath = '$userId/avatar.$extension';
    try {
      final storage = Supabase.instance.client.storage.from('avatars');
      await storage.upload(
        storagePath,
        file,
        fileOptions: const FileOptions(upsert: true),
      );
      // The path never changes, so add a version or others keep seeing the
      // old cached photo.
      final url = storage.getPublicUrl(storagePath);
      return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
    } catch (error) {
      debugPrint('Avatar upload failed: $error');
      return null;
    }
  }

  // Photos picked before cloud storage worked only exist on that phone.
  // Uploads them once so other users can see them too.
  static Future<String?> uploadLocalIfMissing(
    Map<String, dynamic> profile,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final url = (profile['avatar_url'] as String?)?.trim();
    final localPath = (profile['avatar_local_path'] as String?)?.trim();
    if (userId == null ||
        (url != null && url.isNotEmpty) ||
        localPath == null ||
        !File(localPath).existsSync()) {
      return null;
    }
    final avatarUrl = await _upload(userId, File(localPath));
    if (avatarUrl != null) {
      await _profileModel.updateProfile({'avatar_url': avatarUrl});
    }
    return avatarUrl;
  }

  static Future<void> discardDraft(String? draftPath) async {
    if (draftPath == null) return;
    final file = File(draftPath);
    if (await file.exists()) await file.delete();
  }

  // Deletes the local copy, best-effort clears the cloud copy, and clears
  // the profile's avatar fields so the UI falls back to the default icon.
  static Future<void> removePhoto(Map<String, dynamic> metadata) async {
    final source = File(await _savedSourcePath());
    if (await source.exists()) await source.delete();

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
        // The header photo lives in the same folder; leave it alone.
        final paths = objects
            .where((o) => !o.name.startsWith('header.'))
            .map((o) => '$userId/${o.name}')
            .toList();
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
