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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row(
                icon: _icon(weather.condition),
                title: '${weather.temperature.round()}°',
                subtitle: _label(l10n, weather.condition),
                large: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Chip(
                    icon: Icons.water_drop_outlined,
                    label: l10n.rainChance(weather.rainChance),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    icon: Icons.air_rounded,
                    label: l10n.windSpeed(weather.windSpeed.round()),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
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

  static String _label(AppLocalizations l10n, WeatherCondition condition) =>
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
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SynkColors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SynkColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: SynkColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
