import 'package:flutter_test/flutter_test.dart';
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
}
