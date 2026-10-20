import 'package:flutter/widgets.dart';

class SynkIcons {
  SynkIcons._();

  // Icons.logout_rounded, but its arrow flips to point left in Arabic like
  // the app's other arrows.
  static const IconData logout = IconData(
    0xf88b,
    fontFamily: 'MaterialIcons',
    matchTextDirection: true,
  );
}
