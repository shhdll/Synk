import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/views/home/widgets/activity_status_chip.dart';

void main() {
  Activity activity({required int joined, required int max}) {
    return Activity(
      id: 'a',
      title: 'Padel',
      dateTime: DateTime.now().add(const Duration(days: 1)),
      location: 'Riyadh',
      participantsCount: joined,
      maxParticipants: max,
    );
  }

  group('ActivityAvailability', () {
    test('is Available with two or more spots open', () {
      expect(
        activity(joined: 2, max: 4).availability,
        ActivityAvailability.available,
      );
    });

    test('is One More Needed with exactly one spot open', () {
      expect(
        activity(joined: 3, max: 4).availability,
        ActivityAvailability.oneMoreNeeded,
      );
    });

    test('is Full with no spots open', () {
      expect(
        activity(joined: 4, max: 4).availability,
        ActivityAvailability.full,
      );
    });

    test('labels match the user story wording', () {
      expect(ActivityAvailability.available.label, 'Available');
      expect(ActivityAvailability.oneMoreNeeded.label, 'One More Needed');
      expect(ActivityAvailability.full.label, 'Full');
    });
  });

  testWidgets('ActivityStatusChip shows the status label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActivityStatusChip(availability: ActivityAvailability.full),
        ),
      ),
    );

    expect(find.text('Full'), findsOneWidget);
  });
}
