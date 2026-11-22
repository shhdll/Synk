import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:synk/controllers/activity_leave_controller.dart';
import 'package:synk/controllers/language_controller.dart';
import 'package:synk/l10n/l10n.dart';
import 'package:synk/models/activity_participation_model.dart';

// Answers remove_participant without a server.
class _FakeParticipationModel extends ActivityParticipationModel {
  _FakeParticipationModel(this.answer)
    : super(client: SupabaseClient('http://localhost', 'test-key'));

  final Map<String, dynamic>? answer;
  String? removedUserId;

  @override
  Future<ActivityJoinResult> removeParticipant({
    required String activityId,
    required String participantUserId,
  }) async {
    removedUserId = participantUserId;
    if (answer == null) throw Exception('offline');
    return ActivityJoinResult.fromJson(answer!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => LanguageController.instance.setLocale(const Locale('en')));

  Future<
    (ActivityJoinResult?, ActivityLeaveController, _FakeParticipationModel)
  >
  remove(Map<String, dynamic>? answer) async {
    final model = _FakeParticipationModel(answer);
    final controller = ActivityLeaveController(participationModel: model);
    final result = await controller.removeParticipant(
      activityId: 'activity-1',
      participantUserId: 'user-2',
    );
    return (result, controller, model);
  }

  group('ActivityLeaveController.removeParticipant', () {
    test('returns the result when the participant is removed', () async {
      final (result, controller, model) = await remove({
        'result': 'removed',
        'message': 'The participant was removed.',
      });

      expect(result?.result, 'removed');
      expect(model.removedUserId, 'user-2');
      expect(controller.errorMessage, isNull);
      expect(controller.isBusy('activity-1'), isFalse);
    });

    test('shows the reason when someone who is not the host tries', () async {
      final (result, controller, _) = await remove({
        'result': 'not_host',
        'message': 'Only the host can remove participants.',
      });

      expect(result, isNull);
      expect(controller.failureResult, 'not_host');
      expect(controller.errorMessage, 'Only the host can remove participants.');
    });

    test('refuses once the activity has started', () async {
      final (result, controller, _) = await remove({
        'result': 'activity_started',
        'message': 'This activity has already started.',
      });

      expect(result, isNull);
      expect(controller.failureResult, 'activity_started');
    });

    test('reports a participant who already left', () async {
      final (result, controller, _) = await remove({
        'result': 'not_eligible',
        'message': 'The selected participant is no longer in this activity.',
      });

      expect(result, isNull);
      expect(controller.failureResult, 'not_eligible');
    });

    test('falls back to a general error when the request fails', () async {
      final (result, controller, _) = await remove(null);

      expect(result, isNull);
      expect(controller.failureResult, isNull);
      expect(
        controller.errorMessage,
        'Unable to remove the participant. Please try again.',
      );
    });
  });

  group('removed participant messages in Arabic', () {
    setUp(() => LanguageController.instance.setLocale(const Locale('ar')));

    test('only the host can remove participants', () {
      expect(
        serverMessage('Only the host can remove participants.'),
        'المنظم فقط يمكنه إزالة المشاركين',
      );
    });
  });
}
