import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synk/controllers/activity_save_messages.dart';
import 'package:synk/controllers/create_activity_controller.dart';
import 'package:synk/controllers/language_controller.dart';
import 'package:synk/core/constants/activity_constants.dart';
import 'package:synk/l10n/l10n.dart';
import 'package:synk/models/activities_model.dart';
import 'package:synk/models/activity_model.dart';
import 'package:synk/models/activity_save_model.dart';
import 'package:synk/models/pending_activity_save_store.dart';
import 'package:synk/utils/activity_photo_jpeg.dart';
import 'package:synk/views/create_activity/activity_rejected_dialog.dart';

// Answers saves from a script and records what was sent.
class _FakeSaveService implements ActivitySaveService {
  _FakeSaveService(this.answers);

  final List<ActivitySaveResult> answers;
  final List<ActivitySaveRequest> sent = [];

  @override
  Future<ActivitySaveResult> save(ActivitySaveRequest request) async {
    sent.add(request);
    return answers.length > 1 ? answers.removeAt(0) : answers.first;
  }
}

class _FakeActivitiesModel implements ActivitiesModel {
  _FakeActivitiesModel({this.latest});

  final Activity? latest;

  @override
  String? get currentUserId => 'me';

  @override
  Future<String?> checkScheduleConflict({
    required DateTime startsAt,
    required DateTime endsAt,
    String? excludedActivityId,
  }) async => null;

  @override
  Future<Activity?> fetchById(String id) async => latest;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Activity _activity({String id = 'a1', int? version = 3, String? photoUrl}) =>
    Activity(
      id: id,
      title: 'Padel night',
      hostId: 'me',
      hostName: 'Amal',
      dateTime: DateTime.now().add(const Duration(days: 2)),
      location: 'Kingdom Arena',
      maxParticipants: 4,
      setting: ActivitySetting.indoor,
      photoUrl: photoUrl,
      editVersion: version,
    );

ActivitySaveResult _saved([Activity? activity]) => ActivitySaveResult(
  ActivitySaveCode.saved,
  activity: activity ?? _activity(),
);

CreateActivityController _filledController(
  _FakeSaveService service, {
  Activity? editing,
  ActivitiesModel? model,
}) {
  final controller = CreateActivityController(
    activitiesModel: model ?? _FakeActivitiesModel(),
    activity: editing,
    saveService: service,
    currentUserId: () => 'me',
  );
  if (editing == null) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    controller.titleController.text = 'Padel night';
    controller.setPlace(name: 'Kingdom Arena', latitude: 24.7, longitude: 46.6);
    controller.setSetting(ActivitySetting.indoor);
    controller.setDate(tomorrow);
    controller.setTime(const TimeOfDay(hour: 18, minute: 0));
  }
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('save request', () {
    final request = ActivitySaveRequest(
      operation: ActivitySaveOperation.update,
      requestId: newUuidV4(),
      activityId: 'a1',
      expectedVersion: 4,
      activity: ActivitySaveRequest.fieldsFor(_activity()),
      photoChange: ActivityPhotoChange.keep,
    );

    test('sends only the allowed fields, never host or photo URL', () {
      final body = request.toBody();
      expect(body.keys.toSet(), {
        'operation',
        'request_id',
        'activity_id',
        'expected_version',
        'activity',
        'photo',
      });
      final activity = body['activity']! as Map;
      expect(activity.keys, isNot(contains('host_id')));
      expect(activity.keys, isNot(contains('photo_url')));
      expect(activity.keys, isNot(contains('activity_code')));
      expect(body['photo'], {'action': 'keep'});
      expect(activity['description'], isNull);
    });

    test('a create has no expected version; a replace carries the photo', () {
      final create = ActivitySaveRequest(
        operation: ActivitySaveOperation.create,
        requestId: newUuidV4(),
        activityId: newUuidV4(),
        activity: const {'title': 'x'},
        photoChange: ActivityPhotoChange.replace,
        photoPath: '/tmp/x.jpg',
      );
      final body = create.toBody(jpegBase64: 'AAAA');
      expect(body.containsKey('expected_version'), isFalse);
      expect(body['photo'], {'action': 'replace', 'jpeg_base64': 'AAAA'});
    });

    test('survives being stored on the device', () {
      final copy = ActivitySaveRequest.fromJson(
        jsonDecode(jsonEncode(request.toJson())),
      )!;
      expect(copy.requestId, request.requestId);
      expect(copy.sameContentAs(request), isTrue);
      expect(ActivitySaveRequest.fromJson({'operation': 'nope'}), isNull);
    });

    test('request ids are random version 4 UUIDs', () {
      final ids = List.generate(200, (_) => newUuidV4());
      expect(ids.toSet().length, 200);
      for (final id in ids) {
        expect(
          id,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
      }
    });
  });

  group('save result', () {
    test('reads codes, fields and the activity', () {
      final result = ActivitySaveResult.fromResponse({
        'result': 'rejected',
        'fields': ['title', 'photo'],
        'request_id': 'r',
      });
      expect(result.code, ActivitySaveCode.rejected);
      expect(result.fields, ['title', 'photo']);
      expect(result.isFinal, isTrue);

      final saved = ActivitySaveResult.fromResponse({
        'result': 'saved',
        'activity': {
          'id': 'a1',
          'title': 'Padel',
          'starts_at': '2026-12-01T17:00:00Z',
          'edit_version': 2,
        },
      });
      expect(saved.isSaved, isTrue);
      expect(saved.activity?.editVersion, 2);
    });

    test('unknown or broken answers count as a failed save', () {
      for (final data in [
        null,
        'nope',
        42,
        {'result': 'surprise'},
      ]) {
        final result = ActivitySaveResult.fromResponse(data);
        expect(result.code, ActivitySaveCode.saveFailed);
        expect(result.isRetryable, isTrue);
      }
    });

    test('which codes may be retried with the same request', () {
      const retryable = {
        ActivitySaveCode.busy,
        ActivitySaveCode.moderationUnavailable,
        ActivitySaveCode.storageFailed,
        ActivitySaveCode.saveFailed,
        ActivitySaveCode.connectionLost,
      };
      for (final code in ActivitySaveCode.values) {
        expect(
          ActivitySaveResult(code).isRetryable,
          retryable.contains(code),
          reason: '$code',
        );
      }
    });

    test('HTTP errors map to codes', () {
      expect(
        ActivitySaveService.resultForHttpError(401).code,
        ActivitySaveCode.unauthorized,
      );
      expect(
        ActivitySaveService.resultForHttpError(413).code,
        ActivitySaveCode.payloadTooLarge,
      );
      expect(
        ActivitySaveService.resultForHttpError(400).code,
        ActivitySaveCode.invalidRequest,
      );
      expect(
        ActivitySaveService.resultForHttpError(503).code,
        ActivitySaveCode.saveFailed,
      );
    });

    test('every code has a fixed, translated message', () {
      for (final code in ActivitySaveCode.values) {
        if (code == ActivitySaveCode.saved) continue;
        final message = activitySaveMessage(
          ActivitySaveResult(code),
          editing: false,
        );
        expect(message, isNotEmpty, reason: '$code');
      }
      expect(
        activitySaveMessage(
          const ActivitySaveResult(
            ActivitySaveCode.rejected,
            fields: ['photo'],
          ),
          editing: false,
        ),
        appL10n.activityPhotoRejected,
      );
    });
  });

  group('pending saves', () {
    const store = PendingActivitySaveStore();
    ActivitySaveRequest request(String id, {String? photo}) =>
        ActivitySaveRequest(
          operation: ActivitySaveOperation.create,
          requestId: id,
          activityId: 'a1',
          activity: const {'title': 'x'},
          photoChange: photo == null
              ? ActivityPhotoChange.none
              : ActivityPhotoChange.replace,
          photoPath: photo,
        );

    test('kept per user until cleared with the same request id', () async {
      await store.save('me', request('r1'));
      expect((await store.load('me'))?.requestId, 'r1');
      expect(await store.load('someone else'), isNull);

      await store.clear('me', requestId: 'other');
      expect((await store.load('me'))?.requestId, 'r1');

      await store.clear('me', requestId: 'r1');
      expect(await store.load('me'), isNull);
    });

    test('clearing removes its photo unless asked not to', () async {
      final dir = await Directory.systemTemp.createTemp('pending');
      final photo = File('${dir.path}/p.jpg')..writeAsBytesSync([1, 2, 3]);
      await store.save('me', request('r2', photo: photo.path));
      await store.clear('me', requestId: 'r2', deletePhoto: false);
      expect(photo.existsSync(), isTrue);

      await store.save('me', request('r3', photo: photo.path));
      await store.clear('me', requestId: 'r3');
      expect(photo.existsSync(), isFalse);
      await dir.delete(recursive: true);
    });

    test('an unreadable entry is dropped', () async {
      SharedPreferences.setMockInitialValues({
        'pending_activity_save.me': '{not json',
      });
      expect(await store.load('me'), isNull);
    });
  });

  group('photo preparation', () {
    test('turns a PNG into a JPEG', () {
      final source = img.Image(width: 300, height: 100);
      img.fill(source, color: img.ColorRgb8(200, 80, 40));
      final jpeg = encodeActivityJpeg(
        Uint8List.fromList(img.encodePng(source)),
      )!;
      expect(jpeg.sublist(0, 3), [0xFF, 0xD8, 0xFF]);
      expect(img.decodeJpg(jpeg)!.width, 300);
    });

    test('applies the EXIF rotation, then drops EXIF and GPS', () {
      final source = img.Image(width: 300, height: 100);
      img.fill(source, color: img.ColorRgb8(200, 80, 40));
      source.exif.imageIfd.orientation = 6; // shown rotated 90°
      source.exif.gpsIfd['GPSLatitude'] = img.IfdValueAscii('24.7136');
      final tagged = img.encodeJpg(source);
      expect(latin1.decode(tagged, allowInvalid: true), contains('Exif'));

      final jpeg = encodeActivityJpeg(Uint8List.fromList(tagged))!;
      final decoded = img.decodeJpg(jpeg)!;
      expect([decoded.width, decoded.height], [100, 300]);
      expect(decoded.exif.isEmpty, isTrue);
      final text = latin1.decode(jpeg, allowInvalid: true);
      expect(text, isNot(contains('Exif')));
      expect(text, isNot(contains('24.7136')));
    });

    test('wide photos are scaled to 1600 px', () {
      final source = img.Image(width: 3200, height: 1600);
      final jpeg = encodeActivityJpeg(
        Uint8List.fromList(img.encodeJpg(source)),
      )!;
      expect(img.decodeJpg(jpeg)!.width, 1600);
      expect(jpeg.length, lessThanOrEqualTo(ActivitySaveLimits.photoBytes));
    });

    test('not an image: null', () {
      expect(encodeActivityJpeg(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });

  group('create form', () {
    test(
      'a clean save returns the activity and clears the pending save',
      () async {
        final service = _FakeSaveService([_saved()]);
        final controller = _filledController(service);
        final result = await controller.submit();

        expect(result.created, isTrue);
        final sent = service.sent.single;
        expect(sent.operation, ActivitySaveOperation.create);
        expect(sent.photoChange, ActivityPhotoChange.none);
        expect(sent.expectedVersion, isNull);
        expect(await const PendingActivitySaveStore().load('me'), isNull);
      },
    );

    test(
      'rejected fields are highlighted and block saving until changed',
      () async {
        final service = _FakeSaveService([
          const ActivitySaveResult(
            ActivitySaveCode.rejected,
            fields: ['title', 'description'],
          ),
        ]);
        final controller = _filledController(service);
        final result = await controller.submit();

        expect(result.created, isFalse);
        expect(
          controller.errorFor(CreateField.title),
          appL10n.activityFieldRejected,
        );
        expect(controller.descriptionError, appL10n.activityFieldRejected);
        expect(controller.errorMessage, appL10n.activityGuidelinesRejected);
        expect(controller.firstFlaggedStep, 0);
        expect(controller.canSubmit, isFalse);
        // The form keeps everything that was typed.
        expect(controller.titleController.text, 'Padel night');

        controller.titleController.text = 'Padel evening';
        controller.descriptionController.text = 'All levels';
        expect(controller.errorFor(CreateField.title), isNull);
        expect(controller.descriptionError, isNull);
        expect(controller.canSubmit, isTrue);
      },
    );

    test('a retry with the same content reuses the request id', () async {
      final service = _FakeSaveService([
        const ActivitySaveResult(ActivitySaveCode.moderationUnavailable),
        const ActivitySaveResult(ActivitySaveCode.moderationUnavailable),
        _saved(),
      ]);
      final controller = _filledController(service);
      await controller.submit();
      expect(controller.errorMessage, appL10n.activityCheckUnavailable);
      // Still pending on the device until a final answer.
      expect(
        (await const PendingActivitySaveStore().load('me'))?.requestId,
        service.sent.first.requestId,
      );
      await controller.submit();
      expect(service.sent[1].requestId, service.sent[0].requestId);

      controller.titleController.text = 'Padel evening';
      await controller.submit();
      expect(service.sent[2].requestId, isNot(service.sent[0].requestId));
      // One activity id for the whole form.
      expect(service.sent.map((r) => r.activityId).toSet().length, 1);
    });

    test('request_mismatch is never resent automatically', () async {
      final service = _FakeSaveService([
        const ActivitySaveResult(ActivitySaveCode.requestMismatch),
        _saved(),
      ]);
      final controller = _filledController(service);
      await controller.submit();
      expect(service.sent.length, 1);
      expect(controller.errorMessage, appL10n.somethingWentWrongPleaseTryAgain);
      expect(await const PendingActivitySaveStore().load('me'), isNull);
      expect(controller.titleController.text, 'Padel night');

      // The next deliberate tap is a new attempt.
      await controller.submit();
      expect(service.sent[1].requestId, isNot(service.sent[0].requestId));
    });

    test('busy waits and asks once more with the same request', () async {
      final service = _FakeSaveService([
        const ActivitySaveResult(ActivitySaveCode.busy, retryAfterSeconds: 1),
        _saved(),
      ]);
      final controller = _filledController(service);
      final result = await controller.submit();
      expect(result.created, isTrue);
      expect(service.sent.length, 2);
      expect(service.sent[1].requestId, service.sent[0].requestId);
    });

    test('schedule and capacity codes keep their existing behaviour', () async {
      final schedule = _filledController(
        _FakeSaveService([
          const ActivitySaveResult(ActivitySaveCode.scheduleConflict),
        ]),
      );
      await schedule.submit();
      expect(schedule.hasScheduleConflict, isTrue);
      expect(
        schedule.errorFor(CreateField.time),
        appL10n.youAlreadyHaveAnActivityAtThisTime,
      );

      final capacity = _filledController(
        _FakeSaveService([
          const ActivitySaveResult(ActivitySaveCode.capacityBelowParticipants),
        ]),
      );
      await capacity.submit();
      expect(capacity.hasCapacityConflict, isTrue);
      expect(capacity.errorMessage, appL10n.capacityBelowParticipants);
    });
  });

  group('edit form', () {
    test('sends the version it started from and keeps the photo', () async {
      final service = _FakeSaveService([_saved()]);
      final controller = _filledController(
        service,
        editing: _activity(photoUrl: 'https://x/p.jpg'),
      );
      controller.setTime(const TimeOfDay(hour: 19, minute: 0));
      final result = await controller.submit();
      expect(result.created, isTrue);
      expect(service.sent.single.operation, ActivitySaveOperation.update);
      expect(service.sent.single.expectedVersion, 3);
      expect(service.sent.single.photoChange, ActivityPhotoChange.keep);
      // Host details the server doesn't send are kept.
      expect(result.activity?.hostName, 'Amal');
    });

    test('removing the photo is sent as remove', () async {
      final service = _FakeSaveService([_saved()]);
      final controller = _filledController(
        service,
        editing: _activity(photoUrl: 'https://x/p.jpg'),
      );
      controller.removePhoto();
      await controller.submit();
      expect(service.sent.single.photoChange, ActivityPhotoChange.remove);
    });

    test(
      'a conflict returns the latest version instead of overwriting',
      () async {
        final latest = _activity(version: 5);
        final service = _FakeSaveService([
          ActivitySaveResult(ActivitySaveCode.conflict, activity: latest),
        ]);
        final controller = _filledController(service, editing: _activity());
        final result = await controller.submit();
        expect(result.created, isFalse);
        expect(result.latestActivity?.editVersion, 5);
        expect(controller.errorMessage, appL10n.activityChangedElsewhere);
      },
    );

    test('deleted or no longer the host closes the editor', () async {
      for (final code in [
        ActivitySaveCode.notFound,
        ActivitySaveCode.notHost,
      ]) {
        final controller = _filledController(
          _FakeSaveService([ActivitySaveResult(code)]),
          editing: _activity(),
        );
        final result = await controller.submit();
        expect(result.closeEditor, isTrue, reason: '$code');
      }
    });

    test('an activity loaded without a version reads it first', () async {
      final service = _FakeSaveService([_saved()]);
      final controller = _filledController(
        service,
        editing: _activity(version: null),
        model: _FakeActivitiesModel(latest: _activity(version: 7)),
      );
      await controller.submit();
      expect(service.sent.single.expectedVersion, 7);
    });
  });

  group('activity titles', () {
    final controller = CreateActivityController(
      activitiesModel: _FakeActivitiesModel(),
      saveService: _FakeSaveService([_saved()]),
    );

    test('English, Arabic and mixed titles are valid', () {
      for (final title in [
        'Padel night',
        'ليلة بادل',
        'بادل night مع Sara',
        'Coffee & كتب, 7 pm',
        'قَهْوَة الصباح',
        "Ahmad's بادل",
      ]) {
        expect(controller.validateTitle(title), isNull, reason: title);
      }
    });

    test('the same length and punctuation rules apply in Arabic', () {
      expect(
        controller.validateTitle('ب' * (ActivityConstants.titleMaxLength + 1)),
        appL10n.keepItToLetters(ActivityConstants.titleMaxLength),
      );
      expect(
        controller.validateTitle('ب' * ActivityConstants.titleMaxLength),
        isNull,
      );
      // Only & ' , and digits 0-9, as before.
      expect(controller.validateTitle('بادل، مساء'), appL10n.useLettersOnly);
      expect(controller.validateTitle('بادل ٧ مساء'), appL10n.useLettersOnly);
      expect(controller.validateTitle('Padel!'), appL10n.useLettersOnly);
    });

    test('Arabic letters and harakat can be typed', () {
      for (final rune in 'ليلة بادلَ'.runes) {
        expect(CreateActivityController.isAllowedTitleRune(rune), isTrue);
      }
      expect(
        CreateActivityController.isAllowedTitleRune('،'.runes.single),
        isFalse,
      );
      expect(
        CreateActivityController.isAllowedTitleRune('!'.runes.single),
        isFalse,
      );
    });

    for (final title in ['Padel night', 'ليلة بادل', 'بادل night مع Sara']) {
      test('"$title" is sent as typed and saved', () async {
        final service = _FakeSaveService([_saved()]);
        final form = _filledController(service)..titleController.text = title;
        final result = await form.submit();
        expect(result.created, isTrue);
        expect(service.sent.single.activity['title'], title);
      });
    }

    for (final title in ['يا كلب', 'Padel for idiots']) {
      test(
        'an inappropriate title ("$title") is highlighted, not saved',
        () async {
          final service = _FakeSaveService([
            const ActivitySaveResult(
              ActivitySaveCode.rejected,
              fields: ['title'],
            ),
          ]);
          final form = _filledController(service)..titleController.text = title;
          final result = await form.submit();
          expect(result.created, isFalse);
          expect(
            form.errorFor(CreateField.title),
            appL10n.activityFieldRejected,
          );
          expect(form.errorMessage, appL10n.activityGuidelinesRejected);
          expect(form.firstFlaggedStep, 0);
          expect(form.titleController.text, title);
          expect(form.canSubmit, isFalse);
        },
      );
    }
  });

  group('rejected content', () {
    tearDown(() => LanguageController.instance.setLocale(const Locale('en')));

    const photoUrl =
        'https://x.supabase.co/storage/v1/object/public/activity-photos/me/a1.jpg';
    const steps = {'title': 0, 'location': 0, 'description': 1, 'photo': 1};

    String labelFor(AppLocalizations l10n, String field) => switch (field) {
      'title' => l10n.activityTitle,
      'location' => l10n.location,
      'description' => l10n.description,
      _ => l10n.photo,
    };

    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final field in steps.keys) {
        test(
          '${locale.languageCode}: a rejected $field is flagged and the form '
          'keeps its data and photo',
          () async {
            await LanguageController.instance.setLocale(locale);
            final l10n = lookupAppLocalizations(locale);
            final service = _FakeSaveService([
              ActivitySaveResult(ActivitySaveCode.rejected, fields: [field]),
            ]);
            final controller = _filledController(
              service,
              editing: _activity(photoUrl: photoUrl),
            );
            controller.descriptionController.text = 'All levels';
            final result = await controller.submit();

            expect(result.activity, isNull);
            expect(controller.hasFlaggedContent, isTrue);
            expect(controller.flaggedFields, [field]);
            expect(controller.firstFlaggedStep, steps[field]);
            expect(controller.canSubmit, isFalse);
            switch (field) {
              case 'title':
                expect(
                  controller.errorFor(CreateField.title),
                  l10n.activityFieldRejected,
                );
              case 'location':
                expect(
                  controller.errorFor(CreateField.location),
                  l10n.activityFieldRejected,
                );
              case 'description':
                expect(controller.descriptionError, l10n.activityFieldRejected);
              case 'photo':
                expect(controller.photoError, l10n.activityPhotoRejected);
            }
            // Nothing typed or chosen is lost.
            expect(controller.titleController.text, 'Padel night');
            expect(controller.descriptionController.text, 'All levels');
            expect(controller.existingPhotoUrl, photoUrl);
          },
        );

        testWidgets(
          '${locale.languageCode}: the popup names the $field and lists the '
          'guidelines only',
          (tester) async {
            final l10n = lookupAppLocalizations(locale);
            await tester.pumpWidget(
              MaterialApp(
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Builder(
                  builder: (context) => TextButton(
                    onPressed: () =>
                        showActivityRejectedDialog(context, fields: [field]),
                    child: const Text('open'),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('open'));
            await tester.pumpAndSettle();

            expect(find.text(l10n.activityRejectedTitle), findsOneWidget);
            expect(find.text(l10n.activityRejectedMessage), findsOneWidget);
            expect(find.text(l10n.activityRejectedGuidelines), findsOneWidget);
            expect(find.text(l10n.activityNeedsReview), findsOneWidget);
            expect(find.text(labelFor(l10n, field)), findsOneWidget);
            for (final other in steps.keys.where((f) => f != field)) {
              expect(find.text(labelFor(l10n, other)), findsNothing);
            }
            // No provider, category, score or technical detail.
            expect(
              find.textContaining(
                RegExp(
                  r'openai|score|categor|moderation|error|flagged',
                  caseSensitive: false,
                ),
              ),
              findsNothing,
            );

            await tester.tap(find.text(l10n.reviewActivity));
            await tester.pumpAndSettle();
            expect(find.text(l10n.activityRejectedTitle), findsNothing);
          },
        );
      }
    }

    test('the popup text matches what was agreed', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(en.activityRejectedTitle, 'Content couldn’t be published');
      expect(en.reviewActivity, 'Review activity');
      expect(en.activityRejectedGuidelines.split('\n'), [
        '• Violence or threats',
        '• Hate or harassment',
        '• Self-harm',
        '• Illegal or dangerous content',
        '• Sexual or explicit content',
      ]);
      expect(ar.activityRejectedTitle, 'تعذر نشر المحتوى');
      expect(ar.reviewActivity, 'مراجعة الفعالية');
      expect(ar.activityRejectedGuidelines.split('\n'), hasLength(5));
      expect(
        ar.activityRejectedGuidelines.split('\n').last,
        '• محتوى جنسي أو صريح',
      );
    });

    test(
      'a failed check is not a rejection: retry message, no popup',
      () async {
        final controller = _filledController(
          _FakeSaveService([
            const ActivitySaveResult(ActivitySaveCode.moderationUnavailable),
          ]),
        );
        final result = await controller.submit();
        expect(result.activity, isNull);
        expect(controller.hasFlaggedContent, isFalse);
        expect(controller.flaggedFields, isEmpty);
        expect(controller.errorMessage, appL10n.activityCheckUnavailable);
      },
    );
  });
}
