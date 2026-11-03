import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/weather_model.dart';

// The icon for a weather condition, shared with the map.
IconData weatherIconFor(WeatherCondition condition) => switch (condition) {
  WeatherCondition.clear => Icons.wb_sunny_rounded,
  WeatherCondition.partlyCloudy => Icons.wb_cloudy_outlined,
  WeatherCondition.cloudy => Icons.cloud_rounded,
  WeatherCondition.fog => Icons.foggy,
  WeatherCondition.drizzle => Icons.grain_rounded,
  WeatherCondition.rain => Icons.umbrella_rounded,
  WeatherCondition.snow => Icons.ac_unit_rounded,
  WeatherCondition.storm => Icons.thunderstorm_rounded,
};

// The sun is yellow; everything else stays teal.
Color weatherColorFor(WeatherCondition condition) =>
    condition == WeatherCondition.clear
    ? const Color(0xFFF2B705)
    : SynkColors.tealText;

// Forecast for the activity's place at its start time.
class ActivityWeatherCard extends StatefulWidget {
  const ActivityWeatherCard({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.startsAt,
  });

  final double latitude;
  final double longitude;
  final DateTime startsAt;

  @override
  State<ActivityWeatherCard> createState() => _ActivityWeatherCardState();
}

class _ActivityWeatherCardState extends State<ActivityWeatherCard> {
  late Future<ActivityWeather> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(ActivityWeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.startsAt != widget.startsAt) {
      _future = _load();
    }
  }

  Future<ActivityWeather> _load() => WeatherModel.fetch(
    latitude: widget.latitude,
    longitude: widget.longitude,
    startsAt: widget.startsAt,
  );

  // One small line: icon, temperature and anything worth knowing. Hidden
  // while loading and when there's no forecast.
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return FutureBuilder<ActivityWeather>(
      future: _future,
      builder: (context, snapshot) {
        final weather = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            weather == null) {
          return const SizedBox.shrink();
        }
        final note = _note(l10n, weather);

        // The gap above comes with it, so nothing is left when it's hidden.
        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                weatherIconFor(weather.condition),
                size: 18,
                color: weatherColorFor(weather.condition),
              ),
              const SizedBox(width: 8),
              Text(
                '${weather.temperature.round()}°',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              if (note != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Only weather worth knowing about; a clear or cloudy day shows nothing.
  static String? _note(AppLocalizations l10n, ActivityWeather weather) {
    final notes = <String>[
      ?switch (weather.condition) {
        WeatherCondition.storm => l10n.weatherStorm,
        WeatherCondition.rain => l10n.weatherRain,
        WeatherCondition.drizzle => l10n.weatherDrizzle,
        WeatherCondition.snow => l10n.weatherSnow,
        WeatherCondition.fog => l10n.weatherFog,
        _ when weather.rainChance >= 40 => l10n.rainChance(weather.rainChance),
        _ => null,
      },
      if (weather.windSpeed >= 30) l10n.windSpeed(weather.windSpeed.round()),
    ];
    return notes.isEmpty ? null : notes.join(' · ');
  }
}

// A tiny pill with the weather right now, for the map. Hidden until it
// loads and when there's no forecast.
class MapWeatherPill extends StatefulWidget {
  const MapWeatherPill({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  State<MapWeatherPill> createState() => _MapWeatherPillState();
}

class _MapWeatherPillState extends State<MapWeatherPill> {
  late Future<ActivityWeather> _future = _load();

  // Small moves don't change the weather; only refetch for a new area.
  String _area(MapWeatherPill w) =>
      '${w.latitude.toStringAsFixed(1)},${w.longitude.toStringAsFixed(1)}';

  @override
  void didUpdateWidget(MapWeatherPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_area(oldWidget) != _area(widget)) _future = _load();
  }

  Future<ActivityWeather> _load() => WeatherModel.fetch(
    latitude: widget.latitude,
    longitude: widget.longitude,
    startsAt: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ActivityWeather>(
      future: _future,
      builder: (context, snapshot) {
        final weather = snapshot.data;
        if (weather == null) return const SizedBox.shrink();
        return Material(
          // Light yellow, for the weather.
          color: const Color(0xFFFFF4C7),
          elevation: 3,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  weatherIconFor(weather.condition),
                  size: 16,
                  color: weatherColorFor(weather.condition),
                ),
                const SizedBox(width: 5),
                Text(
                  '${weather.temperature.round()}°',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
