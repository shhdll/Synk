import 'dart:io';

import 'package:flutter/foundation.dart'
    show consolidateHttpClientResponseBytes, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/photo_cropper.dart';

// Picks, crops and uploads the profile header photo. Stored next to the
// avatar as avatars/<userId>/header.<ext>.
class HeaderUploader {
  HeaderUploader._();

  // Width to height, same as the header on the profile page.
  static const double aspectRatio = 2.6;

  static final ImagePicker _picker = ImagePicker();

  // Picks and crops a photo without saving it. Keeps the uncropped original
  // so it can be adjusted again.
  static Future<({String cropped, String source})?> pickDraft() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final source = await _copyToTemp(picked.path, 'source');
    final cropped = await cropDraft(source);
    if (cropped == null) {
      await discard(source);
      return null;
    }
    return (cropped: cropped, source: source);
  }

  // Opens Move and Scale on [sourcePath]. Null if the user cancels.
  static Future<String?> cropDraft(String sourcePath) async {
    final croppedPath = await cropPhoto(
      sourcePath,
      aspectRatio: aspectRatio,
      maxWidth: 1600,
    );
    if (croppedPath == null) return null;
    return _copyToTemp(croppedPath, 'draft');
  }

  // The saved header photo, downloaded so it can be adjusted.
  static Future<String?> downloadForAdjusting(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      if (response.statusCode != 200) return null;
      final bytes = await consolidateHttpClientResponseBytes(response);
      final file = File(
        '${(await getTemporaryDirectory()).path}/header_download_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  // Uploads the draft and returns its public URL. Throws when it fails.
  static Future<String> upload(String draftPath) async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final extension = draftPath.split('.').last.toLowerCase();
    final storagePath = '$userId/header.$extension';
    final storage = Supabase.instance.client.storage.from('avatars');
    await storage.upload(
      storagePath,
      File(draftPath),
      fileOptions: const FileOptions(upsert: true),
    );
    // Same path every time, so add a version or others see the cached one.
    final url = storage.getPublicUrl(storagePath);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  // Best-effort delete of the uploaded header photo.
  static Future<void> removeUploaded() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final storage = Supabase.instance.client.storage.from('avatars');
      final objects = await storage.list(path: userId);
      final paths = objects
          .where((o) => o.name.startsWith('header.'))
          .map((o) => '$userId/${o.name}')
          .toList();
      if (paths.isNotEmpty) await storage.remove(paths);
    } catch (error) {
      debugPrint('Header photo removal failed: $error');
    }
  }

  static Future<void> discard(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Future<String> _copyToTemp(String path, String kind) async {
    final extension = path.split('.').last;
    final dir = await getTemporaryDirectory();
    final copyPath =
        '${dir.path}/header_${kind}_${DateTime.now().microsecondsSinceEpoch}.$extension';
    return (await File(path).copy(copyPath)).path;
  }
}
