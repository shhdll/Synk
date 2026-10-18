import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/controllers/home_discovery_controller.dart';
import 'package:synk/models/activities_model.dart';
import 'package:synk/models/activity_filters.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/models/user_profile_model.dart';
import 'package:synk/utils/maps_launcher.dart';
import 'package:synk/views/home/widgets/activity_thumbnail.dart';
import 'package:synk/views/home/widgets/discovery_activity_card.dart';

class _FakeActivitiesModel implements ActivitiesModel {
  _FakeActivitiesModel(this.activities);

  final List<Activity> activities;

  @override
  String? get currentUserId => 'me';

  @override
  Future<List<Activity>> fetchDiscoveryFeed({
    String? currentUserId,
    String? currentUserGender,
    int limit = 60,
  }) async => activities;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileModel implements UserProfileModel {
  @override
  Future<Map<String, dynamic>> fetchProfile() async => {'full_name': 'Sara A'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Activity _activity({
  String id = '1',
  String title = 'Padel night',
  String description = '',
  String location = 'Kingdom Arena',
  String? address,
  double? lat,
  double? lng,
  String? username = 'sara',
  int joined = 2,
  int max = 4,
  DateTime? at,
}) {
  return Activity(
    id: id,
    title: title,
    description: description,
    dateTime: at ?? DateTime.now().add(const Duration(days: 3)),
    location: location,
    locationAddress: address,
    latitude: lat,
    longitude: lng,
    maxParticipants: max,
    participantsCount: joined,
    hostId: 'host',
    hostName: 'Sara Ahmed',
    hostUsername: username,
  );
}

void main() {
  group('HomeDiscoveryController', () {
    Future<HomeDiscoveryController> controllerWith(List<Activity> items) async {
      final controller = HomeDiscoveryController(
        activitiesModel: _FakeActivitiesModel(items),
        profileModel: _FakeProfileModel(),
      );
      await controller.loadFeed();
      return controller;
    }

    test('search matches title, description, location and address', () async {
      final controller = await controllerWith([
        _activity(id: 'a', title: 'Sunrise ride'),
        _activity(id: 'b', title: 'x', description: 'bring your racket'),
        _activity(id: 'c', title: 'y', location: 'Diriyah Gate'),
        _activity(id: 'd', title: 'z', address: 'Olaya St, Riyadh'),
      ]);

      List<String> search(String q) {
        controller.searchController.text = q;
        controller.onSearchChanged(q);
        return controller.filteredActivities.map((a) => a.id).toList();
      }

      expect(search('sunrise'), ['a']);
      expect(search('racket'), ['b']);
      expect(search('diriyah'), ['c']);
      expect(search('olaya'), ['d']);
    });

    test('category chips match titles when no category label is set', () async {
      final controller = await controllerWith([
        _activity(id: 'a', title: 'Friday Padel doubles'),
        _activity(id: 'b', title: 'Board Games evening'),
        _activity(id: 'c', title: 'Brunch'),
      ]);

      controller.toggleCategory('Padel');
      expect(controller.filteredActivities.map((a) => a.id), ['a']);

      // Categories are multi-select and count as one sheet section.
      controller.toggleCategory('Board Games');
      expect(controller.filteredActivities.map((a) => a.id), ['a', 'b']);
      expect(controller.activeFilterCount, 1);

      controller.clearCategories();
      expect(controller.filteredActivities, hasLength(3));
      expect(controller.activeFilterCount, 0);
    });

    test('offers only categories that appear in the feed', () async {
      final controller = await controllerWith([
        _activity(id: 'a', title: 'Friday Padel doubles'),
        _activity(id: 'b', title: 'Chess in the park'),
      ]);
      expect(
        controller.categoriesInFeed(['Padel', 'Board Games', 'Chess']),
        ['Padel', 'Chess'],
      );
    });

    test('live count uses the same logic as the applied list', () async {
      final controller = await controllerWith([
        _activity(id: 'a', joined: 3, max: 4),
        _activity(id: 'b', joined: 4, max: 4),
        _activity(id: 'c', joined: 1, max: 4),
      ]);
      const draft = ActivityFilters(spots: SpotsOption.hasSpots);

      expect(controller.countFor(draft), 2);
      // A draft doesn't change the list until it is applied.
      expect(controller.filteredActivities, hasLength(3));

      controller.applyFilters(draft);
      expect(controller.filteredActivities, hasLength(2));
    });

    test('day strip and Date filter stay in sync', () async {
      final controller = await controllerWith([_activity()]);
      final today = DateUtils.dateOnly(DateTime.now());
      final inFive = today.add(const Duration(days: 5));

      controller.selectDay(today);
      expect(controller.filters.date, DateOption.today);

      controller.selectDay(inFive);
      expect(controller.filters.date, DateOption.custom);
      expect(controller.filters.customDate, inFive);
      expect(controller.filters.coversDay(inFive, DateTime.now()), isTrue);

      // Tapping the only selected day again clears the date.
      controller.selectDay(inFive);
      expect(controller.filters.date, DateOption.any);
    });

    test('day availability follows every filter except the date', () async {
      final today = DateUtils.dateOnly(DateTime.now());
      DateTime at(int days) => today.add(Duration(days: days, hours: 18));
      final controller = await controllerWith([
        _activity(id: 'a', title: 'Padel doubles', at: at(1)),
        _activity(id: 'b', title: 'Art class', at: at(2)),
        _activity(id: 'c', title: 'Padel league', at: at(2)),
      ]);
      DateTime d(int days) => today.add(Duration(days: days));

      expect(controller.activityCountsByDay, {d(1): 1, d(2): 2});

      controller.toggleCategory('Art');
      expect(controller.activityCountsByDay, {d(2): 1});

      // Selecting a day doesn't hide the other days' availability.
      controller.selectDay(d(2));
      expect(controller.activityCountsByDay, {d(2): 1});
    });

    test('clear filters resets every section and the search', () async {
      final controller = await controllerWith([_activity()]);
      controller.searchController.text = 'padel';
      controller.applyFilters(
        const ActivityFilters(
          sort: SortOption.almostFull,
          date: DateOption.tomorrow,
          spots: SpotsOption.oneLeft,
        ).toggleCategory('Padel'),
      );
      expect(controller.activeFilterCount, 4);

      controller.clearAllFilters();
      expect(controller.filters.isDefault, isTrue);
      expect(controller.searchQuery, isEmpty);
    });
  });

  group('ActivityFilters', () {
    // Wednesday, Oct 21 2026, 10:00.
    final now = DateTime(2026, 10, 21, 10);
    DateTime day(int d, [int hour = 18]) => DateTime(2026, 10, d, hour);
    List<String> ids(
      ActivityFilters f,
      List<Activity> items, {
      GeoPoint? me,
    }) => f.apply(items, now: now, userLocation: me).map((a) => a.id).toList();

    test('date options cover the right days', () {
      final items = [
        _activity(id: 'wed', at: day(21)),
        _activity(id: 'thu', at: day(22)),
        _activity(id: 'fri', at: day(23)),
        _activity(id: 'sat', at: day(24)),
        _activity(id: 'sun', at: day(25)),
      ];
      List<String> on(DateOption o, [DateTime? custom]) =>
          ids(ActivityFilters.defaults.withDate(o, customDate: custom), items);

      expect(on(DateOption.any), hasLength(5));
      expect(on(DateOption.today), ['wed']);
      expect(on(DateOption.tomorrow), ['thu']);
      expect(on(DateOption.custom, DateTime(2026, 10, 25)), ['sun']);
    });

    test('time: one slot, or a picked start time and later', () {
      final items = [
        _activity(id: 'morning', at: day(22, 8)),
        _activity(id: 'afternoon', at: day(22, 12)),
        _activity(id: 'evening', at: day(22, 19)),
        _activity(id: 'night', at: day(22, 23)),
      ];
      final defaults = ActivityFilters.defaults;
      expect(ids(defaults.withTime(slot: DaySlot.night), items), ['night']);
      // From 12:00: noon and later.
      expect(
        ids(defaults.withTime(fromMinute: 12 * 60), items),
        ['afternoon', 'evening', 'night'],
      );
      // Picking one replaces the other; passing neither clears it.
      final both = defaults
          .withTime(fromMinute: 60)
          .withTime(slot: DaySlot.morning);
      expect(both.fromMinute, isNull);
      expect(both.withTime().hasTime, isFalse);
      expect(formatMinute(19 * 60 + 30), '7:30 PM');
    });

    test('opposite sorts reverse their order', () {
      final items = [
        _activity(id: 'later', joined: 1, max: 4, at: day(24)),
        _activity(id: 'sooner', joined: 3, max: 4, at: day(22)),
        _activity(id: 'full', joined: 4, max: 4, at: day(23)),
      ];
      List<String> by(SortOption s) => ids(ActivityFilters(sort: s), items);
      expect(by(SortOption.latest), ['later', 'full', 'sooner']);
      expect(by(SortOption.mostSpots), ['later', 'sooner', 'full']);
    });

    test('spots: one left and has spots', () {
      final items = [
        _activity(id: 'one', joined: 3, max: 4),
        _activity(id: 'two', joined: 2, max: 4),
        _activity(id: 'full', joined: 4, max: 4),
      ];
      expect(
        ids(const ActivityFilters(spots: SpotsOption.oneLeft), items),
        ['one'],
      );
      expect(
        ids(const ActivityFilters(spots: SpotsOption.hasSpots), items),
        ['one', 'two'],
      );
      expect(
        ids(const ActivityFilters(spots: SpotsOption.full), items),
        ['full'],
      );
    });

    test('almost full sorts fewest spots first and hides full ones', () {
      final items = [
        _activity(id: 'two', joined: 2, max: 4, at: day(22)),
        _activity(id: 'full', joined: 4, max: 4, at: day(22)),
        _activity(id: 'one', joined: 3, max: 4, at: day(23)),
      ];
      expect(
        ids(const ActivityFilters(sort: SortOption.almostFull), items),
        ['one', 'two'],
      );
    });

    // From Al Olaya: KAFD is about 9 km away, Diriyah about 12 km.
    const olaya = (latitude: 24.6950, longitude: 46.6850);
    final places = [
      _activity(id: 'diriyah', lat: 24.7340, lng: 46.5750, at: day(22)),
      _activity(id: 'kafd', lat: 24.7620, lng: 46.6400, at: day(23)),
      _activity(id: 'olaya', lat: 24.6960, lng: 46.6860, at: day(24)),
      _activity(id: 'nowhere', at: day(21, 12)),
    ];

    test('nearest and farthest sort by distance; no coordinates last', () {
      List<String> by(SortOption s, {GeoPoint? me}) =>
          ids(ActivityFilters(sort: s), places, me: me);

      expect(by(SortOption.nearest, me: olaya), [
        'olaya',
        'kafd',
        'diriyah',
        'nowhere',
      ]);
      expect(by(SortOption.farthest, me: olaya), [
        'diriyah',
        'kafd',
        'olaya',
        'nowhere',
      ]);
      // Without a location, both fall back to soonest.
      expect(by(SortOption.nearest), ['nowhere', 'diriyah', 'kafd', 'olaya']);
    });

    test('distance measures from the user', () {
      const within10 = ActivityFilters(distance: DistanceOption.within10);
      expect(ids(within10, places, me: olaya), ['kafd', 'olaya']);
      // No location at all: the distance filter can't apply.
      expect(ids(within10, places), hasLength(4));
    });

    test('badge counts sections that differ from defaults', () {
      expect(ActivityFilters.defaults.changedSectionCount, 0);
      final f = const ActivityFilters(
        distance: DistanceOption.within5,
        sort: SortOption.latest,
      ).withTime(slot: DaySlot.evening);
      expect(f.changedSectionCount, 3);
      expect(f.withTime().changedSectionCount, 2);
    });

    test('plural categories match singular words', () {
      expect(
        ActivityFilters.matchesCategory(_activity(title: 'Book club'), 'Books'),
        isTrue,
      );
      expect(
        ActivityFilters.matchesCategory(_activity(title: 'Chess'), 'Chess'),
        isTrue,
      );
    });

    test('every activity lands in a category, unmatched ones in Other', () {
      bool m(String title, String c) =>
          ActivityFilters.matchesCategory(_activity(title: title), c);

      expect(m('Morning run', 'Running'), isTrue);
      expect(m('Sunday brunch', 'Food'), isTrue);
      expect(m('Sunday brunch', 'Running'), isFalse);
      expect(m('o', 'Other'), isTrue);
      expect(m('Morning run', 'Other'), isFalse);
    });

    test('formats short dates', () {
      expect(formatShortDate(DateTime(2026, 10, 20)), 'Tue, Oct 20');
    });
  });

  group('MapsLauncher', () {
    test('prefers coordinates, then address, then place name', () {
      expect(
        MapsLauncher.googleMapsUri(_activity(lat: 24.7, lng: 46.6))
            ?.queryParameters['query'],
        '24.7,46.6',
      );
      expect(
        MapsLauncher.googleMapsUri(_activity(address: 'Olaya St'))
            ?.queryParameters['query'],
        'Olaya St',
      );
      expect(
        MapsLauncher.googleMapsUri(_activity())?.queryParameters['query'],
        'Kingdom Arena',
      );
      expect(MapsLauncher.googleMapsUri(_activity(location: '')), isNull);
    });
  });

  group('ActivityVisual', () {
    test('picks icons by word start', () {
      expect(
        ActivityVisual.of(_activity(title: 'Morning running club')).icon,
        Icons.directions_run_rounded,
      );
      expect(
        ActivityVisual.of(_activity(title: 'Sunday brunch')).icon,
        Icons.restaurant_rounded,
      );
      expect(
        ActivityVisual.of(_activity(title: 'Something new')).icon,
        ActivityVisual.fallback.icon,
      );
    });
  });

  group('DiscoveryActivityCard', () {
    Future<void> pumpCard(WidgetTester tester, Activity activity) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DiscoveryActivityCard(activity: activity, onTap: () {}),
          ),
        ),
      );
    }

    testWidgets('shows handle, count and no join button or host badge', (
      tester,
    ) async {
      await pumpCard(tester, _activity(joined: 3, max: 4));

      expect(find.text('Padel night'), findsOneWidget);
      expect(find.text('@sara'), findsOneWidget);
      expect(find.text('Sara Ahmed'), findsNothing);
      // Count and status share one pill.
      expect(find.text('3/4 One More Needed'), findsOneWidget);
      expect(find.textContaining('Join'), findsNothing);
      expect(find.text('Host'), findsNothing);
      expect(find.textContaining('Women'), findsNothing);
    });

    testWidgets('has no map button; maps live in the details sheet', (
      tester,
    ) async {
      await pumpCard(tester, _activity(lat: 24.7, lng: 46.6));
      expect(find.byIcon(Icons.map_outlined), findsNothing);
      expect(find.byIcon(Icons.map_rounded), findsNothing);
    });
  });
}
