import 'dart:math' as math;

import 'activity_model.dart';
import 'top_picks.dart';

// When the user wants to go, in Surprise Me's filter.
enum SurpriseTime { any, today, thisWeek }

// Indoors, outdoors or either, in Surprise Me's filter.
enum SurpriseSetting { any, indoor, outdoor }

// Surprise Me's optional filter. Starts as "any" every time it opens.
class SurpriseFilter {
  const SurpriseFilter({
    this.time = SurpriseTime.any,
    this.setting = SurpriseSetting.any,
  });

  static const none = SurpriseFilter();

  final SurpriseTime time;
  final SurpriseSetting setting;

  bool get isActive =>
      time != SurpriseTime.any || setting != SurpriseSetting.any;

  SurpriseFilter copyWith({SurpriseTime? time, SurpriseSetting? setting}) =>
      SurpriseFilter(time: time ?? this.time, setting: setting ?? this.setting);

  bool matches(Activity activity, DateTime now) {
    final start = activity.dateTime.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final fitsTime = switch (time) {
      SurpriseTime.any => true,
      SurpriseTime.today =>
        !start.isBefore(today) &&
            start.isBefore(today.add(const Duration(days: 1))),
      // Weeks run Sunday to Saturday, as for the streak.
      SurpriseTime.thisWeek => start.isBefore(
        today.add(Duration(days: 7 - today.weekday % 7)),
      ),
    };
    final fitsSetting = switch (setting) {
      SurpriseSetting.any => true,
      SurpriseSetting.indoor => activity.setting == ActivitySetting.indoor,
      SurpriseSetting.outdoor => activity.setting == ActivitySetting.outdoor,
    };
    return fitsTime && fitsSetting;
  }
}

// Picks a random activity from [ranked] (rankTopPicks with no limit, so
// past, full, hosted and already joined activities are already out).
// Leaves out what doesn't fit [filter] and what [clashes] with the user's
// plans. Every activity can come up, but ones that suit the user (a higher
// top-picks score) are more likely. Null when nothing fits.
Activity? pickSurprise({
  required List<TopPick> ranked,
  SurpriseFilter filter = SurpriseFilter.none,
  bool Function(Activity activity)? clashes,
  String? avoidId,
  math.Random? random,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  var options = [
    for (final pick in ranked)
      if (pick.activity.dateTime.isAfter(at) &&
          filter.matches(pick.activity, at) &&
          !(clashes?.call(pick.activity) ?? false))
        pick,
  ];
  // "Shuffle again" shows something new when there's anything else.
  if (avoidId != null && options.length > 1) {
    options = [
      for (final pick in options)
        if (pick.activity.id != avoidId) pick,
    ];
  }
  if (options.isEmpty) return null;

  final weights = [for (final pick in options) 1 + math.max(0.0, pick.score)];
  final total = weights.fold(0.0, (sum, w) => sum + w);
  var roll = (random ?? math.Random()).nextDouble() * total;
  for (var i = 0; i < options.length; i++) {
    roll -= weights[i];
    if (roll < 0) return options[i].activity;
  }
  return options.last.activity;
}
