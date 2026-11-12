import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'activity_model.dart';

// Creating and editing an activity goes through the `save-activity` Edge
// Function, which checks the title, description, location and photo for
// inappropriate content before anything is saved
// (supabase/functions/save-activity, supabase/ACTIVITY_MODERATION.md).

enum ActivitySaveOperation { create, update }

// What happens to the photo: nothing (new activity without one), keep the
// current one, remove it, or replace it with [ActivitySaveRequest.photoPath].
enum ActivityPhotoChange { none, keep, remove, replace }

// The server's result codes, plus [connectionLost] when no answer arrived.
enum ActivitySaveCode {
  saved,
  alreadyExists,
  rejected,
  invalid,
  photoInvalid,
  notFound,
  notHost,
  suspended,
  conflict,
  scheduleConflict,
  capacityBelowParticipants,
  scheduleTooFar,
  invalidTimeRange,
  requestMismatch,
  tooManyAttempts,
  rateLimited,
  busy,
  moderationUnavailable,
  storageFailed,
  saveFailed,
  unauthorized,
  invalidRequest,
  payloadTooLarge,
  connectionLost,
}

const Map<String, ActivitySaveCode> _codes = {
  'saved': ActivitySaveCode.saved,
  'already_exists': ActivitySaveCode.alreadyExists,
  'rejected': ActivitySaveCode.rejected,
  'invalid': ActivitySaveCode.invalid,
  'photo_invalid': ActivitySaveCode.photoInvalid,
  'not_found': ActivitySaveCode.notFound,
  'not_host': ActivitySaveCode.notHost,
  'suspended': ActivitySaveCode.suspended,
  'conflict': ActivitySaveCode.conflict,
  'schedule_conflict': ActivitySaveCode.scheduleConflict,
  'capacity_below_participants': ActivitySaveCode.capacityBelowParticipants,
  'schedule_too_far': ActivitySaveCode.scheduleTooFar,
  'invalid_time_range': ActivitySaveCode.invalidTimeRange,
  'request_mismatch': ActivitySaveCode.requestMismatch,
  'too_many_attempts': ActivitySaveCode.tooManyAttempts,
  'rate_limited': ActivitySaveCode.rateLimited,
  'busy': ActivitySaveCode.busy,
  'moderation_unavailable': ActivitySaveCode.moderationUnavailable,
  'storage_failed': ActivitySaveCode.storageFailed,
  'save_failed': ActivitySaveCode.saveFailed,
  'unauthorized': ActivitySaveCode.unauthorized,
  'invalid_request': ActivitySaveCode.invalidRequest,
  'payload_too_large': ActivitySaveCode.payloadTooLarge,
};

// The same limits the server applies (supabase/functions/save-activity).
abstract final class ActivitySaveLimits {
  static const int photoBytes = 2000000;
  static const int bodyBytes = 3040870; // 2.9 MiB
}

final Random _secureRandom = Random.secure();

// A random (version 4) UUID.
String newUuidV4() {
  final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

// One save, exactly as it is sent. Kept on the device until the server
// gives a final answer, so a retry (or reopening the app) sends the same
// request id and content and can't create a second activity.
@immutable
class ActivitySaveRequest {
  const ActivitySaveRequest({
    required this.operation,
    required this.requestId,
    required this.activityId,
    required this.activity,
    required this.photoChange,
    this.expectedVersion,
    this.photoPath,
  });

  final ActivitySaveOperation operation;
  final String requestId;
  final String activityId;
  final int? expectedVersion;

  // The activity fields, in the server's names.
  final Map<String, Object?> activity;
  final ActivityPhotoChange photoChange;

  // The prepared JPEG on this device, for [ActivityPhotoChange.replace].
  final String? photoPath;

  // The activity fields for [draft], as the server expects them.
  static Map<String, Object?> fieldsFor(Activity draft) {
    final description = draft.description.trim();
    return {
      'title': draft.title.trim(),
      'description': description.isEmpty ? null : description,
      'starts_at': draft.dateTime.toUtc().toIso8601String(),
      'ends_at': draft.endsAt.toUtc().toIso8601String(),
      'location_name': draft.location.trim(),
      'location_address': draft.locationAddress?.trim(),
      'latitude': draft.latitude,
      'longitude': draft.longitude,
      'max_participants': draft.maxParticipants,
      'is_public': draft.isPublic,
      'setting': draft.setting?.name,
      'category_emoji': draft.categoryEmoji.isEmpty
          ? null
          : draft.categoryEmoji,
      'category_label': draft.categoryLabel.isEmpty
          ? null
          : draft.categoryLabel,
    };
  }

  // Same activity, fields and photo: a retry may reuse the request id.
  bool sameContentAs(ActivitySaveRequest other) =>
      operation == other.operation &&
      activityId == other.activityId &&
      expectedVersion == other.expectedVersion &&
      photoChange == other.photoChange &&
      photoPath == other.photoPath &&
      mapEquals(activity, other.activity);

  // The request body. [jpegBase64] is the photo for a replace.
  Map<String, Object?> toBody({String? jpegBase64}) => {
    'operation': operation.name,
    'request_id': requestId,
    'activity_id': activityId,
    if (operation == ActivitySaveOperation.update)
      'expected_version': expectedVersion,
    'activity': activity,
    'photo': photoChange == ActivityPhotoChange.replace
        ? {'action': 'replace', 'jpeg_base64': jpegBase64}
        : {'action': photoChange.name},
  };

  Map<String, Object?> toJson() => {
    'operation': operation.name,
    'request_id': requestId,
    'activity_id': activityId,
    'expected_version': expectedVersion,
    'activity': activity,
    'photo_change': photoChange.name,
    'photo_path': photoPath,
  };

  static ActivitySaveRequest? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      return ActivitySaveRequest(
        operation: ActivitySaveOperation.values.byName(
          json['operation'] as String,
        ),
        requestId: json['request_id'] as String,
        activityId: json['activity_id'] as String,
        expectedVersion: (json['expected_version'] as num?)?.toInt(),
        activity: Map<String, Object?>.from(json['activity'] as Map),
        photoChange: ActivityPhotoChange.values.byName(
          json['photo_change'] as String,
        ),
        photoPath: json['photo_path'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

@immutable
class ActivitySaveResult {
  const ActivitySaveResult(
    this.code, {
    this.activity,
    this.fields = const [],
    this.reason,
    this.retryAfterSeconds,
  });

  final ActivitySaveCode code;

  // The saved row, or the current one for [ActivitySaveCode.conflict] and
  // [ActivitySaveCode.alreadyExists]. Host details aren't included.
  final Activity? activity;

  // For rejected and invalid: 'title', 'description', 'location', 'time',
  // 'capacity' or 'photo'.
  final List<String> fields;

  // For photoInvalid: 'too_large', 'unsupported', 'corrupt' or 'dimensions'.
  final String? reason;
  final int? retryAfterSeconds;

  bool get isSaved => code == ActivitySaveCode.saved;

  // Worth sending again unchanged, with the same request id.
  bool get isRetryable => const {
    ActivitySaveCode.busy,
    ActivitySaveCode.moderationUnavailable,
    ActivitySaveCode.storageFailed,
    ActivitySaveCode.saveFailed,
    ActivitySaveCode.connectionLost,
  }.contains(code);

  // The server decided; the saved request on the device can go.
  bool get isFinal => !isRetryable;

  static ActivitySaveResult fromResponse(Object? data) {
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return const ActivitySaveResult(ActivitySaveCode.saveFailed);
      }
    }
    if (data is! Map) {
      return const ActivitySaveResult(ActivitySaveCode.saveFailed);
    }
    final code = _codes[data['result']] ?? ActivitySaveCode.saveFailed;
    final activity = data['activity'];
    Activity? parsed;
    if (activity is Map) {
      try {
        parsed = Activity.fromMap(Map<String, dynamic>.from(activity));
      } catch (_) {
        parsed = null;
      }
    }
    final fields = data['fields'];
    return ActivitySaveResult(
      code,
      activity: parsed,
      fields: fields is List ? fields.whereType<String>().toList() : const [],
      reason: data['reason'] as String?,
      retryAfterSeconds: (data['retry_after_seconds'] as num?)?.toInt(),
    );
  }
}

// Sends a save to the Edge Function.
class ActivitySaveService {
  ActivitySaveService({SupabaseClient? client}) : _injected = client;

  final SupabaseClient? _injected;

  // Looked up on use, so this can be built without Supabase (tests).
  SupabaseClient get _client => _injected ?? Supabase.instance.client;

  Future<ActivitySaveResult> save(ActivitySaveRequest request) async {
    String? jpegBase64;
    if (request.photoChange == ActivityPhotoChange.replace) {
      final path = request.photoPath;
      if (path == null) {
        return const ActivitySaveResult(
          ActivitySaveCode.photoInvalid,
          reason: 'corrupt',
        );
      }
      final file = File(path);
      if (!await file.exists()) {
        return const ActivitySaveResult(
          ActivitySaveCode.photoInvalid,
          reason: 'corrupt',
        );
      }
      final bytes = await file.readAsBytes();
      if (bytes.length > ActivitySaveLimits.photoBytes) {
        return const ActivitySaveResult(
          ActivitySaveCode.photoInvalid,
          reason: 'too_large',
        );
      }
      jpegBase64 = base64Encode(bytes);
    }

    try {
      final response = await _client.functions.invoke(
        'save-activity',
        body: request.toBody(jpegBase64: jpegBase64),
      );
      return ActivitySaveResult.fromResponse(response.data);
    } on FunctionException catch (error) {
      return resultForHttpError(error.status);
    } on SocketException {
      return const ActivitySaveResult(ActivitySaveCode.connectionLost);
    } on HttpException {
      return const ActivitySaveResult(ActivitySaveCode.connectionLost);
    } catch (error) {
      // Timeouts and other client errors: the server may or may not have
      // saved, so treat it as a lost answer and retry with the same ids.
      debugPrint('SYNK: save-activity call failed: ${error.runtimeType}');
      return const ActivitySaveResult(ActivitySaveCode.connectionLost);
    }
  }

  @visibleForTesting
  static ActivitySaveResult resultForHttpError(int status) {
    return switch (status) {
      401 => const ActivitySaveResult(ActivitySaveCode.unauthorized),
      413 => const ActivitySaveResult(ActivitySaveCode.payloadTooLarge),
      400 => const ActivitySaveResult(ActivitySaveCode.invalidRequest),
      _ => const ActivitySaveResult(ActivitySaveCode.saveFailed),
    };
  }
}
