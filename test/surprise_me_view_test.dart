import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synk/controllers/language_controller.dart';
import 'package:synk/l10n/app_localizations.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/models/top_picks.dart';
import 'package:synk/views/home/surprise_me_view.dart';
import 'package:synk/views/home/widgets/surprise_puzzle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LanguageController.instance.setLocale(const Locale('en')));

  final activity = Activity(
    id: 'a1',
    title: 'Sunset padel with a very long title that keeps going and going',
    dateTime: DateTime.now().add(const Duration(days: 1)),
    location: 'Granada Mall, Eastern Ring Branch Rd, Ghirnatah, Riyadh',
    maxParticipants: 4,
    participantsCount: 2,
  );

  Future<void> pumpSurprise(
    WidgetTester tester, {
    required List<TopPick> ranked,
    Locale locale = const Locale('en'),
    Size size = const Size(320, 640),
  }) async {
    await LanguageController.instance.setLocale(locale);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SurpriseMeView(
          ranked: () => ranked,
          activityStore: ActivityStore(),
          distanceOf: (_) => 3.2,
          onOpen: (_) {},
          onJoined: () {},
        ),
      ),
    );
  }

  final picks = [
    TopPick(rank: 1, activity: activity, reason: const PopularNearYou()),
  ];

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('shuffles and reveals an activity on a small phone '
        '(${locale.languageCode})', (tester) async {
      await pumpSurprise(tester, ranked: picks, locale: locale);
      expect(find.byType(SurprisePuzzle), findsOneWidget);

      await tester.tap(find.byIcon(Icons.extension_rounded).last);
      await tester.pump();
      // Mid-shuffle the button can't be pressed again.
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SurprisePuzzle), findsOneWidget);

      await tester.pump(SurprisePuzzle.duration);
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Sunset padel'), findsOneWidget);
      expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('says so when there is nothing to pick', (tester) async {
    await pumpSurprise(tester, ranked: const []);

    await tester.tap(find.byIcon(Icons.extension_rounded).last);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('No surprises right now'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
  });
}
