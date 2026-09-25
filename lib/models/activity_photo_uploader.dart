import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/activity_constants.dart';

// Result of uploading an activity photo.
//
// [url] is the public URL to store in `activities.photo_url`, or null when
// the upload failed. [warning] is a message to show the user in that case.
class ActivityPhotoUploadResult {
  const ActivityPhotoUploadResult({this.url, this.warning});

  final String? url;
  final String? warning;

  bool get succeeded => url != null;
}

// Handles the single optional photo attached to an activity.
//
// Photo workflow: the user picks a file (local preview only), the activity
// row is inserted first so it has an id, then the file is uploaded to
// `<host_id>/<activity_id>.<ext>` and the resulting URL is saved on the row.
// Creating an activity never fails because of its photo.
class ActivityPhotoUploader {
  ActivityPhotoUploader._();

  static final ImagePicker _picker = ImagePicker();

  static SupabaseClient get _supabase => Supabase.instance.client;

  // Opens the system photo picker. Returns null when the user cancels.
  // The file is not uploaded here — the caller shows it as a preview and
  // uploads it after the activity has been created.
  static Future<XFile?> pick() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: ActivityConstants.photoMaxWidth,
      imageQuality: ActivityConstants.photoQuality,
    );
  }

  // Uploads [file] for an activity that already exists and returns its
  // public URL. Never throws: a failure comes back as a warning so the
  // activity itself stays created.
  static Future<ActivityPhotoUploadResult> upload({
    required String activityId,
    required XFile file,
  }) async {
    final hostId = _supabase.auth.currentUser?.id;
    if (hostId == null) {
      return const ActivityPhotoUploadResult(
        warning: "Your photo wasn't saved because you're signed out.",
      );
    }

    final path = ActivityConstants.photoPath(
      hostId: hostId,
      activityId: activityId,
      extension: _extensionOf(file.path),
    );

    try {
      await _supabase.storage
          .from(ActivityConstants.photoBucket)
          .upload(
            path,
            File(file.path),
            fileOptions: const FileOptions(upsert: true),
          );

      final url = _supabase.storage
          .from(ActivityConstants.photoBucket)
          .getPublicUrl(path);

      return ActivityPhotoUploadResult(url: url);
    } catch (_) {
      // Bucket missing, no permission, or the network dropped. The activity
      // is already saved, so report it and carry on without a photo.
      return const ActivityPhotoUploadResult(
        warning: "Your activity was created, but the photo couldn't be saved.",
      );
    }
  }

    // Removes an activity's photo and reports what actually happened, so
  // callers never present an unverified cleanup as a success.
  //
  // Returns true only when there was nothing to remove or every matching
  // object was deleted. Returns false when listing or deleting failed —
  // the file may still exist in Storage.
  static Future<bool> remove({
    required String hostId,
    required String activityId,
  }) async {
    List<String> paths;
    try {
      final objects = await _supabase.storage
          .from(ActivityConstants.photoBucket)
          .list(path: hostId);

      paths = objects
          .where((o) => o.name.startsWith('$activityId.'))
          .map((o) => '$hostId/${o.name}')
          .toList();
    } catch (_) {
      // Could not list the folder, so we cannot say whether a photo is there.
      return false;
    }

    // Nothing stored for this activity: already in the desired end state.
    if (paths.isEmpty) return true;

    try {
      final removed = await _supabase.storage
          .from(ActivityConstants.photoBucket)
          .remove(paths);

      // Storage returns the objects it actually deleted.
      return removed.length == paths.length;
    } catch (_) {
      return false;
    }
  }

  static String _extensionOf(String filePath) {
    final dot = filePath.lastIndexOf('.');
    if (dot == -1 || dot == filePath.length - 1) return 'jpg';
    return filePath.substring(dot + 1);
  }
}