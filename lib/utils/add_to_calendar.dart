import 'dart:convert';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_model.dart';

// The calendar event for an activity: its title, start and end, place,
// and description. The place name comes first, then its address.
Event calendarEventFor(Activity activity) {
  final place = activity.location.trim();
  final address = activity.locationAddress?.trim() ?? '';
  final location = [
    if (place.isNotEmpty) place,
    if (address.isNotEmpty && address != place) address,
  ].join(', ');
  final description = activity.description.trim();

  return Event(
    title: activity.title,
    description: description.isEmpty ? null : description,
    location: location.isEmpty ? null : location,
    startDate: activity.dateTime.toLocal(),
    endDate: activity.endsAt.toLocal(),
    iosParams: const IOSParams(reminder: Duration(hours: 1)),
  );
}

// Opens the phone's calendar app with the activity filled in, so the user
// only has to save it. False when there's no calendar app to open.
Future<bool> addActivityToCalendar(Activity activity) async {
  try {
    return await Add2Calendar.addEvent2Cal(calendarEventFor(activity));
  } catch (_) {
    return false;
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

  // True when [activity] was added to the calendar with a different start
  // or end than it has now.
  Future<bool> isOutdated(Activity activity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final times = _read(prefs)[activity.id];
      if (times == null) return false;
      return !times.$1.isAtSameMomentAs(activity.dateTime) ||
          !times.$2.isAtSameMomentAs(activity.endsAt);
    } catch (_) {
      return false;
    }
  }

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
