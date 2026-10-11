import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/controllers/home_discovery_controller.dart';
import 'package:synk/models/activities_model.dart';
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
}) {
  return Activity(
    id: id,
    title: title,
    description: description,
    dateTime: DateTime.now().add(const Duration(days: 3)),
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

      controller.setCategoryFilter('Padel');
      expect(controller.filteredActivities.map((a) => a.id), ['a']);

      controller.setCategoryFilter('Board Games');
      expect(controller.filteredActivities.map((a) => a.id), ['b']);

      // Category is shown by its chip, not counted on the filter button.
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

    test('re-applying the same location keeps it selected', () async {
      final controller = await controllerWith([_activity()]);
      controller.setLocationFilter('Kingdom Arena');
      controller.setLocationFilter('Kingdom Arena');
      expect(controller.selectedLocation, 'Kingdom Arena');
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
      expect(find.text('3/4 going'), findsOneWidget);
      expect(find.text(' · 1 spot left'), findsOneWidget);
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
