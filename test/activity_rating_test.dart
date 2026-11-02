import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synk/l10n/l10n.dart';
import 'package:synk/models/activity_rating_model.dart';
import 'package:synk/views/home/widgets/half_star_rating_input.dart';

// Hosts the input with real localizations and keeps its value.
class _Harness extends StatefulWidget {
  const _Harness({required this.locale});

  final Locale locale;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int halfStars = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: widget.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: HalfStarRatingInput(
            halfStars: halfStars,
            starSize: 30,
            onChanged: (value) => setState(() => halfStars = value),
          ),
        ),
      ),
    );
  }
}

Future<_HarnessState> _pump(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(_Harness(locale: locale));
  await tester.pumpAndSettle();
  return tester.state<_HarnessState>(find.byType(_Harness));
}

// Taps [dx] pixels from the input's left edge.
Future<void> _tapAt(WidgetTester tester, double dx) async {
  final topLeft = tester.getTopLeft(find.byType(HalfStarRatingInput));
  await tester.tapAt(topLeft + Offset(dx, 15));
  await tester.pump();
}

void main() {
  group('formatHalfStars', () {
    test('shows whole and half stars', () {
      expect(formatHalfStars(1), '0.5');
      expect(formatHalfStars(8), '4');
      expect(formatHalfStars(9), '4.5');
      expect(formatHalfStars(10), '5');
    });
  });

  group('HalfStarRatingInput in English', () {
    testWidgets('a tap picks half stars from the left', (tester) async {
      final state = await _pump(tester, const Locale('en'));

      await _tapAt(tester, 5);
      expect(state.halfStars, 1);

      await _tapAt(tester, 75);
      expect(state.halfStars, 5);

      await _tapAt(tester, 149);
      expect(state.halfStars, 10);
    });

    testWidgets('tapping the same value clears it', (tester) async {
      final state = await _pump(tester, const Locale('en'));

      await _tapAt(tester, 75);
      expect(state.halfStars, 5);
      await _tapAt(tester, 75);
      expect(state.halfStars, 0);
    });
  });

  group('HalfStarRatingInput in Arabic', () {
    testWidgets('stars fill from the right', (tester) async {
      final state = await _pump(tester, const Locale('ar'));

      await _tapAt(tester, 149);
      expect(state.halfStars, 1);

      await _tapAt(tester, 5);
      expect(state.halfStars, 10);
    });

    testWidgets('uses the Arabic accessibility label', (tester) async {
      final handle = tester.ensureSemantics();
      final state = await _pump(tester, const Locale('ar'));
      await _tapAt(tester, 75);
      expect(state.halfStars, 5);

      final semantics = tester.getSemantics(
        find.byType(HalfStarRatingInput),
      );
      expect(semantics.label, 'التقييم');
      expect(semantics.value, '2.5 من 5 نجوم');
      handle.dispose();
    });
  });

  group('PendingActivityRating.fromMap', () {
    test('reads the activity and the people to rate', () {
      final pending = PendingActivityRating.fromMap({
        'id': 'a1',
        'title': 'Padel',
        'starts_at': '2026-10-20T15:00:00Z',
        'ends_at': '2026-10-20T17:00:00Z',
        'is_public': true,
        'participants': [
          {
            'user_id': 'u1',
            'full_name': 'Laila',
            'username': 'laila',
            'is_host': true,
          },
        ],
      });

      expect(pending.activity.id, 'a1');
      expect(pending.activity.title, 'Padel');
      expect(pending.participants.single.userId, 'u1');
      expect(pending.participants.single.isHost, isTrue);
    });
  });
}
