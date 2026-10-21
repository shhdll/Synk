import 'package:flutter_test/flutter_test.dart';
import 'package:synk/models/activities_model.dart';
import 'package:synk/models/activity_model.dart';

Activity activity(String id, DateTime start, DateTime end, String? status) =>
    Activity(
      id: id,
      title: id,
      description: '',
      location: '',
      dateTime: start,
      endsAt: end,
      hostId: 'host-$id',
      maxParticipants: 10,
      isPublic: true,
      participationStatus: status,
    );

void main() {
  final start = DateTime(2026, 10, 22, 18);
  final target = activity('target', start, start.add(const Duration(hours: 2)), null);

  test('detects overlapping pending and waitlisted activities', () {
    expect(
      ActivitiesModel.hasPendingOverlap(target, [
        activity('pending', start.add(const Duration(minutes: 30)),
            start.add(const Duration(hours: 3)), 'pending'),
      ]),
      isTrue,
    );
    expect(
      ActivitiesModel.hasPendingOverlap(target, [
        activity('waitlisted', start.add(const Duration(minutes: 30)),
            start.add(const Duration(hours: 3)), 'waitlisted'),
      ]),
      isTrue,
    );
  });

  test('ignores nonpending entries, same activity, and touching boundaries', () {
    expect(
      ActivitiesModel.hasPendingOverlap(target, [
        activity('joined', start, start.add(const Duration(hours: 1)), 'joined'),
        activity('target', start, start.add(const Duration(hours: 1)), 'pending'),
        activity('touching', start.add(const Duration(hours: 2)),
            start.add(const Duration(hours: 3)), 'pending'),
      ]),
      isFalse,
    );
  });

  test('ignores same-day activities that do not overlap', () {
    expect(
      ActivitiesModel.hasPendingOverlap(target, [
        activity('later', start.add(const Duration(hours: 3)),
            start.add(const Duration(hours: 4)), 'waitlisted'),
      ]),
      isFalse,
    );
  });
}
