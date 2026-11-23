import 'package:flutter_test/flutter_test.dart';
import 'package:synk/models/activity_model.dart';

// The profile's activities count and the weekly streak count only
// activities the user checked in to. The server works out which ones; the
// store just holds the result.
void main() {
  const me = 'user-me';
  final past = DateTime.now().subtract(const Duration(days: 2));

  ActivityStore storeWith({List<Activity> mine = const []}) {
    return ActivityStore()
      ..currentUserId = me
      ..setMine(mine);
  }

  test('hosted or joined activities alone count for nothing', () {
    final store = storeWith(
      mine: [
        Activity(
          id: 'hosted-past',
          title: 'hosted-past',
          dateTime: past,
          location: 'Somewhere',
          hostId: me,
        ),
      ],
    );

    expect(store.checkedInCount, 0);
    expect(store.attendedTimes, isEmpty);
    expect(store.weeklyStreak.weeks, 0);
  });

  test('count and streak come from the checked-in activities', () {
    final store = storeWith();
    var notified = 0;
    store.addListener(() => notified++);

    store.setCheckedIn(count: 3, times: [past]);

    expect(notified, 1);
    expect(store.checkedInCount, 3);
    expect(store.attendedTimes, [past]);
    expect(store.weeklyStreak.weeks, greaterThan(0));
  });
}
