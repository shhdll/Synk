import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../core/constants/activity_constants.dart';
import '../models/activity_save_model.dart';

// Turns the picked (and cropped) activity photo into what the server
// accepts: a JPEG of at most 2 MB, upright, with no EXIF or GPS data. The
// server checks and re-encodes it again; doing it here keeps uploads small
// and keeps location data off the network.
//
// Returns the path of the prepared file in the app's documents folder, so
// it survives the app closing while a save is pending, or null when the
// photo can't be read or made small enough.
Future<String?> prepareActivityPhoto(String sourcePath) async {
  try {
    final bytes = await File(sourcePath).readAsBytes();
    final jpeg = await compute(encodeActivityJpeg, bytes);
    if (jpeg == null) return null;
    final folder = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/pending_activity_photos',
    );
    await folder.create(recursive: true);
    final file = File('${folder.path}/${newUuidV4()}.jpg');
    await file.writeAsBytes(jpeg, flush: true);
    return file.path;
  } catch (error) {
    debugPrint('SYNK: activity photo prepare failed: ${error.runtimeType}');
    return null;
  }
}

// Pure, so it can run in an isolate and in tests.
Uint8List? encodeActivityJpeg(Uint8List input) {
  img.Image? image;
  try {
    image = img.decodeImage(input);
  } catch (_) {
    return null;
  }
  if (image == null) return null;

  // Apply the EXIF rotation to the pixels, then drop all metadata.
  image = img.bakeOrientation(image);
  final maxWidth = ActivityConstants.photoMaxWidth.toInt();
  if (image.width > maxWidth) {
    image = img.copyResize(
      image,
      width: maxWidth,
      interpolation: img.Interpolation.average,
    );
  }
  image.exif = img.ExifData();

  for (final quality in const [85, 75, 65]) {
    final jpeg = img.encodeJpg(image, quality: quality);
    if (jpeg.length <= ActivitySaveLimits.photoBytes) return jpeg;
  }
  return null;
}
