import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/l10n/app_localizations.dart';
import 'package:synk/models/activity_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synk/models/streak_intro.dart';
import 'package:synk/views/home/widgets/streak_widgets.dart';

void main() {
  const me = 'user-me';

  Activity hosted(String id, DateTime at) =>
      Activity(id: id, title: id, dateTime: at, location: 'X', hostId: me);

  Widget app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );

  // Wednesday 4 Nov 2026, 18:00. Its week runs Sun 1 Nov - Sat 7 Nov.
  final now = DateTime(2026, 11, 4, 18);

  group('helpers', () {
    test('best is the longest run ever, not just the current one', () {
      expect(
        WeeklyStreak.best([
          DateTime(2026, 11, 2), // current run: 1
          DateTime(2026, 10, 13), // older run: 3
          DateTime(2026, 10, 6),
          DateTime(2026, 9, 29),
        ], now: now),
        3,
      );
      expect(WeeklyStreak.best([], now: now), 0);
      // Upcoming activities don't count.
      expect(WeeklyStreak.best([DateTime(2026, 11, 6)], now: now), 0);
    });

    test('daysThisWeek marks attended days, Sunday first', () {
      expect(
        WeeklyStreak.daysThisWeek([
          DateTime(2026, 11, 1, 9), // Sunday
          DateTime(2026, 11, 3, 22), // Tuesday
          DateTime(2026, 11, 3, 23), // Tuesday again
          DateTime(2026, 10, 31), // last Saturday, other week
          DateTime(2026, 11, 6), // Friday, not yet
        ], now: now),
        [true, false, true, false, false, false, false],
      );
    });

    test('daysLeft counts today, down to 1 on Saturday', () {
      expect(WeeklyStreak.daysLeft(now: DateTime(2026, 11, 1)), 7); // Sun
      expect(WeeklyStreak.daysLeft(now: now), 4); // Wed
      expect(WeeklyStreak.daysLeft(now: DateTime(2026, 11, 7, 23)), 1); // Sat
    });

    test('weekStart is the Sunday of the week', () {
      expect(WeeklyStreak.weekStart(now: now), DateTime(2026, 11, 1));
      expect(
        WeeklyStreak.weekStart(weeksAgo: 1, now: now),
        DateTime(2026, 10, 25),
      );
      expect(
        WeeklyStreak.weekStart(now: DateTime(2026, 11, 1, 23)),
        DateTime(2026, 11, 1),
      );
      expect(
        WeeklyStreak.weekStart(now: DateTime(2027, 1, 2)),
        DateTime(2026, 12, 27),
      );
    });
  });

  group('isFading', () {
    const alive = WeeklyStreak(weeks: 3, attendedThisWeek: false);
    final friday = DateTime(2026, 11, 6, 12);
    final wednesday = DateTime(2026, 11, 4, 12);

    test('grey on the last two days with nothing booked', () {
      expect(WeeklyStreak.isFading(alive, [], now: friday), isTrue);
      expect(
        WeeklyStreak.isFading(alive, [], now: DateTime(2026, 11, 7, 23)),
        isTrue,
      );
    });

    test('not grey earlier in the week', () {
      expect(WeeklyStreak.isFading(alive, [], now: wednesday), isFalse);
    });

    test('a booking later this week keeps it lit', () {
      expect(
        WeeklyStreak.isFading(alive, [DateTime(2026, 11, 7, 20)], now: friday),
        isFalse,
      );
    });

    test('a booking next week does not help', () {
      expect(
        WeeklyStreak.isFading(alive, [DateTime(2026, 11, 8, 20)], now: friday),
        isTrue,
      );
    });

    test('never grey once attended, or with no streak', () {
      expect(
        WeeklyStreak.isFading(
          const WeeklyStreak(weeks: 3, attendedThisWeek: true),
          [],
          now: friday,
        ),
        isFalse,
      );
      expect(
        WeeklyStreak.isFading(WeeklyStreak.none, [], now: friday),
        isFalse,
      );
    });
  });

  group('StreakChip', () {
    testWidgets('shows the streak and opens the sheet', (tester) async {
      final store = ActivityStore()
        ..currentUserId = me
        ..setMine([
          hosted('a', DateTime.now().subtract(const Duration(days: 7))),
          hosted('b', DateTime.now().subtract(const Duration(days: 14))),
        ]);

      await tester.pumpWidget(app(StreakChip(activityStore: store)));
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('streak-chip')));
      await tester.pumpAndSettle();

      expect(find.text('weeks in a row'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
    });

    testWidgets('updates when activities change', (tester) async {
      final store = ActivityStore()..currentUserId = me;
      await tester.pumpWidget(app(StreakChip(activityStore: store)));
      expect(find.text('0'), findsOneWidget);

      store.setMine([
        hosted('a', DateTime.now().subtract(const Duration(minutes: 1))),
      ]);
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });
  });
  group('StreakIntro', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('shows once a day per user', () async {
      final morning = DateTime(2026, 11, 2, 9);
      final evening = DateTime(2026, 11, 2, 22);
      final tomorrow = DateTime(2026, 11, 3, 8);

      expect(await StreakIntro.takeTurn('u1', now: morning), isTrue);
      expect(await StreakIntro.takeTurn('u1', now: evening), isFalse);
      // Another account on the same phone gets its own turn.
      expect(await StreakIntro.takeTurn('u2', now: evening), isTrue);
      expect(await StreakIntro.takeTurn('u1', now: tomorrow), isTrue);
    });

    test('never shows when signed out', () async {
      expect(await StreakIntro.takeTurn(null), isFalse);
    });
  });
  group('StreakSheet', () {
    final cases = <String, List<DateTime>>{
      'no streak': [],
      'at risk': [DateTime(2026, 10, 27), DateTime(2026, 10, 20)],
      'done this week': [
        for (var week = 0; week < 12; week++)
          DateTime(2026, 11, 2).subtract(Duration(days: 7 * week)),
      ],
    };

    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final MapEntry(key: name, value: attended) in cases.entries) {
        testWidgets('fits on a small phone: $locale $name', (tester) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            app(
              Align(
                alignment: Alignment.bottomCenter,
                child: StreakSheet(attendedAt: attended, now: now),
              ),
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('at risk: count, best and days left', (tester) async {
      await tester.pumpWidget(
        app(
          StreakSheet(
            attendedAt: [
              DateTime(2026, 10, 27),
              DateTime(2026, 10, 20),
              DateTime(2026, 9, 29),
              DateTime(2026, 9, 22),
              DateTime(2026, 9, 15),
            ],
            now: now,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('weeks in a row'), findsOneWidget);
      expect(find.text('Best: 3 weeks'), findsOneWidget);
      expect(find.text('4 days left'), findsOneWidget);
      expect(
        find.text('One activity this week keeps it going'),
        findsOneWidget,
      );
    });

    testWidgets('done this week', (tester) async {
      await tester.pumpWidget(
        app(StreakSheet(attendedAt: [DateTime(2026, 11, 2)], now: now)),
      );
      await tester.pumpAndSettle();

      expect(find.text('week in a row'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(
        find.text("Nice, this week's done. See you next week"),
        findsOneWidget,
      );
    });

    testWidgets('Arabic text', (tester) async {
      await tester.pumpWidget(
        app(
          StreakSheet(
            attendedAt: [
              DateTime(2026, 10, 27),
              DateTime(2026, 10, 20),
              DateTime(2026, 10, 13),
            ],
            now: now,
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أسابيع متتالية'), findsOneWidget);
      expect(find.text('الأفضل: 3 أسابيع'), findsOneWidget);
      expect(find.text('باقي 4 أيام'), findsOneWidget);
      expect(find.text('هذا الأسبوع'), findsOneWidget);
    });
  });
}
