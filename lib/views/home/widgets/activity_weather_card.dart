import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/weather_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: FutureBuilder<ActivityWeather>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _row(
              icon: Icons.wb_cloudy_outlined,
              title: l10n.weather,
              subtitle: l10n.loadingForecast,
              muted: true,
            );
          }
          if (snapshot.hasError) {
            return _row(
              icon: Icons.cloud_off_rounded,
              title: l10n.weather,
              subtitle: snapshot.error is WeatherTooFarAhead
                  ? l10n.forecastTooFarAhead
                  : l10n.weatherUnavailable,
              muted: true,
            );
          }

          final weather = snapshot.data!;
          return _row(
            icon: _icon(weather.condition),
            title: '${weather.temperature.round()}°C',
            subtitle: _note(l10n, weather),
            large: true,
          );
        },
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    String? subtitle,
    bool muted = false,
    bool large = false,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: SynkColors.teal.withValues(alpha: muted ? 0.08 : 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: muted ? SynkColors.textSecondary : SynkColors.tealText,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: large ? 20 : 14,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: SynkColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _icon(WeatherCondition condition) => switch (condition) {
    WeatherCondition.clear => Icons.wb_sunny_rounded,
    WeatherCondition.partlyCloudy => Icons.wb_cloudy_outlined,
    WeatherCondition.cloudy => Icons.cloud_rounded,
    WeatherCondition.fog => Icons.foggy,
    WeatherCondition.drizzle => Icons.grain_rounded,
    WeatherCondition.rain => Icons.umbrella_rounded,
    WeatherCondition.snow => Icons.ac_unit_rounded,
    WeatherCondition.storm => Icons.thunderstorm_rounded,
  };

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
