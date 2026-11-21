import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Saves roughly where the user is (rounded to 0.1°, about 10 km) so the
// "nice weather tonight" nudge can check their evening's forecast
// (supabase/migrations/20261121100000_marketing_nudges.sql). Nothing more
// precise ever leaves the phone.
class WeatherSpotModel {
  WeatherSpotModel._();

  static final WeatherSpotModel instance = WeatherSpotModel._();

  // What was last saved this run, so moving around town doesn't write
  // again and again.
  String? _saved;

  Future<void> save(double latitude, double longitude) async {
    final lat = (latitude * 10).round() / 10;
    final lon = (longitude * 10).round() / 10;
    final key = '$lat,$lon';
    if (key == _saved) return;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.from('user_weather_spots').upsert({
        'user_id': userId,
        'latitude': lat,
        'longitude': lon,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _saved = key;
    } catch (error) {
      // Only for a nudge; never worth bothering the user about.
      debugPrint('SYNK: weather spot not saved: $error');
    }
  }
}
