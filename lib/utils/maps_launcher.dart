import 'package:url_launcher/url_launcher.dart';

import '../models/activity_model.dart';

// Opens an activity's location in Google Maps (the app when installed,
// otherwise the browser) using the Maps URLs API.
class MapsLauncher {
  MapsLauncher._();

  // Coordinates are the most precise; fall back to the address, then the
  // place name. Returns null when the activity has no usable location.
  static Uri? googleMapsUri(Activity activity) {
    final String query;
    if (activity.hasCoordinates) {
      query = '${activity.latitude},${activity.longitude}';
    } else if ((activity.locationAddress ?? '').trim().isNotEmpty) {
      query = activity.locationAddress!.trim();
    } else if (activity.location.trim().isNotEmpty) {
      query = activity.location.trim();
    } else {
      return null;
    }

    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }

  static bool canOpen(Activity activity) => googleMapsUri(activity) != null;

  static Future<bool> open(Activity activity) async {
    final uri = googleMapsUri(activity);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
