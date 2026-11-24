import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/l10n/app_localizations.dart';
import 'package:synk/models/activities_model.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/models/activity_participation_model.dart';
import 'package:synk/models/activity_swipes_model.dart';
import 'package:synk/models/top_picks.dart';
import 'package:synk/views/home/widgets/for_you_deck.dart';

// No server: swipes are dropped, joins always go through.
class _FakeSwipes implements ActivitySwipesModel {
  @override
  Future<void> record(String activityId, SwipeAction action) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeParticipation implements ActivityParticipationModel {
  final joined = <String>[];

  @override
  Future<ActivityJoinResult> joinPublicActivity(String activityId) async {
    joined.add(activityId);
    return const ActivityJoinResult(result: 'joined', message: 'Joined');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActivities implements ActivitiesModel {
  @override
  Future<List<Activity>> fetchParticipating() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TopPick pick(String id, int rank) => TopPick(
    rank: rank,
    activity: Activity(
      id: id,
      title: id,
      dateTime: DateTime.now().add(const Duration(days: 2)),
      location: 'Riyadh',
      maxParticipants: 6,
      participantsCount: 2,
    ),
    reason: const PopularNearYou(),
  );

  List<TopPick> picksOf(List<String> ids) => [
    for (final (i, id) in ids.indexed) pick(id, i + 1),
  ];

  Future<_FakeParticipation> pumpDeck(
    WidgetTester tester,
    ValueNotifier<List<TopPick>> picks,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final participation = _FakeParticipation();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ValueListenableBuilder(
              valueListenable: picks,
              builder: (context, value, _) => ForYouDeck(
                picks: value,
                session: 0,
                activityStore: ActivityStore(),
                onOpen: (_) {},
                onJoined: () {},
                swipes: _FakeSwipes(),
                participation: participation,
                activitiesModel: _FakeActivities(),
              ),
            ),
          ),
        ),
      ),
    );
    // Past the first-time nudge.
    await tester.pump(const Duration(seconds: 2));
    return participation;
  }

  // A swipe from the middle of the front card, where [title] is.
  Future<void> swipeLeft(WidgetTester tester, String title) async {
    final card = tester.getRect(find.byType(ForYouDeck));
    final gesture = await tester.startGesture(
      Offset(card.center.dx, card.top + 120),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    // The card flies off, then the deck moves on.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('goes back to the first card after the last one', (tester) async {
    await pumpDeck(tester, ValueNotifier(picksOf(['a', 'b', 'c'])));
    expect(find.text('1 of 3'), findsOneWidget);

    await swipeLeft(tester, 'a');
    await swipeLeft(tester, 'b');
    expect(find.text('3 of 3'), findsOneWidget);

    await swipeLeft(tester, 'c');
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Couldn’t find your thing?'), findsNothing);
  });

  testWidgets('takes the new top picks after a join', (tester) async {
    final picks = ValueNotifier(picksOf(['a', 'b', 'c']));
    final participation = await pumpDeck(tester, picks);

    // Join the first card; it's saved once the Undo bar goes away.
    await tester.tap(find.text('Join').last);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('2 of 3'), findsOneWidget);
    // The bar waits a few seconds, then slides away and the join is saved.
    await tester.pump(const Duration(seconds: 8));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(participation.joined, ['a']);

    // Home's picks drop the joined one and bring in the next best.
    picks.value = picksOf(['b', 'c', 'd']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Still on the card that was showing, now first of the new list.
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('b'), findsWidgets);
    await swipeLeft(tester, 'b');
    await swipeLeft(tester, 'c');
    expect(find.text('d'), findsWidgets);
  });
}
