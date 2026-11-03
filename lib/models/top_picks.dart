import 'activity_filters.dart';
import 'activity_model.dart';
import 'friends_model.dart';

// Why an activity made the user's top picks, strongest first.
sealed class TopPickReason {
  const TopPickReason();
}

// Friends of the user are hosting or have joined.
class FriendsGoing extends TopPickReason {
  const FriendsGoing(this.friends);

  final List<FriendUser> friends;
}

// Shares at least one of the user's interests; [interest] is the first match.
class SharedInterest extends TopPickReason {
  const SharedInterest(this.interest);

  final String interest;
}

// Indoors or outdoors, as the user prefers.
class PreferredSetting extends TopPickReason {
  const PreferredSetting(this.setting);

  final ActivitySetting setting;
}

// Fills the list when too few activities match the user.
class PopularNearYou extends TopPickReason {
  const PopularNearYou();
}

class TopPick {
  const TopPick({
    required this.rank,
    required this.activity,
    required this.reason,
    this.distanceKm,
  });

  // 1 to [rankTopPicks]'s limit.
  final int rank;
  final Activity activity;
  final TopPickReason reason;

  // Null without the user's location or the activity's coordinates.
  final double? distanceKm;
}

// Interests that say nothing about a specific activity.
const _ignoredInterests = {'Open to Anything'};

// How much each kind of match counts. A friend going outweighs a shared
// interest, which outweighs the preferred setting.
const _friendWeight = 3;
const _interestWeight = 2;
const _settingWeight = 1;

// Picks the best upcoming activities for the user. Each scores for friends
// going, shared interests and the user's indoor/outdoor preference
// ([preferredSetting], from the profile's activity_type: 'Indoor',
// 'Outdoor' or anything else for no preference). Higher scores come first,
// then the nearest, then the soonest. When fewer than [limit] score, the most
// joined activities nearby fill the rest. Without [userLocation], distance
// is skipped.
List<TopPick> rankTopPicks({
  required Iterable<Activity> activities,
  required Iterable<String> interests,
  required String? currentUserId,
  required Set<String> participatingIds,
  Map<String, List<FriendUser>> friendsGoing = const {},
  String? preferredSetting,
  GeoPoint? userLocation,
  DateTime? now,
  int limit = 5,
}) {
  final at = now ?? DateTime.now();
  final wanted = interests
      .map((i) => i.trim())
      .where((i) => i.isNotEmpty && !_ignoredInterests.contains(i))
      .toList();
  final setting = ActivitySetting.fromName(
    preferredSetting?.trim().toLowerCase(),
  );

  final candidates = <_Candidate>[];
  final seen = <String>{};
  for (final activity in activities) {
    if (!seen.add(activity.id) ||
        !activity.dateTime.isAfter(at) ||
        activity.availability == ActivityAvailability.full ||
        activity.isHostedBy(currentUserId) ||
        participatingIds.contains(activity.id)) {
      continue;
    }

    // The host already shows as the host, not as a friend who's going.
    final friends = [
      for (final f in friendsGoing[activity.id] ?? const <FriendUser>[])
        if (f.id != activity.hostId) f,
    ];
    final shared = [
      for (final interest in wanted)
        if (ActivityFilters.matchesCategory(activity, interest)) interest,
    ];
    final settingMatches = setting != null && activity.setting == setting;
    final distance = userLocation != null && activity.hasCoordinates
        ? ActivityFilters.distanceKm(userLocation, (
            latitude: activity.latitude!,
            longitude: activity.longitude!,
          ))
        : null;

    final TopPickReason? reason = friends.isNotEmpty
        ? FriendsGoing(friends)
        : shared.isNotEmpty
        ? SharedInterest(shared.first)
        : settingMatches
        ? PreferredSetting(setting)
        : null;

    candidates.add(
      _Candidate(
        activity: activity,
        score:
            friends.length * _friendWeight +
            shared.length * _interestWeight +
            (settingMatches ? _settingWeight : 0),
        reason: reason,
        distance: distance,
      ),
    );
  }

  // Unknown distances sort after known ones.
  int byDistance(_Candidate a, _Candidate b) =>
      (a.distance ?? double.infinity).compareTo(b.distance ?? double.infinity);
  int bySoonest(_Candidate a, _Candidate b) =>
      a.activity.dateTime.compareTo(b.activity.dateTime);

  final matching = candidates.where((c) => c.score > 0).toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final near = byDistance(a, b);
      return near != 0 ? near : bySoonest(a, b);
    });

  final popular = candidates.where((c) => c.score == 0).toList()
    ..sort((a, b) {
      final byJoined = b.activity.joinedCount.compareTo(a.activity.joinedCount);
      if (byJoined != 0) return byJoined;
      final near = byDistance(a, b);
      return near != 0 ? near : bySoonest(a, b);
    });

  final picked = [...matching, ...popular].take(limit).toList();
  return [
    for (var i = 0; i < picked.length; i++)
      TopPick(
        rank: i + 1,
        activity: picked[i].activity,
        reason: picked[i].reason ?? const PopularNearYou(),
        distanceKm: picked[i].distance,
      ),
  ];
}

class _Candidate {
  const _Candidate({
    required this.activity,
    required this.score,
    required this.reason,
    required this.distance,
  });

  final Activity activity;
  final int score;
  final TopPickReason? reason;
  final double? distance;
}
