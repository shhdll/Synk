import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/controllers/home_discovery_controller.dart';
import 'package:synk/l10n/l10n.dart';
import 'package:synk/models/activities_model.dart';
import 'package:synk/models/activity_filters.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/models/user_profile_model.dart';
import 'package:synk/views/home/widgets/filter_bottom_sheet.dart';
import 'package:synk/views/home/widgets/synk_filter_chip.dart';

class _FakeActivitiesModel implements ActivitiesModel {
  @override
  String? get currentUserId => 'me';

  @override
  Future<List<Activity>> fetchDiscoveryFeed({
    String? currentUserId,
    String? currentUserGender,
    int limit = 60,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileModel implements UserProfileModel {
  @override
  Future<Map<String, dynamic>> fetchProfile() async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<List<ActivityFilters>> pickNearest(
    WidgetTester tester, {
    required bool hasLocation,
  }) async {
    final picked = <ActivityFilters>[];
    final controller = HomeDiscoveryController(
      activitiesModel: _FakeActivitiesModel(),
      profileModel: _FakeProfileModel(),
    );
    // Home's controller has no location; only the map knows where the user is.
    expect(controller.userLocation, isNull);

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FilterBottomSheet(
              controller: controller,
              filters: ActivityFilters.defaults,
              countFor: (_) => 0,
              onApply: (_) {},
              onSortPicked: picked.add,
              hasLocation: hasLocation,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Nearest'));
    await tester.pump();
    return picked;
  }

  testWidgets('map sort uses the location the map found', (tester) async {
    final picked = await pickNearest(tester, hasLocation: true);
    expect(picked.single.sort, SortOption.nearest);
  });

  testWidgets('nearest stays off when nobody knows the location', (
    tester,
  ) async {
    final picked = await pickNearest(tester, hasLocation: false);
    expect(picked, isEmpty);
  });

  test('no sort is chosen until the user picks one', () {
    expect(ActivityFilters.defaults.sort, isNull);
    expect(ActivityFilters.defaults.changedSectionCount, 0);
    const soonest = ActivityFilters(sort: SortOption.soonest);
    expect(soonest.changedSectionCount, 1);
  });

  testWidgets('reset leaves every sort unselected', (tester) async {
    final controller = HomeDiscoveryController(
      activitiesModel: _FakeActivitiesModel(),
      profileModel: _FakeProfileModel(),
    );
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FilterBottomSheet(
              controller: controller,
              filters: const ActivityFilters(sort: SortOption.latest),
              countFor: (_) => 0,
              onApply: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Reset'));
    await tester.pump();

    final chips = tester.widgetList<SynkFilterChip>(
      find.byType(SynkFilterChip),
    );
    final sortLabels = SortOption.values.map((o) => o.label).toSet();
    expect(
      chips.where((c) => sortLabels.contains(c.label) && c.selected),
      isEmpty,
    );
  });
}
