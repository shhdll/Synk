import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/models/surprise_me.dart';
import 'package:synk/models/top_picks.dart';

void main() {
  // Wednesday 25 Nov 2026, 10:00. Its week runs Sun 22 - Sat 28 Nov.
  final now = DateTime(2026, 11, 25, 10);

  Activity activity(String id, {DateTime? at, ActivitySetting? setting}) {
    return Activity(
      id: id,
      title: id,
      dateTime: at ?? now.add(const Duration(hours: 3)),
      location: 'Riyadh',
      setting: setting,
    );
  }

  TopPick pick(Activity activity, {double score = 0}) => TopPick(
    rank: 1,
    activity: activity,
    reason: const PopularNearYou(),
    score: score,
  );

  group('pickSurprise', () {
    test('returns null when there is nothing to pick', () {
      expect(pickSurprise(ranked: const [], now: now), isNull);
    });

    test('picks the only activity there is', () {
      final only = activity('padel');
      expect(pickSurprise(ranked: [pick(only)], now: now), only);
    });

    test('never picks an activity that already started', () {
      final started = activity(
        'started',
        at: now.subtract(const Duration(minutes: 5)),
      );
      expect(pickSurprise(ranked: [pick(started)], now: now), isNull);
    });

    test('leaves out activities that clash with the user\'s plans', () {
      final clash = activity('clash');
      final free = activity('free');
      for (var seed = 0; seed < 20; seed++) {
        expect(
          pickSurprise(
            ranked: [pick(clash), pick(free)],
            clashes: (a) => a.id == 'clash',
            random: math.Random(seed),
            now: now,
          ),
          free,
        );
      }
    });

    test('shuffle again shows a different activity when there is one', () {
      final a = activity('a');
      final b = activity('b');
      for (var seed = 0; seed < 20; seed++) {
        expect(
          pickSurprise(
            ranked: [pick(a), pick(b)],
            avoidId: 'a',
            random: math.Random(seed),
            now: now,
          ),
          b,
        );
      }
    });

    test('shuffle again can repeat the only activity there is', () {
      final only = activity('only');
      expect(
        pickSurprise(ranked: [pick(only)], avoidId: 'only', now: now),
        only,
      );
    });

    test('activities that suit the user come up more often', () {
      final liked = activity('liked');
      final other = activity('other');
      final random = math.Random(1);
      var likedCount = 0;
      for (var i = 0; i < 2000; i++) {
        final picked = pickSurprise(
          ranked: [pick(liked, score: 4), pick(other)],
          random: random,
          now: now,
        );
        if (picked == liked) likedCount++;
      }
      // Weights 5 to 1, so about 5 in 6.
      expect(likedCount, inInclusiveRange(1550, 1780));
    });

    test('every activity can still come up', () {
      final liked = activity('liked');
      final other = activity('other');
      final random = math.Random(2);
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.add(
          pickSurprise(
            ranked: [pick(liked, score: 4), pick(other)],
            random: random,
            now: now,
          )!.id,
        );
      }
      expect(seen, {'liked', 'other'});
    });
  });

  group('SurpriseFilter', () {
    test('starts with nothing chosen', () {
      expect(SurpriseFilter.none.isActive, isFalse);
      expect(SurpriseFilter.none.matches(activity('a'), now), isTrue);
    });

    test('today keeps only activities later today', () {
      const filter = SurpriseFilter(time: SurpriseTime.today);
      expect(filter.isActive, isTrue);
      expect(
        filter.matches(
          activity('tonight', at: DateTime(2026, 11, 25, 21)),
          now,
        ),
        isTrue,
      );
      expect(
        filter.matches(
          activity('tomorrow', at: DateTime(2026, 11, 26, 9)),
          now,
        ),
        isFalse,
      );
    });

    test('this week ends on Saturday night', () {
      const filter = SurpriseFilter(time: SurpriseTime.thisWeek);
      expect(
        filter.matches(
          activity('sat', at: DateTime(2026, 11, 28, 23, 30)),
          now,
        ),
        isTrue,
      );
      expect(
        filter.matches(activity('sun', at: DateTime(2026, 11, 29, 9)), now),
        isFalse,
      );
    });

    test('this week on a Saturday is just that day', () {
      const filter = SurpriseFilter(time: SurpriseTime.thisWeek);
      final saturday = DateTime(2026, 11, 28, 10);
      expect(
        filter.matches(
          activity('sat', at: DateTime(2026, 11, 28, 20)),
          saturday,
        ),
        isTrue,
      );
      expect(
        filter.matches(
          activity('sun', at: DateTime(2026, 11, 29, 8)),
          saturday,
        ),
        isFalse,
      );
    });

    test('indoor and outdoor match the activity setting', () {
      final inside = activity('in', setting: ActivitySetting.indoor);
      final outside = activity('out', setting: ActivitySetting.outdoor);
      final unknown = activity('unknown');
      const indoor = SurpriseFilter(setting: SurpriseSetting.indoor);
      const outdoor = SurpriseFilter(setting: SurpriseSetting.outdoor);

      expect(indoor.matches(inside, now), isTrue);
      expect(indoor.matches(outside, now), isFalse);
      expect(indoor.matches(unknown, now), isFalse);
      expect(outdoor.matches(outside, now), isTrue);
    });

    test('the filter is applied when picking', () {
      final inside = activity('in', setting: ActivitySetting.indoor);
      final outside = activity('out', setting: ActivitySetting.outdoor);
      for (var seed = 0; seed < 20; seed++) {
        expect(
          pickSurprise(
            ranked: [pick(inside), pick(outside)],
            filter: const SurpriseFilter(setting: SurpriseSetting.outdoor),
            random: math.Random(seed),
            now: now,
          ),
          outside,
        );
      }
    });
  });
}
