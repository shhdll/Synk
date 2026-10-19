import 'package:flutter/material.dart';

import '../views/widgets/photo_crop_screen.dart';

// Opens the Move and Scale screen. Returns the cropped file's path, or null
// if the user cancels.
Future<String?> cropPhoto(
  String sourcePath, {
  double aspectRatio = 1,
  bool circle = false,
  int maxWidth = 1600,
}) async {
  final navigator = _rootNavigator();
  if (navigator == null) {
    debugPrint('cropPhoto: no navigator found, skipping crop');
    return sourcePath;
  }
  return navigator.push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PhotoCropScreen(
        imagePath: sourcePath,
        aspectRatio: aspectRatio,
        circle: circle,
        maxOutputWidth: maxWidth,
      ),
    ),
  );
}

// The pickers live in models without a BuildContext, so find the app's
// top-level navigator from the widget tree.
NavigatorState? _rootNavigator() {
  NavigatorState? found;
  void visit(Element element) {
    if (found != null) return;
    if (element is StatefulElement && element.state is NavigatorState) {
      found = element.state as NavigatorState;
      return;
    }
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return found;
}
