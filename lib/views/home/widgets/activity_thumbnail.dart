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
            ? ActivityVisualTile(activity: activity, iconSize: size * 0.40)
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ActivityVisualTile(
                  activity: activity,
                  iconSize: size * 0.40,
                ),
                frameBuilder: (_, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return const ColoredBox(color: SynkColors.backgroundLight);
                },
              ),
      ),
    );
  }
}

class ActivityVisualTile extends StatelessWidget {
  const ActivityVisualTile({
    super.key,
    required this.activity,
    required this.iconSize,
  });

  final Activity activity;
  final double iconSize;

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
          size: iconSize,
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
    // Racket sports
    (
      ['table tennis', 'ping pong'],
      ActivityVisual(Icons.sports_tennis_rounded, _teal),
    ),
    (
      ['padel', 'tennis', 'squash', 'badminton'],
      ActivityVisual(Icons.sports_tennis_rounded, _teal),
    ),

    // Ball and team sports
    (
      ['football', 'soccer', 'futsal'],
      ActivityVisual(Icons.sports_soccer_rounded, _teal),
    ),
    (['basketball'], ActivityVisual(Icons.sports_basketball_rounded, _orange)),
    (['volleyball'], ActivityVisual(Icons.sports_volleyball_rounded, _orange)),
    (['baseball'], ActivityVisual(Icons.sports_baseball_rounded, _orange)),
    (['cricket'], ActivityVisual(Icons.sports_cricket_rounded, _teal)),
    (['rugby'], ActivityVisual(Icons.sports_rugby_rounded, _orange)),
    (['hockey'], ActivityVisual(Icons.sports_hockey_rounded, _teal)),
    (['handball'], ActivityVisual(Icons.sports_handball_rounded, _orange)),
    (['golf'], ActivityVisual(Icons.golf_course_rounded, _teal)),
    (['bowling'], ActivityVisual(Icons.sports_rounded, _orange)),
    (
      ['karting', 'kart', 'drift', 'car meet'],
      ActivityVisual(Icons.sports_motorsports_rounded, _orange),
    ),

    // Combat sports (before "art" so "martial arts" lands here)
    (
      [
        'martial art', 'boxing', 'kickboxing', 'mma', 'karate', 'taekwondo',
        'jiu jitsu', 'bjj', 'muay thai', 'judo',
      ],
      ActivityVisual(Icons.sports_mma_rounded, _orange),
    ),
    (
      ['paintball', 'laser tag', 'archery', 'axe throwing', 'shooting'],
      ActivityVisual(Icons.gps_fixed_rounded, _orange),
    ),

    // Outdoors and fitness
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
    (['climb', 'bouldering'], ActivityVisual(Icons.terrain_rounded, _teal)),
    (['camp'], ActivityVisual(Icons.cabin_rounded, _sand)),
    (
      ['desert', 'dune', 'safari', 'sandboard'],
      ActivityVisual(Icons.landscape_rounded, _sand),
    ),
    (
      ['stargaz', 'star gazing', 'astronomy'],
      ActivityVisual(Icons.nights_stay_rounded, _sand),
    ),
    (['picnic', 'park'], ActivityVisual(Icons.park_rounded, _teal)),
    (
      ['bbq', 'barbecue', 'grill'],
      ActivityVisual(Icons.outdoor_grill_rounded, _sand),
    ),
    (['fishing'], ActivityVisual(Icons.phishing_rounded, _teal)),
    (
      ['road trip', 'roadtrip'],
      ActivityVisual(Icons.directions_car_rounded, _sand),
    ),
    (
      ['yoga', 'pilates', 'meditation', 'stretch'],
      ActivityVisual(Icons.self_improvement_rounded, _teal),
    ),
    (
      ['trampoline', 'gymnastics', 'parkour'],
      ActivityVisual(Icons.sports_gymnastics_rounded, _teal),
    ),
    (
      ['gym', 'workout', 'fitness', 'crossfit', 'training'],
      ActivityVisual(Icons.fitness_center_rounded, _teal),
    ),
    (['swim'], ActivityVisual(Icons.pool_rounded, _teal)),
    (['dive', 'diving', 'snorkel', 'scuba'], ActivityVisual(Icons.scuba_diving_rounded, _teal)),
    (['surf'], ActivityVisual(Icons.surfing_rounded, _teal)),
    (['kayak', 'paddle board'], ActivityVisual(Icons.kayaking_rounded, _teal)),
    (['beach'], ActivityVisual(Icons.beach_access_rounded, _teal)),
    (['skateboard'], ActivityVisual(Icons.skateboarding_rounded, _orange)),
    (['skate', 'skating'], ActivityVisual(Icons.ice_skating_rounded, _teal)),
    (['skiing', 'snowboard'], ActivityVisual(Icons.downhill_skiing_rounded, _teal)),
    (['dance', 'dancing', 'zumba'], ActivityVisual(Icons.nightlife_rounded, _pink)),

    // Food and drinks
    (
      ['coffee', 'cafe', 'café', 'chat'],
      ActivityVisual(Icons.local_cafe_rounded, _sand),
    ),
    (
      ['karak', 'matcha'],
      ActivityVisual(Icons.emoji_food_beverage_rounded, _sand),
    ),
    (
      ['dessert', 'ice cream', 'gelato'],
      ActivityVisual(Icons.icecream_rounded, _pink),
    ),
    (
      [
        'cook', 'baking', 'dinner', 'lunch', 'breakfast', 'brunch', 'food',
        'pizza', 'burger', 'sushi', 'restaurant',
      ],
      ActivityVisual(Icons.restaurant_rounded, _sand),
    ),

    // Games
    (['board game', 'cards'], ActivityVisual(Icons.casino_rounded, _pink)),
    (['chess', 'puzzle'], ActivityVisual(Icons.extension_rounded, _pink)),
    (['escape room'], ActivityVisual(Icons.key_rounded, _pink)),
    (['trivia', 'quiz'], ActivityVisual(Icons.quiz_rounded, _pink)),
    (
      ['game', 'gaming', 'playstation', 'fifa'],
      ActivityVisual(Icons.sports_esports_rounded, _pink),
    ),

    // Culture and entertainment
    (['movie', 'cinema', 'film'], ActivityVisual(Icons.movie_rounded, _pink)),
    (
      ['comedy', 'stand up', 'theater', 'theatre'],
      ActivityVisual(Icons.theater_comedy_rounded, _pink),
    ),
    (
      ['karaoke', 'sing', 'music', 'concert'],
      ActivityVisual(Icons.mic_rounded, _pink),
    ),
    (
      ['museum', 'exhibition', 'gallery'],
      ActivityVisual(Icons.museum_rounded, _sand),
    ),
    (
      ['pottery', 'art', 'paint', 'craft', 'draw'],
      ActivityVisual(Icons.palette_rounded, _pink),
    ),
    (['book', 'reading'], ActivityVisual(Icons.menu_book_rounded, _sand)),
    (['photo'], ActivityVisual(Icons.photo_camera_rounded, _sand)),

    // Learning and community
    (
      ['study', 'coding', 'hackathon', 'workshop'],
      ActivityVisual(Icons.school_rounded, _sand),
    ),
    (['language'], ActivityVisual(Icons.translate_rounded, _sand)),
    (
      ['volunteer', 'charity'],
      ActivityVisual(Icons.volunteer_activism_rounded, _pink),
    ),
    (['shopping', 'mall'], ActivityVisual(Icons.shopping_bag_rounded, _pink)),
  ];

  static const ActivityVisual fallback = ActivityVisual(
    Icons.groups_rounded,
    _orange,
  );

  static ActivityVisual of(Activity activity) =>
      forText('${activity.categoryLabel} ${activity.title}');

  static ActivityVisual forText(String value) {
    final text = value.toLowerCase();
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
