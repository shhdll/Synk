import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/utils/add_to_calendar.dart';

void main() {
  Activity activity({
    String title = 'Padel night',
    String description = '',
    String location = 'Granada Mall',
    String? address,
    DateTime? start,
    DateTime? end,
  }) {
    return Activity(
      id: 'a1',
      title: title,
      description: description,
      dateTime: start ?? DateTime(2026, 11, 23, 18),
      endsAt: end,
      location: location,
      locationAddress: address,
    );
  }

  group('calendarEventFor', () {
    test('uses the activity title and times', () {
      final event = calendarEventFor(
        activity(
          start: DateTime(2026, 11, 23, 18),
          end: DateTime(2026, 11, 23, 20),
        ),
      );

      expect(event.title, 'Padel night');
      expect(event.startDate, DateTime(2026, 11, 23, 18));
      expect(event.endDate, DateTime(2026, 11, 23, 20));
      expect(event.allDay, isFalse);
    });

    test('puts the place name before its address', () {
      final event = calendarEventFor(
        activity(address: 'Eastern Ring Branch Rd, Riyadh'),
      );

      expect(event.location, 'Granada Mall, Eastern Ring Branch Rd, Riyadh');
    });

    test('does not repeat an address that matches the place name', () {
      final event = calendarEventFor(activity(address: 'Granada Mall'));

      expect(event.location, 'Granada Mall');
    });

    test('leaves out an empty description', () {
      expect(calendarEventFor(activity(description: '  ')).description, isNull);
      expect(
        calendarEventFor(activity(description: 'Bring water')).description,
        'Bring water',
      );
    });

    test('keeps server times in the phone\'s local time', () {
      final start = DateTime(2026, 11, 23, 18);
      final event = calendarEventFor(
        activity(
          start: start.toUtc(),
          end: start.add(const Duration(hours: 2)).toUtc(),
        ),
      );

      expect(event.startDate, start);
      expect(event.startDate.isUtc, isFalse);
    });

    test('reminds an hour before on iPhone', () {
      expect(
        calendarEventFor(activity()).iosParams.reminder,
        const Duration(hours: 1),
      );
    });
  });

  group('CalendarAdds', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    const adds = CalendarAdds();
    final now = DateTime(2026, 11, 20);
    final start = DateTime(2026, 11, 23, 18);
    final end = DateTime(2026, 11, 23, 20);
    Activity at(DateTime s, DateTime e) => activity(start: s, end: e);

    test('says nothing for an activity never added', () async {
      expect(await adds.isOutdated(at(start, end)), isFalse);
    });

    test('says nothing when the time has not changed', () async {
      await adds.remember(at(start, end), now: now);
      expect(await adds.isOutdated(at(start, end)), isFalse);
    });

    test('spots a new start time', () async {
      await adds.remember(at(start, end), now: now);
      const hour = Duration(hours: 1);
      expect(await adds.isOutdated(at(start.add(hour), end.add(hour))), isTrue);
    });

    test('spots a new end time', () async {
      await adds.remember(at(start, end), now: now);
      final later = end.add(const Duration(minutes: 30));
      expect(await adds.isOutdated(at(start, later)), isTrue);
    });

    test('adding again with the new time clears it', () async {
      await adds.remember(at(start, end), now: now);
      const day = Duration(days: 1);
      final moved = at(start.add(day), end.add(day));
      await adds.remember(moved, now: now);
      expect(await adds.isOutdated(moved), isFalse);
    });

    test('forgets activities that have started', () async {
      await adds.remember(at(start, end), now: now);
      // Saving another after the first started drops the first.
      await adds.remember(
        Activity(
          id: 'later',
          title: 'Later',
          dateTime: DateTime(2026, 12, 1),
          location: 'Riyadh',
        ),
        now: DateTime(2026, 11, 24),
      );
      final moved = at(start.add(const Duration(hours: 1)), end);
      expect(await adds.isOutdated(moved), isFalse);
    });

    test('ignores saved data it cannot read', () async {
      SharedPreferences.setMockInitialValues({'calendar_adds': 'not json'});
      expect(await adds.isOutdated(at(start, end)), isFalse);
    });
  });
}
