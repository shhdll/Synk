import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/activity_constants.dart';
import '../utils/photo_cropper.dart';

// Picks the single optional photo attached to an activity, and removes an
// activity's photo files.
//
// Uploading happens on the server now: the save-activity Edge Function
// checks the photo, re-encodes it and stores it together with the activity,
// so a host can't put an unchecked photo in place.
class ActivityPhotoUploader {
  ActivityPhotoUploader._();

  static final ImagePicker _picker = ImagePicker();

  static SupabaseClient get _supabase => Supabase.instance.client;

  // Opens the system photo picker. Returns null when the user cancels.
  // The file is not uploaded here — the caller shows it as a preview and
  // uploads it after the activity has been created.
  static Future<XFile?> pick() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: ActivityConstants.photoMaxWidth,
      imageQuality: ActivityConstants.photoQuality,
    );
    if (picked == null) return null;

    // 2:1 matches the photo header on the activity details sheet.
    final croppedPath = await cropPhoto(
      picked.path,
      aspectRatio: 2,
      maxWidth: ActivityConstants.photoMaxWidth.toInt(),
    );
    return croppedPath == null ? null : XFile(croppedPath);
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
}
