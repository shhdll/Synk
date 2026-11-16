import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/activity_categories.dart';
import '../core/constants/badges.dart';

class EarnedBadge {
  const EarnedBadge({
    required this.id,
    required this.earnedAt,
    this.seen = true,
  });

  final String id;
  final DateTime earnedAt;
  final bool seen;
}

class MyBadges {
  const MyBadges({required this.earned, required this.stats});

  static const MyBadges empty = MyBadges(earned: [], stats: {});

  // Newest first.
  final List<EarnedBadge> earned;
  final Map<String, dynamic> stats;

  List<EarnedBadge> get unseen => [
    for (final badge in earned)
      if (!badge.seen) badge,
  ];

  bool has(String id) => earned.any((badge) => badge.id == id);

  int progressOf(BadgeInfo badge) {
    final stat = badge.stat;
    if (stat == null) return has(badge.id) ? 1 : 0;
    return (stats[stat] as num?)?.toInt() ?? 0;
  }

  // Activities in the user's most attended category, for the category badge.
  int get bestCategoryCount {
    final counts = stats['category_counts'];
    if (counts is! Map) return 0;
    var best = 0;
    for (final MapEntry(:key, :value) in counts.entries) {
      if (!kActivityCategories.containsKey(key)) continue;
      if (value is num && value > best) best = value.toInt();
    }
    return best;
  }
}

// Badges (supabase/migrations/20261114200000_badges.sql).
class BadgesModel {
  BadgesModel({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  // Also gives any badge earned since the last check.
  Future<MyBadges> fetchMine() async {
    final result = await _supabase.rpc('get_my_badges');
    if (result is! Map) return MyBadges.empty;
    final rows = result['badges'];
    return MyBadges(
      earned: [
        if (rows is List)
          for (final row in rows)
            if (row is Map && _known(row['id'] as String?))
              EarnedBadge(
                id: row['id'] as String,
                earnedAt: DateTime.parse(row['earned_at'] as String),
                seen: row['seen'] == true,
              ),
      ],
      stats: Map<String, dynamic>.from(
        result['stats'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  // Someone else's earned badges, newest first. Empty across a block.
  Future<List<EarnedBadge>> fetchFor(String userId) async {
    final rows = await _supabase.rpc(
      'get_user_badges',
      params: {'target_user_id': userId},
    );
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map && _known(row['badge_id'] as String?))
          EarnedBadge(
            id: row['badge_id'] as String,
            earnedAt: DateTime.parse(row['earned_at'] as String),
          ),
    ];
  }

  Future<void> markSeen() => _supabase.rpc('mark_badges_seen');

  // Skips ids this version of the app doesn't know, and category badges for
  // labels that aren't one of the app's categories.
  static bool _known(String? id) {
    if (id == null) return false;
    if (id.startsWith(kCategoryFanPrefix)) {
      return kActivityCategories.containsKey(
        id.substring(kCategoryFanPrefix.length),
      );
    }
    return badgeInfo(id) != null;
  }
}
