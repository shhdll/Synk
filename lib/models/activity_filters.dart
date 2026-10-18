import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/constants/activity_categories.dart';
import 'activity_model.dart';

typedef GeoPoint = ({double latitude, double longitude});

// Listed in opposite pairs; the sheet shows one pair per row.
enum SortOption {
  soonest('Soonest'),
  latest('Latest'),
  nearest('Nearest'),
  farthest('Farthest'),
  almostFull('Almost full'),
  mostSpots('Most spots');

  const SortOption(this.label);
  final String label;

  bool get needsLocation => this == nearest || this == farthest;

  // Orders by open spots, so it has nothing to sort when the Spots filter
  // leaves a single count ([SpotsOption.isSingleCount]).
  bool get bySpots => this == almostFull || this == mostSpots;
}

enum DateOption {
  any('Any'),
  today('Today'),
  tomorrow('Tomorrow'),
  custom('Pick a date');

  const DateOption(this.label);
  final String label;
}

// Parts of the day, by the hour an activity starts ([startHour, endHour)).
enum DaySlot {
  morning('Morning', '6 AM–12 PM', 6, 12),
  evening('Evening', '5–9 PM', 17, 21),
  night('Night', '9 PM–12 AM', 21, 24);

  const DaySlot(this.label, this.hours, this.startHour, this.endHour);
  final String label;
  final String hours;
  final int startHour;
  final int endHour;

  bool contains(DateTime time) => time.hour >= startHour && time.hour < endHour;
}

enum DistanceOption {
  any('Any', null),
  within5('5 km', 5),
  within10('10 km', 10),
  within25('25 km', 25);

  const DistanceOption(this.label, this.maxKm);
  final String label;
  final double? maxKm;
}

enum SpotsOption {
  any('Any'),
  oneLeft('1 left'),
  hasSpots('Has spots'),
  full('Full');

  const SpotsOption(this.label);
  final String label;

  // Every match has the same number of open spots, so the spots sorts
  // ([SortOption.bySpots]) can't be combined with it.
  bool get isSingleCount => this == oneLeft || this == full;
}

// Every advanced filter for the discovery feed. Immutable, so the filter
// sheet can edit a draft copy and only replace the applied one on "Show".
// The same [apply] produces both the home list and the sheet's live count.
@immutable
class ActivityFilters {
  const ActivityFilters({
    this.sort = SortOption.soonest,
    this.date = DateOption.any,
    this.customDate,
    this.daySlot,
    this.fromMinute,
    this.categories = const {},
    this.distance = DistanceOption.any,
    this.spots = SpotsOption.any,
  });

  static const ActivityFilters defaults = ActivityFilters();

  final SortOption sort;
  final DateOption date;
  // Set only when [date] is [DateOption.custom].
  final DateTime? customDate;
  // Time of day: one slot, or a picked start time ([fromMinute] minutes
  // after midnight; matches activities starting then or later). At most
  // one is set; neither means any time.
  final DaySlot? daySlot;
  final int? fromMinute;
  // Empty means all categories.
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
      daySlot: daySlot,
      fromMinute: fromMinute,
      categories: categories ?? this.categories,
      distance: distance ?? this.distance,
      spots: spots ?? this.spots,
    );
  }

  ActivityFilters withDate(DateOption date, {DateTime? customDate}) {
    return ActivityFilters(
      sort: sort,
      date: date,
      customDate: date == DateOption.custom ? customDate : null,
      daySlot: daySlot,
      fromMinute: fromMinute,
      categories: categories,
      distance: distance,
      spots: spots,
    );
  }

  // Sets the time of day to [slot] or to "from [fromMinute]"; passing
  // neither clears it.
  ActivityFilters withTime({DaySlot? slot, int? fromMinute}) {
    return ActivityFilters(
      sort: sort,
      date: date,
      customDate: customDate,
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

  // How many of the six sheet sections differ from their defaults; shown
  // on the filter button badge.
  int get changedSectionCount {
    var count = 0;
    if (sort != defaults.sort) count++;
    if (date != defaults.date) count++;
    if (hasTime) count++;
    if (categories.isNotEmpty) count++;
    if (distance != defaults.distance) count++;
    if (spots != defaults.spots) count++;
    return count;
  }

  bool get isDefault => changedSectionCount == 0;

  // Days the date filter covers, as [start, end) local midnights.
  // Null means any date.
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
        return (start, DateTime(start.year, start.month, start.day + 1));
    }
  }

  bool coversDay(DateTime day, DateTime now) {
    final range = dateRange(now);
    if (range == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(range.$1) && d.isBefore(range.$2);
  }

  // The single day selected, if the date filter covers exactly one.
  DateTime? singleDay(DateTime now) {
    final range = dateRange(now);
    if (range == null) return null;
    final (start, end) = range;
    final next = DateTime(start.year, start.month, start.day + 1);
    return next == end ? start : null;
  }

  // "Today", "Tue, Oct 20", or null for any date.
  String? get dateLabel => switch (date) {
    DateOption.any => null,
    DateOption.custom =>
      customDate == null ? null : formatShortDate(customDate!),
    _ => date.label,
  };

  // "Evening", "From 7:30 PM", or null for any time.
  String? get timeLabel {
    if (daySlot != null) return daySlot!.label;
    if (fromMinute != null) return 'From ${formatMinute(fromMinute!)}';
    return null;
  }

  // Filters and sorts [activities]. [search] is the home search bar text;
  // Nearest, Farthest and Distance measure from [userLocation].
  List<Activity> apply(
    Iterable<Activity> activities, {
    GeoPoint? userLocation,
    String search = '',
    DateTime? now,
  }) {
    final range = dateRange(now ?? DateTime.now());
    final from = userLocation;
    final maxKm = from == null ? null : distance.maxKm;
    final query = search.trim().toLowerCase();

    final distances = <String, double>{};
    double? kmTo(Activity activity) {
      if (from == null || !activity.hasCoordinates) return null;
      return distances[activity.id] ??= distanceKm(
        from,
        (latitude: activity.latitude!, longitude: activity.longitude!),
      );
    }

    final result = activities.where((activity) {
      if (query.isNotEmpty && !matchesSearch(activity, query)) return false;

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

      // Almost full is about activities you can still join.
      if (sort == SortOption.almostFull && activity.spotsOpen < 1) {
        return false;
      }

      return true;
    }).toList();

    int bySoonest(Activity a, Activity b) => a.dateTime.compareTo(b.dateTime);

    // Sorts by [key], soonest first on ties. Activities without a key
    // (no coordinates) always go last.
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

    switch (sort) {
      case SortOption.soonest:
        result.sort(bySoonest);
      case SortOption.latest:
        result.sort((a, b) => bySoonest(b, a));
      case SortOption.nearest:
        from == null ? result.sort(bySoonest) : sortBy(kmTo);
      case SortOption.farthest:
        from == null ? result.sort(bySoonest) : sortBy(kmTo, descending: true);
      case SortOption.almostFull:
        // Fewest open spots first; full ones were filtered out above.
        sortBy((a) => a.spotsOpen);
      case SortOption.mostSpots:
        sortBy((a) => a.spotsOpen, descending: true);
    }

    return result;
  }

  // Title, description, location (name or address) or category label.
  static bool matchesSearch(Activity activity, String lowerQuery) {
    final searchable = [
      activity.title,
      activity.description,
      activity.location,
      activity.locationAddress ?? '',
      activity.categoryLabel,
    ];
    return searchable.any((field) => field.toLowerCase().contains(lowerQuery));
  }

  // Activities have no stored category yet, so a category also matches
  // when one of its keywords (kActivityCategories) starts a word in the
  // title or description. Unlisted names match themselves, with plurals
  // matching their singular. [kOtherCategory] is everything else.
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
    return keywords.any(
      (k) => RegExp('\\b${RegExp.escape(k)}').hasMatch(text),
    );
  }

  // Straight-line (great-circle) distance in kilometers.
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

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// "Tue, Oct 20".
String formatShortDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';

// "7:30 PM" for [minuteOfDay] minutes after midnight.
String formatMinute(int minuteOfDay) {
  final hour = minuteOfDay ~/ 60;
  final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12:$minute ${hour < 12 ? 'AM' : 'PM'}';
}

String shortWeekday(DateTime date) => _weekdays[date.weekday - 1];
