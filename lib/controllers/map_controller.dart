import 'package:flutter/foundation.dart';

import '../core/constants/synk_colors.dart';
import '../models/map_pin.dart';

// Placeholder pin positions for the Map screen. Ready to be replaced with
// real nearby-activity locations once a map package and API key are wired
// up (see MapView).
class MapController extends ChangeNotifier {
  static const List<MapPin> pins = [
    MapPin(top: 90, left: 60, color: SynkColors.orangeDark),
    MapPin(top: 170, left: 190, color: SynkColors.teal),
    MapPin(top: 260, left: 90, color: SynkColors.pink),
  ];
}
