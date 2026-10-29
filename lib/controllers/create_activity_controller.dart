import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/activity_constants.dart';
import '../l10n/l10n.dart';
import '../models/activities_model.dart';
import '../models/activity_model.dart';
import '../models/activity_photo_uploader.dart';
import '../utils/text_direction.dart';

// Image formats accepted for an activity photo.
enum PhotoFormat { jpeg, png }

enum CreateField { title, location, setting, date, time }

// Outcome of a create attempt.
//
// [activity] is non-null when the row was created. [photoWarning] explains a
// photo problem that did NOT prevent creation. [orphanWarning] is set only
// when a photo was uploaded but could not be linked to the activity, so the
// file may still be sitting in Storage — it is never reported as cleaned up.
class CreateActivityResult {
  const CreateActivityResult({
    this.activity,
    this.photoWarning,
    this.orphanWarning,
  });

  final Activity? activity;
  final String? photoWarning;
  final String? orphanWarning;

  bool get created => activity != null;
}

class CreateActivityController extends ChangeNotifier {
  CreateActivityController({
    ActivitiesModel? activitiesModel,
    Activity? activity,
    this.store,
  }) : _activitiesModel = activitiesModel ?? ActivitiesModel(),
       _editingActivity = activity {
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
    _locationName = name.trim();
    _locationAddress = address?.trim();
    _latitude = latitude;
    _longitude = longitude;
    notifyListeners();
  }

  void clearPlace() {
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

      _photo = picked;
      _photoFormat = format;
      _removeExistingPhoto = false;
    } finally {
      _isPickingPhoto = false;
      notifyListeners();
    }
  }

  void removePhoto() {
    _photo = null;
    _photoFormat = null;
    _removeExistingPhoto = _editingActivity?.hasPhoto ?? false;
    _photoError = null;
    notifyListeners();
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
    // The field drops Arabic as it's typed; this catches older titles.
    if (hasArabic(title)) return appL10n.useEnglishLettersOnly;
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

  bool get canSubmit =>
      _stepValid(0) &&
      validateDescription(descriptionController.text) == null &&
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
      stepBlocker(0) ?? validateDescription(descriptionController.text);

  // ---------------------------------------------------------------------------
  // Submit — insert first, then upload the photo, then attach it.
  // ---------------------------------------------------------------------------

  Future<CreateActivityResult> submit() async {
    // Guard: never start a second submit while one is running, and never
    // reach the insert with an incomplete draft (startsAt would be null).
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

    Activity created;
    try {
      final scheduleConflict = await _activitiesModel.checkScheduleConflict(
        startsAt: start,
        endsAt: start.add(const Duration(hours: 2)),
        excludedActivityId: _editingActivity?.id,
      );
      if (scheduleConflict != null) {
        _markScheduleConflict();
        _isSubmitting = false;
        _setLoading(false);
        return const CreateActivityResult();
      }
      final draft = Activity(
          id: _editingActivity?.id ?? '',
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
          photoUrl: _removeExistingPhoto ? null : _editingActivity?.photoUrl,
          hostId: _editingActivity?.hostId,
          hostName: _editingActivity?.hostName,
          hostUsername: _editingActivity?.hostUsername,
          hostAvatarUrl: _editingActivity?.hostAvatarUrl,
          hostGender: _editingActivity?.hostGender,
          participantsCount: _editingActivity?.participantsCount,
          activityCode: _editingActivity?.activityCode,
        );
      created = isEditing
          ? await _activitiesModel.update(draft)
          : await _activitiesModel.create(draft);
    } catch (error) {
      debugPrint('SYNK: create activity failed: $error');
      final errorText = error.toString();
      final normalizedError = errorText.toLowerCase();
      _capacityConflict = normalizedError.contains(
        'capacity cannot be lower than the current number of participants',
      );
      final scheduleConflict = normalizedError.contains(
        'already have an activity scheduled',
      );
      if (scheduleConflict) _markScheduleConflict();
      _errorMessage = scheduleConflict
          ? _scheduleConflictMessage
          : _capacityConflict
          ? 'Capacity cannot be lower than the current number of participants.'
          : isEditing
          ? appL10n.weCouldntSaveYourChanges
          : appL10n.weCouldntCreateYourActivityPlease;
      _isSubmitting = false;
      _setLoading(false);
      return const CreateActivityResult();
    }

    // From here the activity exists. Nothing below may undo that.
    final file = _photo;
    if (file == null) {
      if (isEditing && _removeExistingPhoto) {
        final hostId = _editingActivity?.hostId;
        if (hostId != null) {
          var photoWarning = appL10n.photoCouldntBeDetached;
          try {
            final detached = await _activitiesModel.updatePhotoUrl(
              created.id,
              null,
            );
            created = detached.copyWith(
              hostName: created.hostName,
              hostUsername: created.hostUsername,
              hostAvatarUrl: created.hostAvatarUrl,
              hostGender: created.hostGender,
              participantsCount: created.participantsCount,
            );
            final removed = await ActivityPhotoUploader.remove(
              hostId: hostId,
              activityId: created.id,
            );
            photoWarning = removed
                ? ''
                : appL10n.photoDetachedFileNotRemoved;
          } catch (_) {
            // Keep the attached photo when clearing its database URL fails.
          }
          _isSubmitting = false;
          _setLoading(false);
          return CreateActivityResult(
            activity: created,
            photoWarning: photoWarning.isEmpty ? null : photoWarning,
          );
        }
      }
      _isSubmitting = false;
      _setLoading(false);
      return CreateActivityResult(activity: created);
    }

    final upload = await ActivityPhotoUploader.upload(
      activityId: created.id,
      file: file,
      cacheBust: isEditing,
    );

    if (!upload.succeeded) {
      _isSubmitting = false;
      _setLoading(false);
      return CreateActivityResult(
        activity: created,
        photoWarning: upload.warning,
      );
    }

    // Attach the URL, retrying once before giving up.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final updatedPhoto = await _activitiesModel.updatePhotoUrl(
          created.id,
          upload.url,
        );
        final withPhoto = updatedPhoto.copyWith(
          hostName: created.hostName,
          hostUsername: created.hostUsername,
          hostAvatarUrl: created.hostAvatarUrl,
          hostGender: created.hostGender,
          participantsCount: created.participantsCount,
          participationId: created.participationId,
          participationStatus: created.participationStatus,
        );
        _isSubmitting = false;
        _setLoading(false);
        return CreateActivityResult(activity: withPhoto);
      } catch (_) {
        if (attempt == 0) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
    }

    // Uploaded but not linked. The file is still in Storage and this code
    // has not removed it, so say exactly that rather than implying cleanup.
    _isSubmitting = false;
    _setLoading(false);
    return CreateActivityResult(
      activity: created,
      photoWarning:
          appL10n.activityCreatedPhotoNotAdded,
      orphanWarning:
          'Uploaded photo for activity ${created.id} was not linked and was not removed.',
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
