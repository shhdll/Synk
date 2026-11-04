import 'dart:math' as math;

import '../core/constants/activity_categories.dart';
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

// Shares one of the user's interests, or a kind of activity they keep
// joining; [interest] is the strongest match.
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
    this.score = 0,
  });

  // 1 to [rankTopPicks]'s limit.
  final int rank;
  final Activity activity;
  final TopPickReason reason;

  // How well it matches the user; 0 for popular fill-ins.
  final double score;

  // Null without the user's location or the activity's coordinates.
  final double? distanceKm;
}

enum TasteSignal { joined, opened, skipped }

// Something the user did with an activity, from get_my_for_you_history.
class TasteEvent {
  const TasteEvent({
    required this.activity,
    required this.signal,
    required this.at,
  });

  // Only the id, title, description and category are filled in.
  final Activity activity;
  final TasteSignal signal;
  final DateTime at;

  static TasteEvent? fromMap(Map<String, dynamic> map) {
    final signal = switch (map['signal']) {
      'joined' => TasteSignal.joined,
      'opened' => TasteSignal.opened,
      'skipped' => TasteSignal.skipped,
      _ => null,
    };
    final at = DateTime.tryParse(map['happened_at'] as String? ?? '');
    final id = map['activity_id'] as String?;
    if (signal == null || at == null || id == null) return null;
    return TasteEvent(
      signal: signal,
      at: at.toLocal(),
      activity: Activity(
        id: id,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        categoryLabel: map['category_label'] as String? ?? '',
        dateTime: at.toLocal(),
        location: '',
      ),
    );
  }
}

// What the user's history says they like: a weight per category, and how
// often they skipped each activity.
class Taste {
  const Taste({this.categories = const {}, this.skips = const {}});

  static const none = Taste();

  // Above 0 for kinds of activity the user goes for, below for ones they
  // keep skipping.
  final Map<String, double> categories;

  // Activity id to times skipped.
  final Map<String, int> skips;

  // A join counts most, opening a card a little, a skip a little against.
  // Each counts half as much every [_halfLifeDays].
  static const _joined = 1.0;
  static const _opened = 0.3;
  static const _skipped = -0.15;
  static const _halfLifeDays = 30.0;

  factory Taste.fromHistory(Iterable<TasteEvent> events, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final categories = <String, double>{};
    final skips = <String, int>{};
    for (final event in events) {
      if (event.signal == TasteSignal.skipped) {
        skips[event.activity.id] = (skips[event.activity.id] ?? 0) + 1;
      }
      final days = math.max(0, at.difference(event.at).inHours / 24);
      final weight =
          switch (event.signal) {
            TasteSignal.joined => _joined,
            TasteSignal.opened => _opened,
            TasteSignal.skipped => _skipped,
          } *
          math.pow(0.5, days / _halfLifeDays);
      for (final category in _categoriesOf(event.activity)) {
        categories[category] = (categories[category] ?? 0) + weight;
      }
    }
    return Taste(categories: categories, skips: skips);
  }
}

List<String> _categoriesOf(Activity activity) => [
  for (final category in kActivityCategories.keys)
    if (ActivityFilters.matchesCategory(activity, category)) category,
];

// Interests that say nothing about a specific activity.
const _ignoredInterests = {'Open to Anything'};

// How much each kind of match counts. A friend going outweighs a shared
// interest, which outweighs the preferred setting.
const _friendWeight = 3.0;
const _interestWeight = 2.0;
const _settingWeight = 1.0;

// The most the history can add or take away.
const _maxTaste = 2.0;

// Closer and sooner score higher: [_nearWeight] at 0 km, dropping to about
// a third every [_nearKm]; [_soonWeight] now, dropping every [_soonHours].
const _nearWeight = 2.0;
const _nearKm = 8.0;
const _soonWeight = 1.0;
const _soonHours = 48.0;

// Taken off for each time the user skipped the activity.
const _skipPenalty = 1.5;

// Picks the best upcoming activities for the user. Each scores for friends
// going, shared interests, the user's indoor/outdoor preference
// ([preferredSetting], from the profile's activity_type: 'Indoor',
// 'Outdoor' or anything else for no preference) and what [taste] learned
// from their history. Those that match also score for being close and soon,
// and lose for each skip. When fewer than [limit] match, the most joined
// activities nearby fill the rest, skipped ones last. Without
// [userLocation], distance is skipped.
List<TopPick> rankTopPicks({
  required Iterable<Activity> activities,
  required Iterable<String> interests,
  required String? currentUserId,
  required Set<String> participatingIds,
  Map<String, List<FriendUser>> friendsGoing = const {},
  String? preferredSetting,
  Taste taste = Taste.none,
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

    // The best liked category, for the reason.
    String? liked;
    var learned = 0.0;
    if (taste.categories.isNotEmpty) {
      for (final category in _categoriesOf(activity)) {
        final weight = taste.categories[category] ?? 0;
        learned += weight;
        if (weight > 0 &&
            (liked == null || weight > taste.categories[liked]!)) {
          liked = category;
        }
      }
      learned = learned.clamp(-_maxTaste, _maxTaste);
    }

    final TopPickReason? reason = friends.isNotEmpty
        ? FriendsGoing(friends)
        : shared.isNotEmpty
        ? SharedInterest(shared.first)
        : liked != null && learned > 0
        ? SharedInterest(liked)
        : settingMatches
        ? PreferredSetting(setting)
        : null;

    final match =
        friends.length * _friendWeight +
        shared.length * _interestWeight +
        (settingMatches ? _settingWeight : 0) +
        learned;
    final skips = taste.skips[activity.id] ?? 0;
    final hours = activity.dateTime.difference(at).inMinutes / 60;
    final near = distance == null
        ? 0
        : _nearWeight * math.exp(-distance / _nearKm);
    final soon = _soonWeight * math.exp(-hours / _soonHours);

    candidates.add(
      _Candidate(
        activity: activity,
        matches: match > 0,
        score: match > 0 ? match + near + soon - skips * _skipPenalty : 0,
        skips: skips,
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

  final matching = candidates.where((c) => c.matches).toList()
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final near = byDistance(a, b);
      return near != 0 ? near : bySoonest(a, b);
    });

  final popular = candidates.where((c) => !c.matches).toList()
    ..sort((a, b) {
      final bySkips = a.skips.compareTo(b.skips);
      if (bySkips != 0) return bySkips;
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
        score: picked[i].score,
      ),
  ];
}

class _Candidate {
  const _Candidate({
    required this.activity,
    required this.matches,
    required this.score,
    required this.skips,
    required this.reason,
    required this.distance,
  });

  final Activity activity;
  final bool matches;
  final double score;
  final int skips;
  final TopPickReason? reason;
  final double? distance;
}
