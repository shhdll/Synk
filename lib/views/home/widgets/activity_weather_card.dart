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
  WeatherCondition.drizzle => Icons.water_drop_rounded,
  WeatherCondition.rain => Icons.umbrella_rounded,
  WeatherCondition.snow => Icons.ac_unit_rounded,
  WeatherCondition.storm => Icons.thunderstorm_rounded,
};

// The sun is yellow; everything else stays teal.
Color weatherColorFor(WeatherCondition condition) =>
    condition == WeatherCondition.clear
    ? const Color(0xFFF2B705)
    : SynkColors.tealText;

String weatherNameFor(AppLocalizations l10n, WeatherCondition condition) =>
    switch (condition) {
      WeatherCondition.clear => l10n.weatherClear,
      WeatherCondition.partlyCloudy => l10n.weatherPartlyCloudy,
      WeatherCondition.cloudy => l10n.weatherCloudy,
      WeatherCondition.fog => l10n.weatherFog,
      WeatherCondition.drizzle => l10n.weatherDrizzle,
      WeatherCondition.rain => l10n.weatherRain,
      WeatherCondition.snow => l10n.weatherSnow,
      WeatherCondition.storm => l10n.weatherStorm,
    };

// A short tip on what to wear, from how it feels outside.
String weatherTipFor(AppLocalizations l10n, ActivityWeather weather) {
  if (weather.condition == WeatherCondition.storm) return l10n.weatherTipStorm;
  if (weather.condition == WeatherCondition.rain ||
      weather.condition == WeatherCondition.drizzle) {
    return l10n.weatherTipRain;
  }
  final feels = weather.feelsLike;
  if (feels >= 38) return l10n.weatherTipHot;
  if (feels >= 30) return l10n.weatherTipWarm;
  if (feels >= 20) return l10n.weatherTipNice;
  if (feels >= 12) return l10n.weatherTipCool;
  return l10n.weatherTipCold;
}

// The full forecast, from tapping the temperature.
Future<void> showWeatherSheet(BuildContext context, ActivityWeather weather) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _WeatherSheet(weather: weather),
  );
}

class _WeatherSheet extends StatelessWidget {
  const _WeatherSheet({required this.weather});

  final ActivityWeather weather;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = [
      (
        Icons.thermostat_rounded,
        l10n.feelsLike,
        '${weather.feelsLike.round()}°',
      ),
      (Icons.water_drop_outlined, l10n.chanceOfRain, '${weather.rainChance}%'),
      (Icons.air_rounded, l10n.wind, l10n.kmPerHour(weather.windSpeed.round())),
      (Icons.opacity_rounded, l10n.humidity, '${weather.humidity}%'),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: SynkColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: SynkColors.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            weatherIconFor(weather.condition),
            size: 44,
            color: weatherColorFor(weather.condition),
          ),
          const SizedBox(height: 8),
          Text(
            '${weather.temperature.round()}°',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: SynkColors.textPrimary,
            ),
          ),
          Text(
            weatherNameFor(l10n, weather.condition),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: SynkColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4C7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              weatherTipFor(l10n, weather),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SynkColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (final (i, (icon, label, value)) in rows.indexed) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: SynkColors.textSecondary.withValues(alpha: 0.12),
                    ),
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: SynkColors.tealText),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: SynkColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

  // A small button with the icon and temperature, next to the map
  // buttons. Hidden while loading and when there's no forecast.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ActivityWeather>(
      future: _future,
      builder: (context, snapshot) {
        final weather = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            weather == null) {
          return const SizedBox.shrink();
        }

        // The gap before it comes with it, so nothing is left when hidden.
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: 10),
          child: SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => showWeatherSheet(context, weather),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: SynkColors.textSecondary.withValues(alpha: 0.18),
                  ),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    weatherIconFor(weather.condition),
                    size: 20,
                    color: weatherColorFor(weather.condition),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${weather.temperature.round()}°',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showWeatherSheet(context, weather),
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
          ),
        );
      },
    );
  }
}
