import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/constants/activity_categories.dart';
import '../l10n/l10n.dart';
import '../utils/fuzzy_search.dart';
import 'activity_model.dart';

export '../l10n/l10n.dart' show formatMonthDay, formatShortDate;

typedef GeoPoint = ({double latitude, double longitude});

// Opposite pairs, one per row in the sheet.
enum SortOption {
  soonest,
  latest,
  nearest,
  farthest,
  almostFull,
  mostSpots;

  String get label => switch (this) {
    soonest => appL10n.soonest,
    latest => appL10n.latest,
    nearest => appL10n.nearest,
    farthest => appL10n.farthest,
    almostFull => appL10n.almostFull,
    mostSpots => appL10n.mostSpots,
  };

  bool get needsLocation => this == nearest || this == farthest;

  bool get bySpots => this == almostFull || this == mostSpots;
}

enum DateOption {
  any,
  today,
  tomorrow,
  custom;

  String get label => switch (this) {
    any => appL10n.any,
    today => appL10n.today,
    tomorrow => appL10n.tomorrow,
    custom => appL10n.pickADate,
  };
}

// [startHour, endHour)
enum DaySlot {
  morning(6, 12),
  evening(12, 21),
  night(21, 24);

  const DaySlot(this.startHour, this.endHour);
  final int startHour;
  final int endHour;

  String get label => switch (this) {
    morning => appL10n.morning,
    evening => appL10n.evening,
    night => appL10n.night,
  };

  String get hours => switch (this) {
    morning => appL10n.slotMorningHours,
    evening => appL10n.slotEveningHours,
    night => appL10n.slotNightHours,
  };

  bool contains(DateTime time) => time.hour >= startHour && time.hour < endHour;
}

enum DistanceOption {
  any(null),
  within5(5),
  within10(10),
  within25(25);

  const DistanceOption(this.maxKm);
  final double? maxKm;

  String get label =>
      maxKm == null ? appL10n.any : appL10n.distanceKm(maxKm!.round());
}

enum SpotsOption {
  any,
  oneLeft,
  hasSpots,
  full;

  String get label => switch (this) {
    any => appL10n.any,
    oneLeft => appL10n.oneLeft,
    hasSpots => appL10n.hasSpots,
    full => appL10n.full,
  };

  bool get isSingleCount => this == oneLeft || this == full;
}

// Immutable so the sheet can edit a draft copy.
@immutable
class ActivityFilters {
  const ActivityFilters({
    this.sort,
    this.date = DateOption.any,
    this.customDate,
    this.customEndDate,
    this.daySlot,
    this.fromMinute,
    this.categories = const {},
    this.distance = DistanceOption.any,
    this.spots = SpotsOption.any,
  });

  static const ActivityFilters defaults = ActivityFilters();

  // null until the user picks one; the list is then shown soonest first.
  final SortOption? sort;
  final DateOption date;
  final DateTime? customDate;
  // Last day when the picked date is a range; null for a single day.
  final DateTime? customEndDate;
  // Either a slot or a start time, never both.
  final DaySlot? daySlot;
  final int? fromMinute;
  // Empty = all.
  final Set<String> categories;
  final DistanceOption distance;
  final SpotsOption spots;

  ActivityFilters copyWith({
    SortOption? sort,
    Set<String>? categories,
    DistanceOption? distance,
    SpotsOption? spots,
  }) {
    return ActivityFilters(
      sort: sort ?? this.sort,
      date: date,
      customDate: customDate,
      customEndDate: customEndDate,
      daySlot: daySlot,
      fromMinute: fromMinute,
      categories: categories ?? this.categories,
      distance: distance ?? this.distance,
      spots: spots ?? this.spots,
    );
  }

  // Unlike copyWith, this can clear the sort back to null.
  ActivityFilters withSort(SortOption? sort) {
    return ActivityFilters(
      sort: sort,
      date: date,
      customDate: customDate,
      customEndDate: customEndDate,
      daySlot: daySlot,
      fromMinute: fromMinute,
      categories: categories,
      distance: distance,
      spots: spots,
    );
  }

  ActivityFilters withDate(
    DateOption date, {
    DateTime? customDate,
    DateTime? customEndDate,
  }) {
    final isCustom = date == DateOption.custom;
    return ActivityFilters(
      sort: sort,
      date: date,
      customDate: isCustom ? customDate : null,
      customEndDate: isCustom ? customEndDate : null,
      daySlot: daySlot,
      fromMinute: fromMinute,
      categories: categories,
      distance: distance,
      spots: spots,
    );
  }

  ActivityFilters withTime({DaySlot? slot, int? fromMinute}) {
    return ActivityFilters(
      sort: sort,
      date: date,
      customDate: customDate,
      customEndDate: customEndDate,
      daySlot: slot,
      fromMinute: slot == null ? fromMinute : null,
      categories: categories,
      distance: distance,
      spots: spots,
    );
  }

  ActivityFilters toggleCategory(String category) {
    final next = {...categories};
    if (!next.remove(category)) next.add(category);
    return copyWith(categories: next);
  }

  bool get hasTime => daySlot != null || fromMinute != null;

  int get changedSectionCount {
    var count = 0;
    if (sort != null) count++;
    if (date != defaults.date) count++;
    if (hasTime) count++;
    if (categories.isNotEmpty) count++;
    if (distance != defaults.distance) count++;
    if (spots != defaults.spots) count++;
    return count;
  }

  bool get isDefault => changedSectionCount == 0;

  (DateTime, DateTime)? dateRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    DateTime day(int offset) =>
        DateTime(today.year, today.month, today.day + offset);

    switch (date) {
      case DateOption.any:
        return null;
      case DateOption.today:
        return (today, day(1));
      case DateOption.tomorrow:
        return (day(1), day(2));
      case DateOption.custom:
        final picked = customDate;
        if (picked == null) return null;
        final start = DateTime(picked.year, picked.month, picked.day);
        final last = customEndDate ?? start;
        return (start, DateTime(last.year, last.month, last.day + 1));
    }
  }

  bool coversDay(DateTime day, DateTime now) {
    final range = dateRange(now);
    if (range == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(range.$1) && d.isBefore(range.$2);
  }

  DateTime? singleDay(DateTime now) {
    final range = dateRange(now);
    if (range == null) return null;
    final (start, end) = range;
    final next = DateTime(start.year, start.month, start.day + 1);
    return next == end ? start : null;
  }

  String? get dateLabel => switch (date) {
    DateOption.any => null,
    DateOption.custom =>
      customDate == null
          ? null
          : customEndDate == null || customEndDate == customDate
          ? formatShortDate(customDate!)
          : '${formatMonthDay(customDate!)} – ${formatMonthDay(customEndDate!)}',
    _ => date.label,
  };

  String? get timeLabel {
    if (daySlot != null) return daySlot!.label;
    if (fromMinute != null) return appL10n.fromTime(formatMinute(fromMinute!));
    return null;
  }

  List<Activity> apply(
    Iterable<Activity> activities, {
    GeoPoint? userLocation,
    String search = '',
    DateTime? now,
  }) {
    final range = dateRange(now ?? DateTime.now());
    final from = userLocation;
    final maxKm = from == null ? null : distance.maxKm;
    final query = search.trim();

    // How closely each activity matches the search; lower is better.
    final searchScores = <String, int>{};

    final distances = <String, double>{};
    double? kmTo(Activity activity) {
      if (from == null || !activity.hasCoordinates) return null;
      return distances[activity.id] ??= distanceKm(from, (
        latitude: activity.latitude!,
        longitude: activity.longitude!,
      ));
    }

    final result = activities.where((activity) {
      if (query.isNotEmpty) {
        final score = searchScore(activity, query);
        if (score == null) return false;
        searchScores[activity.id] = score;
      }

      final start = activity.dateTime;
      if (range != null &&
          (start.isBefore(range.$1) || !start.isBefore(range.$2))) {
        return false;
      }

      if (daySlot != null && !daySlot!.contains(start)) return false;
      if (fromMinute != null && start.hour * 60 + start.minute < fromMinute!) {
        return false;
      }

      if (categories.isNotEmpty &&
          !categories.any((c) => matchesCategory(activity, c))) {
        return false;
      }

      if (maxKm != null) {
        final km = kmTo(activity);
        if (km == null || km > maxKm) return false;
      }

      switch (spots) {
        case SpotsOption.any:
          break;
        case SpotsOption.oneLeft:
          if (activity.spotsOpen != 1) return false;
        case SpotsOption.hasSpots:
          if (activity.spotsOpen < 1) return false;
        case SpotsOption.full:
          if (activity.spotsOpen > 0) return false;
      }

      if (sort == SortOption.almostFull && activity.spotsOpen < 1) {
        return false;
      }

      return true;
    }).toList();

    int bySoonest(Activity a, Activity b) => a.dateTime.compareTo(b.dateTime);

    // Ties go to the soonest, missing keys last.
    void sortBy(num? Function(Activity) key, {bool descending = false}) {
      result.sort((a, b) {
        final ka = key(a);
        final kb = key(b);
        if (ka == null || kb == null) {
          if (ka != kb) return ka == null ? 1 : -1;
          return bySoonest(a, b);
        }
        final byKey = descending ? kb.compareTo(ka) : ka.compareTo(kb);
        return byKey != 0 ? byKey : bySoonest(a, b);
      });
    }

    // While searching with no sort picked, the closest matches come first.
    if (query.isNotEmpty && sort == null) {
      sortBy((a) => searchScores[a.id]);
      return result;
    }

    switch (sort ?? SortOption.soonest) {
      case SortOption.soonest:
        result.sort(bySoonest);
      case SortOption.latest:
        result.sort((a, b) => bySoonest(b, a));
      case SortOption.nearest:
        from == null ? result.sort(bySoonest) : sortBy(kmTo);
      case SortOption.farthest:
        from == null ? result.sort(bySoonest) : sortBy(kmTo, descending: true);
      case SortOption.almostFull:
        sortBy((a) => a.spotsOpen);
      case SortOption.mostSpots:
        sortBy((a) => a.spotsOpen, descending: true);
    }

    return result;
  }

  // How well [activity] matches a search, forgiving typos and unfinished
  // words; null when it doesn't match. Lower is better.
  static int? searchScore(Activity activity, String query) {
    return FuzzySearch.score(
      query,
      title: activity.title,
      primary: [activity.location, activity.categoryLabel],
      secondary: [activity.locationAddress ?? ''],
      loose: [activity.description],
    );
  }

  // No stored category yet, so match keywords in the title/description.
  static bool matchesCategory(Activity activity, String category) {
    final wanted = category.trim().toLowerCase();
    final label = activity.categoryLabel.trim().toLowerCase();
    if (label == wanted) return true;

    if (category == kOtherCategory) {
      return label.isEmpty &&
          !kActivityCategories.keys.any((c) => matchesCategory(activity, c));
    }

    final stem = wanted.length > 3 && wanted.endsWith('s')
        ? wanted.substring(0, wanted.length - 1)
        : wanted;
    final keywords = kActivityCategories[category] ?? [stem];
    final text = '${activity.title} ${activity.description}'.toLowerCase();
    return keywords.any((k) => RegExp('\\b${RegExp.escape(k)}').hasMatch(text));
  }

  static double distanceKm(GeoPoint a, GeoPoint b) {
    const earthRadiusKm = 6371.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLng = rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.latitude)) *
            math.cos(rad(b.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(h));
  }
}

String formatMinute(int minuteOfDay) =>
    formatTime(minuteOfDay ~/ 60, minuteOfDay % 60);

String shortWeekday(DateTime date) => weekdayShort(date);
