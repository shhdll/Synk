import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synk/l10n/app_localizations.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/views/home/activities_view.dart';
import 'package:synk/views/home/widgets/activity_details_sheet.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'x',
    );
  });

  testWidgets('Activities opens an activity the shell asks for', (
    tester,
  ) async {
    final store = ActivityStore()..currentUserId = 'me';
    final activity = Activity(
      id: 'a',
      title: 'Padel',
      hostId: 'me',
      dateTime: DateTime.now().add(const Duration(days: 1)),
      location: 'Riyadh',
      participantsCount: 1,
      maxParticipants: 4,
    );
    store.setMine([activity]);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ActivitiesView(activityStore: store),
      ),
    );

    // Like Create Activity closing just before the request.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final closed = navigator.push<void>(
      MaterialPageRoute(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    navigator.pop();
    await closed;

    store.showInActivities(activity);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ActivityDetailsSheet), findsOneWidget);
    expect(store.detailsFocus, isNull);
  });
}
