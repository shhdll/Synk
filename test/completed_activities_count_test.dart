import 'package:flutter_test/flutter_test.dart';
import 'package:synk/models/activity_model.dart';

void main() {
  const me = 'user-me';
  final past = DateTime.now().subtract(const Duration(days: 2));
  final future = DateTime.now().add(const Duration(days: 2));

  Activity activity(
    String id, {
    required DateTime at,
    String? hostId,
    String? status,
  }) {
    return Activity(
      id: id,
      title: id,
      dateTime: at,
      location: 'Somewhere',
      hostId: hostId,
      participationStatus: status,
    );
  }

  ActivityStore storeWith({
    List<Activity> mine = const [],
    List<Activity> participating = const [],
  }) {
    return ActivityStore()
      ..currentUserId = me
      ..setMine(mine)
      ..setParticipating(participating);
  }

  test('counts past activities the user hosted', () {
    final store = storeWith(
      mine: [
        activity('hosted-past', at: past, hostId: me),
        activity('hosted-future', at: future, hostId: me),
      ],
    );

    expect(store.completedCount, 1);
  });

  test('counts past activities the user joined', () {
    final store = storeWith(
      participating: [
        activity('joined-past', at: past, hostId: 'other', status: 'joined'),
        activity('joined-future', at: future, hostId: 'other', status: 'joined'),
      ],
    );

    expect(store.completedCount, 1);
  });

  test('ignores pending and waitlisted requests', () {
    final store = storeWith(
      participating: [
        activity('pending', at: past, hostId: 'other', status: 'pending'),
        activity('waitlisted', at: past, hostId: 'other', status: 'waitlisted'),
      ],
    );

    expect(store.completedCount, 0);
  });

  test('counts an activity once when it is both hosted and joined', () {
    final store = storeWith(
      mine: [activity('same', at: past, hostId: me)],
      participating: [
        activity('same', at: past, hostId: me, status: 'joined'),
      ],
    );

    expect(store.completedCount, 1);
  });

  test('is zero with no activities', () {
    expect(storeWith().completedCount, 0);
  });
}
