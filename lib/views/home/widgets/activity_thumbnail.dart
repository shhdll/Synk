import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../models/activity_model.dart';

// Square activity image for the home cards. Activities without a photo get
// a soft tinted tile with an icon for their kind of activity.
class ActivityThumbnail extends StatelessWidget {
  const ActivityThumbnail({
    super.key,
    required this.activity,
    this.size = 76,
    this.radius = 12,
  });

  final Activity activity;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photoUrl = activity.photoUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: photoUrl == null || photoUrl.isEmpty
            ? _Fallback(activity: activity, size: size)
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _Fallback(activity: activity, size: size),
                frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return const ColoredBox(color: SynkColors.backgroundLight);
                },
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.activity, required this.size});

  final Activity activity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visual = ActivityVisual.of(activity);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            visual.tint.withValues(alpha: 0.16),
            visual.tint.withValues(alpha: 0.30),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          visual.icon,
          size: size * 0.40,
          color: Color.lerp(visual.tint, SynkColors.textPrimary, 0.35),
        ),
      ),
    );
  }
}

// Icon and tint used when an activity has no photo, picked from its
// category label or, since most activities have none, its title.
class ActivityVisual {
  const ActivityVisual(this.icon, this.tint);

  final IconData icon;
  final Color tint;

  static const _orange = SynkColors.orangeDark;
  static const _teal = SynkColors.teal;
  static const _pink = Color(0xFFE5739B);
  static const _sand = SynkColors.beigeDark;

  // Checked in order; the first keyword found wins.
  static const List<(List<String>, ActivityVisual)> _rules = [
    (
      ['table tennis', 'ping pong'],
      ActivityVisual(Icons.sports_tennis_rounded, _teal),
    ),
    (
      ['padel', 'tennis', 'squash'],
      ActivityVisual(Icons.sports_tennis_rounded, _teal),
    ),
    (
      ['football', 'soccer'],
      ActivityVisual(Icons.sports_soccer_rounded, _teal),
    ),
    (['basketball'], ActivityVisual(Icons.sports_basketball_rounded, _orange)),
    (['volleyball'], ActivityVisual(Icons.sports_volleyball_rounded, _orange)),
    (['bowling'], ActivityVisual(Icons.sports_rounded, _orange)),
    (
      ['karting', 'kart'],
      ActivityVisual(Icons.sports_motorsports_rounded, _orange),
    ),
    (
      ['cycling', 'bike', 'biking'],
      ActivityVisual(Icons.directions_bike_rounded, _teal),
    ),
    (
      ['run', 'jog', 'marathon'],
      ActivityVisual(Icons.directions_run_rounded, _teal),
    ),
    (
      ['hike', 'hiking', 'trail', 'walk'],
      ActivityVisual(Icons.hiking_rounded, _teal),
    ),
    (['climb'], ActivityVisual(Icons.terrain_rounded, _teal)),
    (['camp'], ActivityVisual(Icons.cabin_rounded, _sand)),
    (
      ['gym', 'workout', 'yoga', 'fitness'],
      ActivityVisual(Icons.fitness_center_rounded, _teal),
    ),
    (['swim'], ActivityVisual(Icons.pool_rounded, _teal)),
    (
      ['coffee', 'cafe', 'café', 'chat'],
      ActivityVisual(Icons.local_cafe_rounded, _sand),
    ),
    (
      ['cook', 'baking', 'dinner', 'brunch', 'food'],
      ActivityVisual(Icons.restaurant_rounded, _sand),
    ),
    (
      ['board game', 'chess', 'cards', 'puzzle'],
      ActivityVisual(Icons.extension_rounded, _pink),
    ),
    (['escape room'], ActivityVisual(Icons.key_rounded, _pink)),
    (['game', 'gaming'], ActivityVisual(Icons.sports_esports_rounded, _pink)),
    (['movie', 'cinema', 'film'], ActivityVisual(Icons.movie_rounded, _pink)),
    (
      ['karaoke', 'sing', 'music', 'concert'],
      ActivityVisual(Icons.mic_rounded, _pink),
    ),
    (
      ['pottery', 'art', 'paint', 'craft', 'draw'],
      ActivityVisual(Icons.palette_rounded, _pink),
    ),
    (['book', 'reading'], ActivityVisual(Icons.menu_book_rounded, _sand)),
    (['photo'], ActivityVisual(Icons.photo_camera_rounded, _sand)),
  ];

  static const ActivityVisual fallback = ActivityVisual(
    Icons.groups_rounded,
    _orange,
  );

  static ActivityVisual of(Activity activity) {
    final text = '${activity.categoryLabel} ${activity.title}'.toLowerCase();
    for (final (keywords, visual) in _rules) {
      // Match at word starts so "run" finds "running" but not "brunch".
      if (keywords.any(
        (k) => RegExp('\\b${RegExp.escape(k)}').hasMatch(text),
      )) {
        return visual;
      }
    }
    return fallback;
  }
}
