import 'package:flutter_test/flutter_test.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/models/friends_model.dart';
import 'package:synk/models/top_picks.dart';

final now = DateTime(2026, 10, 29, 12);
const me = 'me';
// Riyadh, roughly.
const home = (latitude: 24.7136, longitude: 46.6753);

Activity activity(
  String id, {
  String title = 'Meetup',
  int hoursFromNow = 24,
  double? kmEast,
  int joined = 1,
  int max = 6,
  String host = 'someone',
  ActivitySetting? setting,
}) {
  return Activity(
    id: id,
    title: title,
    setting: setting,
    dateTime: now.add(Duration(hours: hoursFromNow)),
    location: 'Place $id',
    hostId: host,
    participantsCount: joined,
    maxParticipants: max,
    latitude: kmEast == null ? null : home.latitude,
    // About 1 km per 0.00986 degrees of longitude at this latitude.
    longitude: kmEast == null ? null : home.longitude + kmEast * 0.00986,
  );
}

List<String> ids(List<TopPick> picks) => [
  for (final p in picks) p.activity.id,
];

void main() {
  test('skips past, full, hosted and already-joined activities', () {
    final picks = rankTopPicks(
      activities: [
        activity('past', hoursFromNow: -1),
        activity('full', joined: 4, max: 4),
        activity('mine', host: me),
        activity('joined'),
        activity('ok'),
      ],
      interests: const [],
      currentUserId: me,
      participatingIds: {'joined'},
      now: now,
    );

    expect(ids(picks), ['ok']);
  });

  test('orders by shared interests, then distance, then start time', () {
    final picks = rankTopPicks(
      activities: [
        activity('padel-far', title: 'Padel', kmEast: 9),
        activity('padel-near', title: 'Padel', kmEast: 1),
        activity('padel-movie', title: 'Padel then movie night', kmEast: 20),
        activity('padel-near-later', title: 'Padel', kmEast: 1, hoursFromNow: 48),
      ],
      interests: const ['Padel', 'Movies'],
      currentUserId: me,
      participatingIds: const {},
      userLocation: home,
      now: now,
    );

    expect(ids(picks), [
      'padel-movie',
      'padel-near',
      'padel-near-later',
      'padel-far',
    ]);
    expect(picks.first.reason, isA<SharedInterest>());
    expect((picks.first.reason as SharedInterest).interest, 'Padel');
    expect(picks.map((p) => p.rank), [1, 2, 3, 4]);
  });

  test('fills with popular nearby activities when few match', () {
    final picks = rankTopPicks(
      activities: [
        activity('padel', title: 'Padel', kmEast: 5),
        activity('quiet', title: 'Chat', joined: 1, kmEast: 1),
        activity('busy-far', title: 'Chat', joined: 4, kmEast: 8),
        activity('busy-near', title: 'Chat', joined: 4, kmEast: 2),
        activity('mid', title: 'Chat', joined: 2, kmEast: 1),
        activity('extra', title: 'Chat', joined: 1, kmEast: 3),
      ],
      interests: const ['Padel'],
      currentUserId: me,
      participatingIds: const {},
      userLocation: home,
      now: now,
    );

    expect(ids(picks), ['padel', 'busy-near', 'busy-far', 'mid', 'quiet']);
    expect(picks.skip(1).every((p) => p.reason is PopularNearYou), isTrue);
  });

  test('without location, ranks by interests and time and hides distance', () {
    final picks = rankTopPicks(
      activities: [
        activity('later', title: 'Padel', kmEast: 1, hoursFromNow: 48),
        activity('sooner', title: 'Padel', kmEast: 30, hoursFromNow: 2),
      ],
      interests: const ['Padel'],
      currentUserId: me,
      participatingIds: const {},
      now: now,
    );

    expect(ids(picks), ['sooner', 'later']);
    expect(picks.every((p) => p.distanceKm == null), isTrue);
  });

  test('friends outrank interests, which outrank the preferred setting', () {
    const sara = FriendUser(id: 'f1', name: 'Sara');
    final picks = rankTopPicks(
      activities: [
        activity('outdoor', title: 'Chat', setting: ActivitySetting.outdoor),
        activity('indoor', title: 'Chat', setting: ActivitySetting.indoor),
        activity('padel', title: 'Padel'),
        activity('friend', title: 'Chat'),
      ],
      interests: const ['Padel'],
      preferredSetting: 'Outdoor',
      friendsGoing: const {
        'friend': [sara],
      },
      currentUserId: me,
      participatingIds: const {},
      now: now,
    );

    expect(ids(picks), ['friend', 'padel', 'outdoor', 'indoor']);
    expect((picks[0].reason as FriendsGoing).friends, [sara]);
    expect(picks[1].reason, isA<SharedInterest>());
    expect(
      (picks[2].reason as PreferredSetting).setting,
      ActivitySetting.outdoor,
    );
    expect(picks[3].reason, isA<PopularNearYou>());
  });

  test('"I don\'t mind" adds nothing for the setting', () {
    final picks = rankTopPicks(
      activities: [
        activity('outdoor', setting: ActivitySetting.outdoor),
      ],
      interests: const [],
      preferredSetting: "I don't mind",
      currentUserId: me,
      participatingIds: const {},
      now: now,
    );

    expect(picks.single.reason, isA<PopularNearYou>());
  });

  test('ignores "Open to Anything" and caps the list at five', () {
    final picks = rankTopPicks(
      activities: [for (var i = 0; i < 8; i++) activity('a$i')],
      interests: const ['Open to Anything'],
      currentUserId: me,
      participatingIds: const {},
      now: now,
    );

    expect(picks, hasLength(5));
    expect(picks.every((p) => p.reason is PopularNearYou), isTrue);
  });
}
