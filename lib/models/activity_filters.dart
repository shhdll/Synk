import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/constants/activity_categories.dart';
import 'activity_model.dart';

typedef GeoPoint = ({double latitude, double longitude});

// Opposite pairs, one per row in the sheet.
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

// [startHour, endHour)
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

  bool get isSingleCount => this == oneLeft || this == full;
}

// Immutable so the sheet can edit a draft copy.
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
  final DateTime? customDate;
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
      customDate == null ? null : formatShortDate(customDate!),
    _ => date.label,
  };

  String? get timeLabel {
    if (daySlot != null) return daySlot!.label;
    if (fromMinute != null) return 'From ${formatMinute(fromMinute!)}';
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
        sortBy((a) => a.spotsOpen);
      case SortOption.mostSpots:
        sortBy((a) => a.spotsOpen, descending: true);
    }

    return result;
  }

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
    return keywords.any(
      (k) => RegExp('\\b${RegExp.escape(k)}').hasMatch(text),
    );
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

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String formatShortDate(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';

String formatMinute(int minuteOfDay) {
  final hour = minuteOfDay ~/ 60;
  final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12:$minute ${hour < 12 ? 'AM' : 'PM'}';
}

String shortWeekday(DateTime date) => _weekdays[date.weekday - 1];
