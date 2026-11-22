import 'package:add_2_calendar/add_2_calendar.dart';

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
