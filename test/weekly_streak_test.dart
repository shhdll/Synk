import 'package:flutter_test/flutter_test.dart';
import 'package:synk/models/activity_model.dart';

void main() {
  // Wednesday 4 Nov 2026, 18:00. Its week runs Sun 1 Nov - Sat 7 Nov.
  final now = DateTime(2026, 11, 4, 18);

  WeeklyStreak streakOf(List<DateTime> attended, {DateTime? at}) =>
      WeeklyStreak.from(attended, now: at ?? now);

  group('WeeklyStreak.from', () {
    test('is zero with no activities', () {
      expect(streakOf([]), WeeklyStreak.none);
    });

    test('counts one week when attended this week', () {
      expect(
        streakOf([DateTime(2026, 11, 2, 20)]),
        const WeeklyStreak(weeks: 1, attendedThisWeek: true),
      );
    });

    test('counts consecutive weeks', () {
      expect(
        streakOf([
          DateTime(2026, 11, 3), // this week
          DateTime(2026, 10, 27), // last week
          DateTime(2026, 10, 20), // 2 weeks ago
        ]),
        const WeeklyStreak(weeks: 3, attendedThisWeek: true),
      );
    });

    test('several activities in one week count once', () {
      expect(
        streakOf([
          DateTime(2026, 11, 1, 9),
          DateTime(2026, 11, 2, 9),
          DateTime(2026, 11, 3, 9),
        ]),
        const WeeklyStreak(weeks: 1, attendedThisWeek: true),
      );
    });

    test('keeps last week\'s streak while this week is still open', () {
      expect(
        streakOf([DateTime(2026, 10, 27), DateTime(2026, 10, 20)]),
        const WeeklyStreak(weeks: 2, attendedThisWeek: false),
      );
    });

    test('breaks after a whole week with no activity', () {
      expect(
        streakOf([DateTime(2026, 10, 20), DateTime(2026, 10, 13)]),
        const WeeklyStreak(weeks: 0, attendedThisWeek: false),
      );
    });

    test('a gap restarts the count', () {
      expect(
        streakOf([
          DateTime(2026, 11, 3), // this week
          // nothing 25-31 Oct
          DateTime(2026, 10, 20),
          DateTime(2026, 10, 13),
        ]),
        const WeeklyStreak(weeks: 1, attendedThisWeek: true),
      );
    });

    test('ignores activities that have not started yet', () {
      expect(
        streakOf([DateTime(2026, 11, 6), DateTime(2026, 11, 4, 19)]),
        WeeklyStreak.none,
      );
    });

    test('weeks start on Sunday', () {
      // Sat 31 Oct and Sun 1 Nov are in different weeks.
      expect(
        streakOf([DateTime(2026, 10, 31, 23, 59)], at: DateTime(2026, 11, 1)),
        const WeeklyStreak(weeks: 1, attendedThisWeek: false),
      );
      expect(
        streakOf([DateTime(2026, 11, 1)], at: DateTime(2026, 11, 7, 23, 59)),
        const WeeklyStreak(weeks: 1, attendedThisWeek: true),
      );
    });

    test('works across the new year', () {
      expect(
        streakOf([
          DateTime(2027, 1, 2),
          DateTime(2026, 12, 29),
          DateTime(2026, 12, 22),
        ], at: DateTime(2027, 1, 5)),
        // Sat 2 Jan 2027 is in the week of Sun 27 Dec, so this week is empty.
        const WeeklyStreak(weeks: 2, attendedThisWeek: false),
      );
    });

    test('handles UTC times from the server by local date', () {
      final local = DateTime(2026, 11, 2, 12);
      expect(
        streakOf([local.toUtc()]),
        const WeeklyStreak(weeks: 1, attendedThisWeek: true),
      );
    });

    test('long streaks keep counting', () {
      final attended = [
        for (var week = 0; week < 52; week++)
          DateTime(2026, 11, 3).subtract(Duration(days: 7 * week)),
      ];
      expect(streakOf(attended).weeks, 52);
    });
  });

  group('ActivityStore.weeklyStreak', () {
    const me = 'user-me';

    Activity activity(
      String id, {
      required DateTime at,
      String? hostId,
      String? status,
    }) {
      return Activity(
        id: id,
        title: id,
        dateTime: at,
        location: 'Somewhere',
        hostId: hostId,
        participationStatus: status,
      );
    }

    // Relative to the real clock, since the store reads DateTime.now().
    final today = DateTime.now();
    final lastWeek = today.subtract(const Duration(days: 7));
    final twoWeeksAgo = today.subtract(const Duration(days: 14));

    test('counts hosted and joined activities', () {
      final store = ActivityStore()
        ..currentUserId = me
        ..setMine([activity('hosted', at: lastWeek, hostId: me)])
        ..setParticipating([
          activity('joined', at: twoWeeksAgo, hostId: 'x', status: 'joined'),
        ]);

      expect(store.weeklyStreak.weeks, 2);
    });

    test('ignores pending and waitlisted requests', () {
      final store = ActivityStore()
        ..currentUserId = me
        ..setParticipating([
          activity('pending', at: lastWeek, hostId: 'x', status: 'pending'),
          activity('wait', at: lastWeek, hostId: 'x', status: 'waitlisted'),
        ]);

      expect(store.weeklyStreak, WeeklyStreak.none);
    });

    test('ignores upcoming activities', () {
      final store = ActivityStore()
        ..currentUserId = me
        ..setMine([
          activity(
            'soon',
            at: today.add(const Duration(minutes: 5)),
            hostId: me,
          ),
        ]);

      expect(store.weeklyStreak, WeeklyStreak.none);
    });
  });
}
