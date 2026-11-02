import 'dart:convert';

import 'package:http/http.dart' as http;

// Forecast for an activity's place and start time, from Open-Meteo
// (free, no API key). Forecasts go up to 16 days ahead.
enum WeatherCondition { clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, storm }

class ActivityWeather {
  const ActivityWeather({
    required this.condition,
    required this.temperature,
    required this.rainChance,
    required this.windSpeed,
  });

  final WeatherCondition condition;
  final double temperature;
  final int rainChance;
  final double windSpeed;
}

class WeatherTooFarAhead implements Exception {
  const WeatherTooFarAhead();
}

class WeatherModel {
  WeatherModel._();

  static const int forecastDays = 16;
  static final Map<String, ActivityWeather> _cache = {};

  static Future<ActivityWeather> fetch({
    required double latitude,
    required double longitude,
    required DateTime startsAt,
  }) async {
    final start = startsAt.toUtc();
    final now = DateTime.now().toUtc();
    if (start.difference(now).inDays >= forecastDays - 1) {
      throw const WeatherTooFarAhead();
    }

    final hour = DateTime.utc(start.year, start.month, start.day, start.hour);
    final key =
        '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)},'
        '${hour.toIso8601String()}';
    final cached = _cache[key];
    if (cached != null) return cached;

    final date = hour.toIso8601String().substring(0, 10);
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'hourly':
          'temperature_2m,precipitation_probability,weather_code,wind_speed_10m',
      'timezone': 'GMT',
      'start_date': date,
      'end_date': date,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Weather request failed (${response.statusCode})');
    }

    final hourly =
        (jsonDecode(response.body) as Map<String, dynamic>)['hourly']
            as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final target = hour.toIso8601String().substring(0, 13);
    var index = times.indexWhere((t) => t.startsWith(target));
    if (index < 0) index = 0;

    num? at(String field) => (hourly[field] as List)[index] as num?;

    final weather = ActivityWeather(
      condition: _condition((at('weather_code') ?? 0).toInt()),
      temperature: (at('temperature_2m') ?? 0).toDouble(),
      rainChance: (at('precipitation_probability') ?? 0).toInt(),
      windSpeed: (at('wind_speed_10m') ?? 0).toDouble(),
    );
    _cache[key] = weather;
    return weather;
  }

  // WMO weather codes.
  static WeatherCondition _condition(int code) {
    if (code == 0) return WeatherCondition.clear;
    if (code <= 2) return WeatherCondition.partlyCloudy;
    if (code == 3) return WeatherCondition.cloudy;
    if (code == 45 || code == 48) return WeatherCondition.fog;
    if (code >= 51 && code <= 57) return WeatherCondition.drizzle;
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return WeatherCondition.rain;
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return WeatherCondition.snow;
    }
    if (code >= 95) return WeatherCondition.storm;
    return WeatherCondition.cloudy;
  }
}
