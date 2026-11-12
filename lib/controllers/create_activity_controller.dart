import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/activity_constants.dart';
import '../l10n/l10n.dart';
import '../models/activities_model.dart';
import '../models/activity_model.dart';
import '../models/activity_photo_uploader.dart';
import '../models/activity_save_model.dart';
import '../models/pending_activity_save_store.dart';
import '../utils/activity_photo_jpeg.dart';
import 'activity_save_messages.dart';

// Image formats accepted for an activity photo.
enum PhotoFormat { jpeg, png }

enum CreateField { title, location, setting, date, time }

// Outcome of a save. Saving goes through the save-activity Edge Function,
// which checks the content first; the activity and its photo are saved
// together or not at all.
//
// [activity] is set when it was saved. [latestActivity] is the current
// version after a conflict, so the caller can show it. [closeEditor] is set
// when there's nothing left to edit (deleted, or no longer the host).
class CreateActivityResult {
  const CreateActivityResult({
    this.activity,
    this.latestActivity,
    this.closeEditor = false,
  });

  final Activity? activity;
  final Activity? latestActivity;
  final bool closeEditor;

  bool get created => activity != null;
}

class CreateActivityController extends ChangeNotifier {
  CreateActivityController({
    ActivitiesModel? activitiesModel,
    Activity? activity,
    this.store,
    ActivitySaveService? saveService,
    PendingActivitySaveStore pendingStore = const PendingActivitySaveStore(),
    Future<String?> Function(String sourcePath)? preparePhoto,
    String? Function()? currentUserId,
  }) : _activitiesModel = activitiesModel ?? ActivitiesModel(),
       _editingActivity = activity,
       _saveService = saveService ?? ActivitySaveService(),
       _pending = pendingStore,
       _preparePhoto = preparePhoto ?? prepareActivityPhoto,
       _userIdGetter = currentUserId,
       _activityId = activity?.id ?? newUuidV4(),
       _editVersion = activity?.editVersion {
    // Editing a field the server flagged clears its highlight.
    titleController.addListener(() => _unflag('title'));
    descriptionController.addListener(() => _unflag('description'));
    if (activity != null) {
      titleController.text = activity.title;
      descriptionController.text = activity.description;
      _locationName = activity.location;
      _locationAddress = activity.locationAddress;
      _latitude = activity.latitude;
      _longitude = activity.longitude;
      _setting = activity.setting;
      _date = DateTime(activity.dateTime.year, activity.dateTime.month, activity.dateTime.day);
      _time = TimeOfDay.fromDateTime(activity.dateTime);
      _participants = activity.maxParticipants;
      _confirmedParticipantCount = activity.joinedCount;
      _isLoadingConfirmedParticipantCount = true;
      _confirmedParticipantCountAvailable = false;
      _isPublic = activity.isPublic;
    }
  }

  final ActivitiesModel _activitiesModel;
  final Activity? _editingActivity;
  bool get isEditing => _editingActivity != null;

  final ActivitySaveService _saveService;
  final PendingActivitySaveStore _pending;
  final Future<String?> Function(String sourcePath) _preparePhoto;
  final String? Function()? _userIdGetter;

  // Made once per form, so a retry can't create a second activity.
  final String _activityId;
  // The version this edit started from; the server refuses a save over a
  // newer one.
  int? _editVersion;
  // The last save sent. Sending the same content again reuses its request
  // id, so the server answers instead of saving twice.
  ActivitySaveRequest? _lastRequest;
  // Fields the server found inappropriate, until they're changed.
  final Set<String> _flagged = {};
  // The picked photo as an upright, metadata-free JPEG, ready to send.
  String? _preparedPhotoPath;

  // ---------------------------------------------------------------------------
  // Draft
  // ---------------------------------------------------------------------------

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String _locationName = '';
  String? _locationAddress;
  double? _latitude;
  double? _longitude;

  ActivitySetting? _setting;

  DateTime? _date;
  TimeOfDay? _time;

  int _participants = ActivityConstants.defaultParticipants;
  bool _isPublic = true;

  XFile? _photo;
  PhotoFormat? _photoFormat;
  bool _removeExistingPhoto = false;

  int _currentStep = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isPickingPhoto = false;
  String? _errorMessage;
  bool _scheduleConflict = false;
  String? _scheduleConflictMessage;
  Activity? _conflictingActivity;

  // The user's own activities, used to name a schedule conflict.
  final ActivityStore? store;
  int _scheduleCheckVersion = 0;
  int _confirmedParticipantCount = 1;
  bool _isLoadingConfirmedParticipantCount = false;
  bool _confirmedParticipantCountAvailable = true;
  bool _capacityConflict = false;
  bool _invalidTitleAttempt = false;
  bool _disposed = false;
  String? _photoError;

  String get locationName => _locationName;
  String? get locationAddress => _locationAddress;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  ActivitySetting? get setting => _setting;
  DateTime? get date => _date;
  TimeOfDay? get time => _time;
  int get participants => _participants;
  bool get isPublic => _isPublic;
  XFile? get photo => _photo;
  String? get existingPhotoUrl =>
      _removeExistingPhoto ? null : _editingActivity?.photoUrl;
  PhotoFormat? get photoFormat => _photoFormat;
  File? get photoFile => _photo == null ? null : File(_photo!.path);
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isPickingPhoto => _isPickingPhoto;
  String? get errorMessage => _errorMessage;
  bool get hasScheduleConflict => _scheduleConflict;
  bool get hasCapacityConflict => _capacityConflict;
  String? get scheduleConflictMessage => _scheduleConflictMessage;

  // The hosted or joined activity in the way, when it can be found.
  Activity? get conflictingActivity =>
      _scheduleConflict ? _conflictingActivity : null;
  String? get photoError => _photoError;
  bool get isLoadingConfirmedParticipantCount =>
      _isLoadingConfirmedParticipantCount;
  bool get canVerifyConfirmedParticipantCount =>
      _confirmedParticipantCountAvailable;

  int get spotsOpen => _participants - 1;
  int get confirmedParticipantCount => _confirmedParticipantCount;
  int get minimumParticipants => confirmedParticipantCount > ActivityConstants.minParticipants
      ? confirmedParticipantCount
      : ActivityConstants.minParticipants;
  bool get canDecrement =>
      _confirmedParticipantCountAvailable && _participants > minimumParticipants;
  bool get canIncrement => _participants < ActivityConstants.maxParticipants;

  // Date + time combined; null until both are chosen.
  DateTime? get startsAt {
    final d = _date;
    final t = _time;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  // True once the user has entered anything worth losing. Drives the
  // "Discard activity?" dialog: an untouched draft leaves without asking.
  bool get isDirty {
    final original = _editingActivity;
    if (original != null) {
      final originalDescription = original.description.trim();
      return titleController.text.trim() != original.title.trim() ||
          descriptionController.text.trim() != originalDescription ||
          _locationName != original.location ||
          _locationAddress != original.locationAddress ||
          _latitude != original.latitude ||
          _longitude != original.longitude ||
          _setting != original.setting ||
          startsAt != original.dateTime ||
          _participants != original.maxParticipants ||
          _isPublic != original.isPublic ||
          _photo != null ||
          _removeExistingPhoto;
    }

    return titleController.text.trim().isNotEmpty ||
        descriptionController.text.trim().isNotEmpty ||
        _locationName.isNotEmpty ||
        _setting != null ||
        _date != null ||
        _time != null ||
        _photo != null ||
        _participants != ActivityConstants.defaultParticipants ||
        !_isPublic;
  }

  // ---------------------------------------------------------------------------
  // Draft mutations
  // ---------------------------------------------------------------------------

  void setPlace({
    required String name,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    _flagged.remove('location');
    _locationName = name.trim();
    _locationAddress = address?.trim();
    _latitude = latitude;
    _longitude = longitude;
    notifyListeners();
  }

  void clearPlace() {
    _flagged.remove('location');
    _locationName = '';
    _locationAddress = null;
    _latitude = null;
    _longitude = null;
    _touched.add(CreateField.location);
    notifyListeners();
  }

  void setSetting(ActivitySetting value) {
    _setting = value;
    _touched.add(CreateField.setting);
    notifyListeners();
  }

  void setDate(DateTime value) {
    _date = DateTime(value.year, value.month, value.day);
    _clearScheduleConflict();
    _touched.add(CreateField.date);
    notifyListeners();
  }

  void markInvalidTitleAttempt() {
    if (_invalidTitleAttempt || _disposed) return;
    _invalidTitleAttempt = true;
    _touched.add(CreateField.title);
    notifyListeners();
  }

  void clearInvalidTitleAttempt() {
    if (!_invalidTitleAttempt) return;
    _invalidTitleAttempt = false;
    notifyListeners();
  }

  void setTime(TimeOfDay value) {
    _time = value;
    _clearScheduleConflict();
    _touched.add(CreateField.time);
    notifyListeners();
  }

  void _clearScheduleConflict() {
    _scheduleCheckVersion++;
    if (_scheduleConflict) {
      _scheduleConflict = false;
      _scheduleConflictMessage = null;
      _errorMessage = null;
    }
  }

  // Shown under the Time field.
  void _markScheduleConflict() {
    _findConflictingActivity();
    _scheduleConflict = true;
    _scheduleConflictMessage = appL10n.youAlreadyHaveAnActivityAtThisTime;
    _errorMessage = _scheduleConflictMessage;
    _touched.add(CreateField.time);
  }

  void _findConflictingActivity() {
    final start = startsAt;
    _conflictingActivity = start == null
        ? null
        : store?.conflictingActivity(
            start,
            start.add(const Duration(hours: 2)),
            excludeId: _editingActivity?.id,
          );
  }

  Future<String?> checkSelectedScheduleConflict() async {
    final start = startsAt;
    if (start == null || !start.isAfter(DateTime.now())) return null;
    final version = ++_scheduleCheckVersion;
    try {
      final message = await _activitiesModel.checkScheduleConflict(
        startsAt: start,
        endsAt: start.add(const Duration(hours: 2)),
        excludedActivityId: _editingActivity?.id,
      );
      if (version != _scheduleCheckVersion || startsAt != start) return null;
      _scheduleConflict = message != null;
      if (_scheduleConflict) _findConflictingActivity();
      _scheduleConflictMessage = _scheduleConflict
          ? appL10n.youAlreadyHaveAnActivityAtThisTime
          : null;
      _errorMessage = _scheduleConflictMessage;
      if (_scheduleConflict) _touched.add(CreateField.time);
      notifyListeners();
      return _scheduleConflictMessage;
    } catch (_) {
      // The server repeats this validation when saving. A temporary preflight
      // failure must not block the form or be mistaken for a schedule conflict.
      return null;
    }
  }

  void incrementParticipants() {
    if (!canIncrement) return;
    _participants++;
    notifyListeners();
  }

  void decrementParticipants() {
    if (!canDecrement) return;
    _participants--;
    notifyListeners();
  }

  Future<void> refreshConfirmedParticipantCount() async {
    final activity = _editingActivity;
    if (activity == null) return;
    _isLoadingConfirmedParticipantCount = true;
    notifyListeners();
    try {
      final count = await _activitiesModel.fetchConfirmedParticipantCount(
        activity.id,
      );
      if (_disposed) return;
      _confirmedParticipantCount = count;
      _confirmedParticipantCountAvailable = true;
    } catch (_) {
      // Do not allow capacity reductions when the authoritative count cannot
      // be loaded. Saving the unchanged capacity remains possible.
      if (!_disposed) _confirmedParticipantCountAvailable = false;
    } finally {
      if (!_disposed) {
        _isLoadingConfirmedParticipantCount = false;
        notifyListeners();
      }
    }
  }

  void setPublic(bool value) {
    _isPublic = value;
    notifyListeners();
  }

  void goToStep(int step) {
    if (step < 0 || step > 2 || step == _currentStep) return;
    _currentStep = step;
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Photo
  // ---------------------------------------------------------------------------

  // Opens the picker and keeps the file only if its leading bytes identify
  // it as JPEG or PNG and its extension agrees with them.
  //
  // This is a format check, not an integrity check: it confirms which format
  // the file claims to be so the stored content type is right. It does not
  // decode the image, so a truncated or corrupt file can still pass here and
  // fail to render later.
  //
  // Nothing is uploaded here, and a failed attempt leaves any previously
  // selected photo untouched.
  Future<void> pickPhoto() async {
    if (_isPickingPhoto) return;

    _isPickingPhoto = true;
    _photoError = null;
    notifyListeners();

    try {
      XFile? picked;
      try {
        picked = await ActivityPhotoUploader.pick();
      } catch (_) {
        // Picker unavailable, permission refused, or the platform channel
        // failed. Keep whatever photo was already chosen.
        _photoError = appL10n.couldntOpenYourPhotosPleaseTry;
        return;
      }

      if (picked == null) return; // Cancelled — nothing changes.

      final format = await _detectFormat(picked);
      if (format == null) {
        _photoError = appL10n.thatFileIsntAJpegOr;
        return;
      }

      if (!_extensionMatches(picked.path, format)) {
        // e.g. JPEG bytes saved as ".png": the stored content type would be
        // wrong, so ask for a file whose name matches what it actually is.
        _photoError = appL10n.thisImagesFileTypeAndIts;
        return;
      }

      // Upright JPEG, at most 2 MB, without EXIF or GPS data.
      final prepared = await _preparePhoto(picked.path);
      if (prepared == null) {
        _photoError = appL10n.activityPhotoCantBeUsed;
        return;
      }
      await _discardPreparedPhoto();
      _preparedPhotoPath = prepared;
      _flagged.remove('photo');

      _photo = picked;
      _photoFormat = format;
      _removeExistingPhoto = false;
    } finally {
      _isPickingPhoto = false;
      notifyListeners();
    }
  }

  void removePhoto() {
    unawaited(_discardPreparedPhoto());
    _preparedPhotoPath = null;
    _flagged.remove('photo');
    _photo = null;
    _photoFormat = null;
    _removeExistingPhoto = _editingActivity?.hasPhoto ?? false;
    _photoError = null;
    notifyListeners();
  }

  // Deletes the prepared photo unless a pending save still needs it.
  Future<void> _discardPreparedPhoto() async {
    final path = _preparedPhotoPath;
    if (path == null || _lastRequest?.photoPath == path) return;
    await PendingActivitySaveStore.deletePhoto(path);
  }

  void _unflag(String field) {
    if (_flagged.remove(field) && !_disposed) notifyListeners();
  }

  // Reads the file's leading bytes to identify the format. Returns null when
  // the file is unreadable or is neither JPEG nor PNG, whatever it is called.
  Future<PhotoFormat?> _detectFormat(XFile file) async {
    try {
      final bytes = await File(file.path).openRead(0, 8).first;

      if (bytes.length >= 3 &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xD8 &&
          bytes[2] == 0xFF) {
        return PhotoFormat.jpeg;
      }

      const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      if (bytes.length >= pngSignature.length) {
        var matches = true;
        for (var i = 0; i < pngSignature.length; i++) {
          if (bytes[i] != pngSignature[i]) {
            matches = false;
            break;
          }
        }
        if (matches) return PhotoFormat.png;
      }

      return null;
    } catch (_) {
      // File missing, unreadable, or empty.
      return null;
    }
  }

  bool _extensionMatches(String path, PhotoFormat format) {
    final dot = path.lastIndexOf('.');
    final ext = dot == -1 ? '' : path.substring(dot + 1).toLowerCase();
    return switch (format) {
      PhotoFormat.jpeg => ext == 'jpg' || ext == 'jpeg',
      PhotoFormat.png => ext == 'png',
    };
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  // Letters in any script (Arabic, English or both, with their marks),
  // digits 0-9, and & ' , and spaces. The server applies the same rule.
  static final RegExp titleAllowed = RegExp(
    r"^[\p{L}\p{M}0-9&', ]*$",
    unicode: true,
  );
  static final RegExp _titleLetterOrMark = RegExp(
    r'^[\p{L}\p{M}]$',
    unicode: true,
  );

  static bool isAllowedTitleRune(int rune) {
    if (rune == 0x20 || // space
        rune == 0x26 || // ampersand
        rune == 0x27 || // apostrophe
        rune == 0x2C || // comma
        (rune >= 0x30 && rune <= 0x39)) {
      return true;
    }
    return _titleLetterOrMark.hasMatch(String.fromCharCode(rune));
  }

  String? validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return appL10n.addATitle;
    if (title.characters.length > ActivityConstants.titleMaxLength) {
      return appL10n.keepItToLetters(ActivityConstants.titleMaxLength);
    }
    if (!titleAllowed.hasMatch(title)) {
      return appL10n.useLettersOnly;
    }
    return null;
  }

  String? validateDescription(String? value) {
    final description = value?.trim() ?? '';
    if (description.length > ActivityConstants.descriptionMaxLength) {
      return appL10n.keepItToCharacters(
        ActivityConstants.descriptionMaxLength,
      );
    }
    return null;
  }

  // Errors only show after the user leaves a field.
  final Set<CreateField> _touched = {};

  void touch(CreateField field) {
    if (_touched.add(field)) notifyListeners();
  }

  void touchStep(int step) {
    final fields = switch (step) {
      0 => CreateField.values,
      _ => const <CreateField>[],
    };
    final before = _touched.length;
    _touched.addAll(fields);
    if (_touched.length != before) notifyListeners();
  }

  String? _fieldError(CreateField field) => switch (field) {
    CreateField.title when _flagged.contains('title') =>
      appL10n.activityFieldRejected,
    CreateField.location when _flagged.contains('location') =>
      appL10n.activityFieldRejected,
    CreateField.title => _invalidTitleAttempt
        ? appL10n.useLettersOnly
        : validateTitle(titleController.text),
    CreateField.location => _locationName.isEmpty ? appL10n.chooseALocation : null,
    CreateField.setting => _setting == null ? appL10n.chooseIndoorOrOutdoor : null,
    CreateField.date => _date == null
        ? appL10n.pickADate
        : _date!.isAfter(ActivityConstants.latestAllowedDate(DateTime.now()))
        ? appL10n.chooseADateWithinTheNext
        : null,
    CreateField.time =>
      _scheduleConflict
          ? _scheduleConflictMessage
          : _time == null
          ? appL10n.pickATime
          : startsAt != null && !startsAt!.isAfter(DateTime.now())
          ? appL10n.thisTimeHasAlreadyPassed
          : null,
  };

  String? errorFor(CreateField field) =>
      _touched.contains(field) ? _fieldError(field) : null;

  bool _stepValid(int step) =>
      step != 0 || CreateField.values.every((f) => _fieldError(f) == null);

  // The description's error, including a moderation flag.
  String? get descriptionError => _flagged.contains('description')
      ? appL10n.activityFieldRejected
      : validateDescription(descriptionController.text);

  String? get _flaggedPhotoError =>
      _flagged.contains('photo') ? appL10n.activityPhotoRejected : null;

  bool get canSubmit =>
      _stepValid(0) &&
      descriptionError == null &&
      _flaggedPhotoError == null &&
      !_isSubmitting &&
      !_isLoading;

  String? stepBlocker(int step) {
    if (step != 0) return null;
    for (final field in CreateField.values) {
      final error = _fieldError(field);
      if (error != null) return error;
    }
    return null;
  }

  String? get submitBlocker =>
      stepBlocker(0) ?? descriptionError ?? _flaggedPhotoError;

  // ---------------------------------------------------------------------------
  // Submit — one call to the save-activity Edge Function. It checks the
  // title, description, location and photo for inappropriate content, then
  // saves the activity and its photo together, or nothing at all.
  // ---------------------------------------------------------------------------

  String? get _userId => _userIdGetter != null
      ? _userIdGetter()
      : _activitiesModel.currentUserId;

  // The step holding the first field the server flagged, to go back to.
  int? get firstFlaggedStep {
    if (_flagged.contains('title') || _flagged.contains('location')) return 0;
    if (_flagged.contains('description') || _flagged.contains('photo')) {
      return 1;
    }
    return null;
  }

  bool get hasFlaggedContent => _flagged.isNotEmpty;

  // The fields the server flagged, in the order they appear in the form.
  List<String> get flaggedFields => const [
    'title',
    'location',
    'description',
    'photo',
  ].where(_flagged.contains).toList();

  Future<CreateActivityResult> submit() async {
    // Guard: never start a second submit while one is running, and never
    // send an incomplete draft (startsAt would be null).
    if (_isSubmitting || _isLoading) {
      return const CreateActivityResult();
    }

    final blocker = submitBlocker;
    final start = startsAt;
    if (blocker != null || start == null) {
      _errorMessage = blocker ?? appL10n.pleaseCompleteEveryStepBeforeCreating;
      notifyListeners();
      return const CreateActivityResult();
    }

    _isSubmitting = true;
    _setLoading(true);
    _errorMessage = null;
    _scheduleConflict = false;
    _capacityConflict = false;

    try {
      try {
        final scheduleConflict = await _activitiesModel.checkScheduleConflict(
          startsAt: start,
          endsAt: start.add(const Duration(hours: 2)),
          excludedActivityId: _editingActivity?.id,
        );
        if (scheduleConflict != null) {
          _markScheduleConflict();
          return const CreateActivityResult();
        }
      } catch (_) {
        // Only a preflight; the server checks again when saving.
      }

      final userId = _userId;
      if (userId == null) {
        _errorMessage = appL10n.signInAgainToSave;
        return const CreateActivityResult();
      }

      // Activities loaded before the server had versions: read it now.
      if (isEditing && _editVersion == null) {
        try {
          _editVersion = (await _activitiesModel.fetchById(_activityId))
              ?.editVersion;
        } catch (_) {
          _editVersion = null;
        }
        if (_editVersion == null) {
          _errorMessage = appL10n.weCouldntSaveYourChanges;
          return const CreateActivityResult();
        }
      }

      final request = _buildRequest(start);
      final result = await _send(userId, request);
      if (_disposed) return const CreateActivityResult();
      return _handle(result, request);
    } finally {
      _isSubmitting = false;
      if (!_disposed) _setLoading(false);
    }
  }

  ActivitySaveRequest _buildRequest(DateTime start) {
    final draft = Activity(
      id: _activityId,
      title: titleController.text,
      description: descriptionController.text,
      dateTime: start,
      location: _locationName,
      locationAddress: _locationAddress,
      latitude: _latitude,
      longitude: _longitude,
      maxParticipants: _participants,
      isPublic: _isPublic,
      setting: _setting,
      categoryEmoji: _editingActivity?.categoryEmoji ?? '',
      categoryLabel: _editingActivity?.categoryLabel ?? '',
    );
    final photoChange = _preparedPhotoPath != null
        ? ActivityPhotoChange.replace
        : !isEditing
        ? ActivityPhotoChange.none
        : _removeExistingPhoto
        ? ActivityPhotoChange.remove
        : ActivityPhotoChange.keep;

    ActivitySaveRequest withId(String requestId) => ActivitySaveRequest(
      operation: isEditing
          ? ActivitySaveOperation.update
          : ActivitySaveOperation.create,
      requestId: requestId,
      activityId: _activityId,
      expectedVersion: isEditing ? _editVersion : null,
      activity: ActivitySaveRequest.fieldsFor(draft),
      photoChange: photoChange,
      photoPath: photoChange == ActivityPhotoChange.replace
          ? _preparedPhotoPath
          : null,
    );

    // The same content again (a retry): same request id, so the server
    // answers instead of saving twice. Anything changed: a new attempt.
    final last = _lastRequest;
    if (last != null && last.sameContentAs(withId(last.requestId))) return last;
    return withId(newUuidV4());
  }

  Future<ActivitySaveResult> _send(
    String userId,
    ActivitySaveRequest request,
  ) async {
    _lastRequest = request;
    try {
      // Kept until the server decides, in case the app closes meanwhile.
      await _pending.save(userId, request);
    } catch (_) {
      // Without it a retry still works while the form is open.
    }

    var result = await _saveService.save(request);
    // Another attempt of this save is still running: wait once, then ask.
    if (result.code == ActivitySaveCode.busy && !_disposed) {
      final wait = (result.retryAfterSeconds ?? 3).clamp(1, 5);
      await Future<void>.delayed(Duration(seconds: wait));
      if (!_disposed) result = await _saveService.save(request);
    }

    if (result.isFinal) {
      _lastRequest = null;
      try {
        await _pending.clear(
          userId,
          requestId: request.requestId,
          deletePhoto: false,
        );
      } catch (_) {
        // Offered again on the next start, where the server replays it.
      }
    }
    return result;
  }

  CreateActivityResult _handle(
    ActivitySaveResult result,
    ActivitySaveRequest request,
  ) {
    final message = activitySaveMessage(result, editing: isEditing);
    switch (result.code) {
      case ActivitySaveCode.saved:
      case ActivitySaveCode.alreadyExists:
        final saved = result.activity;
        if (saved == null) {
          // Saved, but the row couldn't be read back (e.g. just deleted).
          _errorMessage = message.isEmpty ? null : message;
          return const CreateActivityResult(closeEditor: true);
        }
        _flagged.clear();
        unawaited(PendingActivitySaveStore.deletePhoto(_preparedPhotoPath));
        _preparedPhotoPath = null;
        return CreateActivityResult(activity: _withHostDetails(saved));

      case ActivitySaveCode.rejected:
        _flagged
          ..clear()
          ..addAll(result.fields);
        if (_flagged.contains('title')) _touched.add(CreateField.title);
        if (_flagged.contains('location')) _touched.add(CreateField.location);
        if (_flagged.contains('photo')) {
          _photoError = appL10n.activityPhotoRejected;
        }
        _errorMessage = message;

      case ActivitySaveCode.photoInvalid:
      case ActivitySaveCode.payloadTooLarge:
        _photoError = message;
        _errorMessage = message;

      case ActivitySaveCode.scheduleConflict:
        _markScheduleConflict();

      case ActivitySaveCode.capacityBelowParticipants:
        _capacityConflict = true;
        _errorMessage = message;

      case ActivitySaveCode.conflict:
        _errorMessage = message;
        return CreateActivityResult(latestActivity: result.activity);

      case ActivitySaveCode.notFound:
      case ActivitySaveCode.notHost:
        _errorMessage = message;
        return const CreateActivityResult(closeEditor: true);

      case ActivitySaveCode.requestMismatch:
        // Never resent automatically: the next tap is a new attempt.
        debugPrint(
          'SYNK: activity save request_mismatch for ${request.requestId}',
        );
        _errorMessage = message;

      default:
        _errorMessage = message;
    }
    return const CreateActivityResult();
  }

  // The server returns the plain row; keep what the screens show about the
  // host and the people going.
  Activity _withHostDetails(Activity saved) {
    final original = _editingActivity;
    if (original == null) return saved;
    return saved.copyWith(
      hostName: original.hostName,
      hostUsername: original.hostUsername,
      hostAvatarUrl: original.hostAvatarUrl,
      hostGender: original.hostGender,
      participantsCount: original.participantsCount,
      participationId: original.participationId,
      participationStatus: original.participationStatus,
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    // The prepared photo stays only while a pending save needs it.
    if (_lastRequest == null) {
      unawaited(PendingActivitySaveStore.deletePhoto(_preparedPhotoPath));
    }
    _disposed = true;
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
