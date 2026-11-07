import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synk/controllers/language_controller.dart';
import 'package:synk/l10n/l10n.dart';
import 'package:synk/models/activities_model.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/views/home/user_activity_history_view.dart';
import 'package:synk/views/home/widgets/recent_activities_section.dart';

// Returns a fixed history page, or throws when [fails] is set.
class _FakeActivitiesModel implements ActivitiesModel {
  _FakeActivitiesModel({
    this.allowed = true,
    this.activities = const [],
    this.fails = false,
    this.me,
  });

  final bool allowed;
  final List<Activity> activities;
  final bool fails;
  final String? me;
  final List<String> hidden = [];

  @override
  String? get currentUserId => me;

  @override
  Future<void> hideRecentActivity(String activityId) async {
    hidden.add(activityId);
  }

  @override
  Future<void> unhideRecentActivity(String activityId) async {
    hidden.remove(activityId);
  }

  @override
  Future<List<Activity>> fetchHiddenRecentActivities() async => [
    for (final a in activities)
      if (hidden.contains(a.id)) a,
  ];

  @override
  Future<UserActivityHistoryPage> fetchUserRecentActivities({
    required String userId,
    int limit = 10,
    int offset = 0,
  }) async {
    if (fails) throw Exception('offline');
    final page = activities
        .where((a) => !hidden.contains(a.id))
        .skip(offset)
        .take(limit)
        .toList();
    return UserActivityHistoryPage(
      allowed: allowed,
      activities: allowed ? page : const [],
      hasMore: allowed && offset + page.length < activities.length,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Activity _activity(String id, String title, DateTime date) {
  return Activity(
    id: id,
    title: title,
    dateTime: date,
    location: '',
    maxParticipants: 4,
  );
}

final _padel = _activity('a1', 'Padel', DateTime(2026, 10, 21, 18));
final _hiking = _activity('a2', 'Hiking', DateTime(2026, 10, 14, 7));

Widget _app(Widget child) {
  return MaterialApp(
    locale: LanguageController.instance.locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Future<void> _pumpSection(WidgetTester tester, ActivitiesModel model) async {
  await tester.pumpWidget(
    _app(
      RecentActivitiesSection(
        userId: 'friend',
        userName: 'Laila',
        activitiesModel: model,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LanguageController.instance.setLocale(const Locale('en')));

  group('RecentActivitiesSection', () {
    testWidgets('shows titles and dates, and folds away', (tester) async {
      await _pumpSection(
        tester,
        _FakeActivitiesModel(activities: [_padel, _hiking]),
      );

      expect(find.text('Recent activities'), findsOneWidget);
      expect(find.text('See all'), findsNothing);
      expect(find.text('Padel'), findsOneWidget);
      expect(find.text(formatShortDate(_padel.dateTime)), findsOneWidget);

      await tester.tap(find.text('Recent activities'));
      await tester.pumpAndSettle();
      expect(find.text('Padel'), findsNothing);
    });

    testWidgets('is hidden with no visible activities', (tester) async {
      await _pumpSection(tester, _FakeActivitiesModel());
      expect(find.text('Recent activities'), findsNothing);
    });

    testWidgets('is hidden for someone who is not a friend', (tester) async {
      await _pumpSection(
        tester,
        _FakeActivitiesModel(allowed: false, activities: [_padel]),
      );
      expect(find.text('Recent activities'), findsNothing);
    });

    testWidgets('is hidden when loading fails', (tester) async {
      await _pumpSection(tester, _FakeActivitiesModel(fails: true));
      expect(find.text('Recent activities'), findsNothing);
    });

    testWidgets('only the user can hide their own', (tester) async {
      await _pumpSection(
        tester,
        _FakeActivitiesModel(activities: [_padel, _hiking]),
      );
      expect(find.byTooltip('Hide'), findsNothing);

      final mine = _FakeActivitiesModel(
        activities: [_padel, _hiking],
        me: 'friend',
      );
      await _pumpSection(tester, mine);
      expect(find.byTooltip('Hide'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Hide').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide').last);
      await tester.pumpAndSettle();

      expect(mine.hidden, ['a1']);
      expect(find.text('Padel'), findsNothing);
      expect(find.text('Hiking'), findsOneWidget);

      await tester.tap(find.text('Hidden (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Padel'), findsOneWidget);
      await tester.tap(find.text('Unhide'));
      await tester.pumpAndSettle();

      expect(mine.hidden, isEmpty);
      expect(find.text('Hidden (1)'), findsNothing);
      expect(find.text('Padel'), findsOneWidget);
    });

    testWidgets('puts a fourth activity on the next row', (tester) async {
      await _pumpSection(
        tester,
        _FakeActivitiesModel(
          activities: [
            _padel,
            _hiking,
            _activity('a3', 'Chess', DateTime(2026, 10, 10, 18)),
            _activity('a4', 'Yoga', DateTime(2026, 10, 7, 18)),
          ],
        ),
      );

      final firstRow = tester.getTopLeft(find.text('Padel')).dy;
      expect(tester.getTopLeft(find.text('Chess')).dy, firstRow);
      expect(tester.getTopLeft(find.text('Yoga')).dy, greaterThan(firstRow));
    });
  });

  group('in Arabic', () {
    setUp(() => LanguageController.instance.setLocale(const Locale('ar')));

    testWidgets('lists from the right with Arabic dates', (tester) async {
      await _pumpSection(
        tester,
        _FakeActivitiesModel(activities: [_padel, _hiking]),
      );

      expect(find.text('الأنشطة الأخيرة'), findsOneWidget);
      expect(find.text('الأربعاء، 21 أكتوبر'), findsOneWidget);

      final first = tester.getTopLeft(find.text('Padel')).dx;
      final second = tester.getTopLeft(find.text('Hiking')).dx;
      expect(first, greaterThan(second));
    });

    testWidgets('history page title and empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: UserActivityHistoryView(
            userId: 'friend',
            userName: 'Laila',
            activitiesModel: _FakeActivitiesModel(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أنشطة Laila'), findsOneWidget);
      expect(find.text('لا توجد أنشطة منتهية حتى الآن'), findsOneWidget);
    });

    testWidgets('history dates include the year', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: UserActivityHistoryView(
            userId: 'friend',
            userName: 'Laila',
            activitiesModel: _FakeActivitiesModel(activities: [_padel]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الأربعاء، 21 أكتوبر 2026'), findsOneWidget);
    });
  });

  group('UserActivityHistoryView', () {
    testWidgets('shows Retry when loading fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: UserActivityHistoryView(
            userId: 'friend',
            userName: 'Laila',
            activitiesModel: _FakeActivitiesModel(fails: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load activities."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('dates include the year', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: UserActivityHistoryView(
            userId: 'friend',
            userName: 'Laila',
            activitiesModel: _FakeActivitiesModel(activities: [_padel]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final date = _padel.dateTime;
      final expected = appL10n.longDate(
        weekdayShort(date),
        monthShort(date.month),
        date.day,
        date.year,
      );
      expect(expected, contains('2026'));
      expect(find.text(expected), findsOneWidget);
    });
  });
}
