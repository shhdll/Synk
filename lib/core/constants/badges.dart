import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

// Badges. The rules are worked out on the server
// (supabase/migrations/20261114200000_badges.sql); names for the push are in
// supabase/functions/notify-waitlist-promotion/badges.ts. Keep the three in
// step.
//
// Badges look like medals. Every badge in a group has the group's shape and
// icon; the tier color shows how hard it is.

enum MedalShape {
  circle,
  shield,
  diamond,
  hexagon,
  octagon,
  starburst,
  scallop,
  pentagon,
}

// Colors follow the Synk palette but still read as bronze, silver, gold
// and platinum. [level] adds to the medal: 1 ribbons, 2 a rosette, 3 a
// bigger rosette and a gem.
enum BadgeTier {
  bronze(Color(0xFFFFB27A), Color(0xFFCA602F), 0),
  silver(Color(0xFFEEF1F3), Color(0xFF8C979F), 1),
  gold(Color(0xFFFFD866), Color(0xFFE8901F), 2),
  platinum(Color(0xFFA8E6DA), Color(0xFF2E8C7E), 3),
  // Category badges, all on the Synk colors.
  fan(Color(0xFFFF9EC0), Color(0xFF4FA89B), 0),
  secret(Color(0xFF5A4C7A), Color(0xFF231C33), 0);

  const BadgeTier(this.light, this.dark, this.level);

  final Color light;
  final Color dark;
  final int level;
}

enum BadgeGroup {
  goingOut(MedalShape.circle, Icons.directions_walk_rounded),
  hosting(MedalShape.shield, Icons.celebration_rounded),
  variety(MedalShape.diamond, Icons.explore_rounded),
  category(MedalShape.scallop, Icons.favorite_rounded),
  friends(MedalShape.hexagon, Icons.people_alt_rounded),
  streaks(MedalShape.octagon, Icons.local_fire_department_rounded),
  ratings(MedalShape.starburst, Icons.star_rounded),
  secret(MedalShape.pentagon, Icons.help_rounded);

  const BadgeGroup(this.shape, this.icon);

  final MedalShape shape;
  final IconData icon;
}

class BadgeInfo {
  const BadgeInfo(
    this.id,
    this.group,
    this.tier, {
    this.stat,
    this.goal = 1,
    this.icon,
  });

  final String id;
  final BadgeGroup group;
  final BadgeTier tier;

  // The number in get_my_badges' stats that counts toward [goal]. Null for
  // badges you either have or don't.
  final String? stat;
  final int goal;

  // Only secret and category badges have their own icon.
  final IconData? icon;

  IconData get iconData => icon ?? group.icon;

  bool get isSecret => group == BadgeGroup.secret;
}

// One badge per category, earned at this many activities in it.
const int kCategoryFanGoal = 5;
const String kCategoryFanPrefix = 'fan:';

const List<BadgeInfo> kBadges = [
  BadgeInfo(
    'attend_1',
    BadgeGroup.goingOut,
    BadgeTier.bronze,
    stat: 'attended',
    goal: 1,
  ),
  BadgeInfo(
    'attend_10',
    BadgeGroup.goingOut,
    BadgeTier.silver,
    stat: 'attended',
    goal: 10,
  ),
  BadgeInfo(
    'attend_25',
    BadgeGroup.goingOut,
    BadgeTier.gold,
    stat: 'attended',
    goal: 25,
  ),
  BadgeInfo(
    'attend_50',
    BadgeGroup.goingOut,
    BadgeTier.platinum,
    stat: 'attended',
    goal: 50,
  ),
  BadgeInfo(
    'host_1',
    BadgeGroup.hosting,
    BadgeTier.bronze,
    stat: 'hosted',
    goal: 1,
  ),
  BadgeInfo('full_house', BadgeGroup.hosting, BadgeTier.silver),
  BadgeInfo(
    'host_10',
    BadgeGroup.hosting,
    BadgeTier.gold,
    stat: 'hosted',
    goal: 10,
  ),
  BadgeInfo(
    'host_25',
    BadgeGroup.hosting,
    BadgeTier.platinum,
    stat: 'hosted',
    goal: 25,
  ),
  BadgeInfo(
    'variety_5',
    BadgeGroup.variety,
    BadgeTier.bronze,
    stat: 'categories',
    goal: 5,
  ),
  BadgeInfo(
    'variety_10',
    BadgeGroup.variety,
    BadgeTier.silver,
    stat: 'categories',
    goal: 10,
  ),
  BadgeInfo(
    'variety_20',
    BadgeGroup.variety,
    BadgeTier.gold,
    stat: 'categories',
    goal: 20,
  ),
  BadgeInfo(
    'variety_30',
    BadgeGroup.variety,
    BadgeTier.platinum,
    stat: 'categories',
    goal: 30,
  ),
  BadgeInfo(
    'friends_5',
    BadgeGroup.friends,
    BadgeTier.bronze,
    stat: 'friends',
    goal: 5,
  ),
  BadgeInfo(
    'together_5',
    BadgeGroup.friends,
    BadgeTier.silver,
    stat: 'together',
    goal: 5,
  ),
  BadgeInfo(
    'friends_15',
    BadgeGroup.friends,
    BadgeTier.gold,
    stat: 'friends',
    goal: 15,
  ),
  BadgeInfo(
    'friends_30',
    BadgeGroup.friends,
    BadgeTier.platinum,
    stat: 'friends',
    goal: 30,
  ),
  BadgeInfo(
    'streak_3',
    BadgeGroup.streaks,
    BadgeTier.bronze,
    stat: 'best_streak',
    goal: 3,
  ),
  BadgeInfo(
    'streak_8',
    BadgeGroup.streaks,
    BadgeTier.silver,
    stat: 'best_streak',
    goal: 8,
  ),
  BadgeInfo(
    'streak_20',
    BadgeGroup.streaks,
    BadgeTier.gold,
    stat: 'best_streak',
    goal: 20,
  ),
  BadgeInfo(
    'streak_52',
    BadgeGroup.streaks,
    BadgeTier.platinum,
    stat: 'best_streak',
    goal: 52,
  ),
  BadgeInfo(
    'five_star',
    BadgeGroup.ratings,
    BadgeTier.bronze,
    stat: 'five_stars',
    goal: 1,
  ),
  BadgeInfo(
    'rater_10',
    BadgeGroup.ratings,
    BadgeTier.silver,
    stat: 'rated_activities',
    goal: 10,
  ),
  BadgeInfo(
    'rated_4_5',
    BadgeGroup.ratings,
    BadgeTier.gold,
    stat: 'rating_count',
    goal: 10,
  ),
  BadgeInfo(
    'rated_4_8',
    BadgeGroup.ratings,
    BadgeTier.platinum,
    stat: 'rating_count',
    goal: 25,
  ),
  BadgeInfo(
    'early_bird',
    BadgeGroup.secret,
    BadgeTier.secret,
    icon: Icons.wb_twilight_rounded,
  ),
  BadgeInfo(
    'night_owl',
    BadgeGroup.secret,
    BadgeTier.secret,
    icon: Icons.nightlight_round,
  ),
  BadgeInfo(
    'lucky_spot',
    BadgeGroup.secret,
    BadgeTier.secret,
    icon: Icons.confirmation_number_rounded,
  ),
  BadgeInfo(
    'weekend',
    BadgeGroup.secret,
    BadgeTier.secret,
    icon: Icons.weekend_rounded,
  ),
];

const BadgeInfo kCategoryFanBadge = BadgeInfo(
  kCategoryFanPrefix,
  BadgeGroup.category,
  BadgeTier.fan,
  goal: kCategoryFanGoal,
);

// The catalog entry for a saved badge id. Each category badge gets the
// category's own icon.
BadgeInfo? badgeInfo(String id) {
  if (id.startsWith(kCategoryFanPrefix)) {
    final icon = _categoryIcons[id.substring(kCategoryFanPrefix.length)];
    return icon == null
        ? kCategoryFanBadge
        : BadgeInfo(
            id,
            BadgeGroup.category,
            BadgeTier.fan,
            goal: kCategoryFanGoal,
            icon: icon,
          );
  }
  for (final badge in kBadges) {
    if (badge.id == id) return badge;
  }
  return null;
}

const Map<String, IconData> _categoryIcons = {
  'Padel': Icons.sports_tennis_rounded,
  'Tennis': Icons.sports_baseball_rounded,
  'Badminton': Icons.air_rounded,
  'Table Tennis': Icons.table_bar_rounded,
  'Football': Icons.sports_soccer_rounded,
  'Basketball': Icons.sports_basketball_rounded,
  'Volleyball': Icons.sports_volleyball_rounded,
  'Golf': Icons.golf_course_rounded,
  'Bowling': Icons.adjust_rounded,
  'Karting': Icons.sports_motorsports_rounded,
  'Martial Arts': Icons.sports_martial_arts_rounded,
  'Paintball': Icons.gps_fixed_rounded,
  'Cycling': Icons.directions_bike_rounded,
  'Running': Icons.directions_run_rounded,
  'Hiking': Icons.hiking_rounded,
  'Climbing': Icons.terrain_rounded,
  'Camping': Icons.forest_rounded,
  'Desert Trips': Icons.landscape_rounded,
  'Picnic': Icons.outdoor_grill_rounded,
  'Fitness': Icons.fitness_center_rounded,
  'Yoga': Icons.self_improvement_rounded,
  'Swimming': Icons.pool_rounded,
  'Diving': Icons.scuba_diving_rounded,
  'Skating': Icons.skateboarding_rounded,
  'Dance': Icons.nightlife_rounded,
  'Coffee': Icons.local_cafe_rounded,
  'Cooking': Icons.soup_kitchen_rounded,
  'Food': Icons.restaurant_rounded,
  'Board Games': Icons.casino_rounded,
  'Chess': Icons.grid_view_rounded,
  'Escape Room': Icons.vpn_key_rounded,
  'Trivia': Icons.quiz_rounded,
  'Gaming': Icons.sports_esports_rounded,
  'Movies': Icons.movie_rounded,
  'Comedy': Icons.theater_comedy_rounded,
  'Karaoke': Icons.mic_rounded,
  'Music': Icons.music_note_rounded,
  'Art': Icons.palette_rounded,
  'Pottery': Icons.local_florist_rounded,
  'Museums': Icons.museum_rounded,
  'Books': Icons.menu_book_rounded,
  'Photography': Icons.photo_camera_rounded,
  'Learning': Icons.school_rounded,
  'Volunteering': Icons.volunteer_activism_rounded,
  'Shopping': Icons.shopping_bag_rounded,
};

String badgeGroupLabel(AppLocalizations l, BadgeGroup group) => switch (group) {
  BadgeGroup.goingOut => l.badgeGroupGoingOut,
  BadgeGroup.hosting => l.badgeGroupHosting,
  BadgeGroup.variety => l.badgeGroupVariety,
  BadgeGroup.category => l.badgeGroupCategory,
  BadgeGroup.friends => l.badgeGroupFriends,
  BadgeGroup.streaks => l.badgeGroupStreaks,
  BadgeGroup.ratings => l.badgeGroupRatings,
  BadgeGroup.secret => l.badgeGroupSecret,
};

String badgeName(AppLocalizations l, String id) {
  if (id.startsWith(kCategoryFanPrefix)) {
    final category = id.substring(kCategoryFanPrefix.length);
    if (category.isEmpty) return l.badgeCategoryAny;
    return l.localeName == 'ar'
        ? l.badgeCategoryFan(_categoriesAr[category] ?? valueLabel(category))
        : l.badgeCategoryFan(category);
  }
  return switch (id) {
    'attend_1' => l.badgeAttend1,
    'attend_10' => l.badgeAttend10,
    'attend_25' => l.badgeAttend25,
    'attend_50' => l.badgeAttend50,
    'host_1' => l.badgeHost1,
    'host_10' => l.badgeHost10,
    'host_25' => l.badgeHost25,
    'full_house' => l.badgeFullHouse,
    'variety_5' => l.badgeVariety5,
    'variety_10' => l.badgeVariety10,
    'variety_20' => l.badgeVariety20,
    'variety_30' => l.badgeVariety30,
    'friends_5' => l.badgeFriends5,
    'friends_15' => l.badgeFriends15,
    'friends_30' => l.badgeFriends30,
    'together_5' => l.badgeTogether5,
    'streak_3' => l.badgeStreak3,
    'streak_8' => l.badgeStreak8,
    'streak_20' => l.badgeStreak20,
    'streak_52' => l.badgeStreak52,
    'five_star' => l.badgeFiveStar,
    'rated_4_5' => l.badgeRated45,
    'rated_4_8' => l.badgeRated48,
    'rater_10' => l.badgeRater10,
    'early_bird' => l.badgeEarlyBird,
    'night_owl' => l.badgeNightOwl,
    'lucky_spot' => l.badgeLuckySpot,
    'weekend' => l.badgeWeekend,
    _ => l.badgesTitle,
  };
}

String badgeRule(AppLocalizations l, String id) {
  if (id.startsWith(kCategoryFanPrefix)) return l.badgeCategoryFanRule;
  return switch (id) {
    'attend_1' => l.badgeAttend1Rule,
    'attend_10' => l.badgeAttend10Rule,
    'attend_25' => l.badgeAttend25Rule,
    'attend_50' => l.badgeAttend50Rule,
    'host_1' => l.badgeHost1Rule,
    'host_10' => l.badgeHost10Rule,
    'host_25' => l.badgeHost25Rule,
    'full_house' => l.badgeFullHouseRule,
    'variety_5' => l.badgeVariety5Rule,
    'variety_10' => l.badgeVariety10Rule,
    'variety_20' => l.badgeVariety20Rule,
    'variety_30' => l.badgeVariety30Rule,
    'friends_5' => l.badgeFriends5Rule,
    'friends_15' => l.badgeFriends15Rule,
    'friends_30' => l.badgeFriends30Rule,
    'together_5' => l.badgeTogether5Rule,
    'streak_3' => l.badgeStreak3Rule,
    'streak_8' => l.badgeStreak8Rule,
    'streak_20' => l.badgeStreak20Rule,
    'streak_52' => l.badgeStreak52Rule,
    'five_star' => l.badgeFiveStarRule,
    'rated_4_5' => l.badgeRated45Rule,
    'rated_4_8' => l.badgeRated48Rule,
    'rater_10' => l.badgeRater10Rule,
    'early_bird' => l.badgeEarlyBirdRule,
    'night_owl' => l.badgeNightOwlRule,
    'lucky_spot' => l.badgeLuckySpotRule,
    'weekend' => l.badgeWeekendRule,
    _ => '',
  };
}

// The rule as something [name] did, for someone else's badge.
String badgeRuleBy(AppLocalizations l, String id, String name, String? gender) {
  final g = gender?.trim().toLowerCase() == 'female' ? 'female' : 'other';
  if (id.startsWith(kCategoryFanPrefix)) return l.badgeCategoryFanBy(name, g);
  return switch (id) {
    'attend_1' => l.badgeAttend1By(name, g),
    'attend_10' => l.badgeAttend10By(name, g),
    'attend_25' => l.badgeAttend25By(name, g),
    'attend_50' => l.badgeAttend50By(name, g),
    'host_1' => l.badgeHost1By(name, g),
    'host_10' => l.badgeHost10By(name, g),
    'host_25' => l.badgeHost25By(name, g),
    'full_house' => l.badgeFullHouseBy(name, g),
    'variety_5' => l.badgeVariety5By(name, g),
    'variety_10' => l.badgeVariety10By(name, g),
    'variety_20' => l.badgeVariety20By(name, g),
    'variety_30' => l.badgeVariety30By(name, g),
    'friends_5' => l.badgeFriends5By(name, g),
    'friends_15' => l.badgeFriends15By(name, g),
    'friends_30' => l.badgeFriends30By(name, g),
    'together_5' => l.badgeTogether5By(name, g),
    'streak_3' => l.badgeStreak3By(name, g),
    'streak_8' => l.badgeStreak8By(name, g),
    'streak_20' => l.badgeStreak20By(name, g),
    'streak_52' => l.badgeStreak52By(name, g),
    'five_star' => l.badgeFiveStarBy(name, g),
    'rated_4_5' => l.badgeRated45By(name, g),
    'rated_4_8' => l.badgeRated48By(name, g),
    'rater_10' => l.badgeRater10By(name, g),
    'early_bird' => l.badgeEarlyBirdBy(name, g),
    'night_owl' => l.badgeNightOwlBy(name, g),
    'lucky_spot' => l.badgeLuckySpotBy(name, g),
    'weekend' => l.badgeWeekendBy(name, g),
    _ => badgeRule(l, id),
  };
}

// "من أهل ..." needs the category with al-.
const Map<String, String> _categoriesAr = {
  'Padel': 'البادل',
  'Tennis': 'التنس',
  'Badminton': 'الريشة الطائرة',
  'Table Tennis': 'تنس الطاولة',
  'Football': 'كرة القدم',
  'Basketball': 'كرة السلة',
  'Volleyball': 'الكرة الطائرة',
  'Golf': 'الغولف',
  'Bowling': 'البولينغ',
  'Karting': 'الكارتينغ',
  'Martial Arts': 'الفنون القتالية',
  'Paintball': 'البينت بول',
  'Cycling': 'الدراجات',
  'Running': 'الجري',
  'Hiking': 'الهايكنغ',
  'Climbing': 'التسلق',
  'Camping': 'التخييم',
  'Desert Trips': 'الرحلات البرية',
  'Picnic': 'النزهات',
  'Fitness': 'اللياقة',
  'Yoga': 'اليوغا',
  'Swimming': 'السباحة',
  'Diving': 'الغوص',
  'Skating': 'التزلج',
  'Dance': 'الرقص',
  'Coffee': 'القهوة',
  'Cooking': 'الطبخ',
  'Food': 'الأكل',
  'Board Games': 'الألعاب اللوحية',
  'Chess': 'الشطرنج',
  'Escape Room': 'غرف الهروب',
  'Trivia': 'المسابقات',
  'Gaming': 'ألعاب الفيديو',
  'Movies': 'الأفلام',
  'Comedy': 'الكوميديا',
  'Karaoke': 'الكاريوكي',
  'Music': 'الموسيقى',
  'Art': 'الفن',
  'Pottery': 'الفخار',
  'Museums': 'المتاحف',
  'Books': 'الكتب',
  'Photography': 'التصوير',
  'Learning': 'التعلم',
  'Volunteering': 'التطوع',
  'Shopping': 'التسوق',
};
