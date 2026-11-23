import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_model.dart';

// What goes into the calendar for an activity.
class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.startDate,
    required this.endDate,
    this.description,
    this.location,
    this.reminder,
  });

  final String title;
  final String? description;
  final String? location;
  final DateTime startDate;
  final DateTime endDate;

  // iPhone only: an alert this long before it starts.
  final Duration? reminder;

  Map<String, Object?> toMap() => {
    'title': title,
    'description': description,
    'location': location,
    'start': startDate.millisecondsSinceEpoch,
    'end': endDate.millisecondsSinceEpoch,
    'reminderMinutes': reminder?.inMinutes,
  };
}

// The calendar event for an activity: its title, start and end, place,
// and description. The place name comes first, then its address.
CalendarEvent calendarEventFor(Activity activity) {
  final place = activity.location.trim();
  final address = activity.locationAddress?.trim() ?? '';
  final location = [
    if (place.isNotEmpty) place,
    if (address.isNotEmpty && address != place) address,
  ].join(', ');
  final description = activity.description.trim();

  return CalendarEvent(
    title: activity.title,
    description: description.isEmpty ? null : description,
    location: location.isEmpty ? null : location,
    startDate: activity.dateTime.toLocal(),
    endDate: activity.endsAt.toLocal(),
    reminder: const Duration(hours: 1),
  );
}

// What happened after asking to add an activity to the calendar.
enum CalendarOutcome {
  // The user saved it.
  saved,
  // Android without calendar access: the calendar opened, but there's no
  // way to tell whether it was saved.
  opened,
  // The user closed the calendar without saving.
  cancelled,
  // iPhone before iOS 17: calendar access was refused.
  denied,
  // No calendar app, nothing to show it on, or already opening.
  unavailable,
}

// Whether an activity was added to the calendar on this phone.
enum CalendarState {
  notAdded,
  // Added with the times it has now; adding again would make a duplicate.
  added,
  // Added, but the host has changed the time since.
  outdated,
}

const _calendar = MethodChannel('synk/calendar');

// Opens the phone's calendar with the activity filled in, so the user only
// has to save it, and says whether they did. Our own code on both phones
// (AppDelegate.swift, MainActivity.kt): the iPhone one shows Apple's
// editor, the Android one checks the calendar after it closes.
Future<CalendarOutcome> addActivityToCalendar(Activity activity) async {
  try {
    final outcome = await _calendar.invokeMethod<String>(
      'add',
      calendarEventFor(activity).toMap(),
    );
    return switch (outcome) {
      'saved' => CalendarOutcome.saved,
      'opened' => CalendarOutcome.opened,
      'cancelled' => CalendarOutcome.cancelled,
      'denied' => CalendarOutcome.denied,
      _ => CalendarOutcome.unavailable,
    };
  } catch (_) {
    return CalendarOutcome.unavailable;
  }
}

// Remembers, on this phone, the times of activities the user added to
// their calendar, so the details sheet can say when the host has changed
// them since. Errors are ignored: it's only a reminder.
class CalendarAdds {
  const CalendarAdds();

  static const _key = 'calendar_adds';

  // Activities that have started are dropped when saving, so the list
  // doesn't grow forever.
  Future<void> remember(Activity activity, {DateTime? now}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = _read(prefs);
      final at = now ?? DateTime.now();
      saved.removeWhere((_, times) => !times.$1.isAfter(at));
      saved[activity.id] = (activity.dateTime, activity.endsAt);
      await prefs.setString(
        _key,
        jsonEncode({
          for (final MapEntry(:key, :value) in saved.entries)
            key: [
              value.$1.millisecondsSinceEpoch,
              value.$2.millisecondsSinceEpoch,
            ],
        }),
      );
    } catch (_) {}
  }

  // Whether [activity] is in the calendar, and with its current times.
  Future<CalendarState> stateOf(Activity activity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final times = _read(prefs)[activity.id];
      if (times == null) return CalendarState.notAdded;
      final same =
          times.$1.isAtSameMomentAs(activity.dateTime) &&
          times.$2.isAtSameMomentAs(activity.endsAt);
      return same ? CalendarState.added : CalendarState.outdated;
    } catch (_) {
      return CalendarState.notAdded;
    }
  }

  // True when [activity] was added to the calendar with a different start
  // or end than it has now.
  Future<bool> isOutdated(Activity activity) async =>
      await stateOf(activity) == CalendarState.outdated;

  static Map<String, (DateTime, DateTime)> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    final saved = <String, (DateTime, DateTime)>{};
    for (final MapEntry(:key, :value) in decoded.entries) {
      if (key is String && value is List && value.length == 2) {
        final [start, end] = value;
        if (start is int && end is int) {
          saved[key] = (
            DateTime.fromMillisecondsSinceEpoch(start),
            DateTime.fromMillisecondsSinceEpoch(end),
          );
        }
      }
    }
    return saved;
  }
}
