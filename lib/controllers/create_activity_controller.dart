import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/activity_constants.dart';
import '../models/activities_model.dart';
import '../models/activity_model.dart';
import '../models/activity_photo_uploader.dart';

// Image formats accepted for an activity photo.
enum PhotoFormat { jpeg, png }

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
  }) : _activitiesModel = activitiesModel ?? ActivitiesModel();

  final ActivitiesModel _activitiesModel;

  // ---------------------------------------------------------------------------
  // Draft
  // ---------------------------------------------------------------------------

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String _locationName = '';
  String? _locationAddress;
  double? _latitude;
  double? _longitude;

  DateTime? _date;
  TimeOfDay? _time;

  int _participants = ActivityConstants.defaultParticipants;
  bool _isPublic = true;

  XFile? _photo;
  PhotoFormat? _photoFormat;

  int _currentStep = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isPickingPhoto = false;
  String? _errorMessage;
  String? _photoError;

  String get locationName => _locationName;
  String? get locationAddress => _locationAddress;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  DateTime? get date => _date;
  TimeOfDay? get time => _time;
  int get participants => _participants;
  bool get isPublic => _isPublic;
  XFile? get photo => _photo;
  PhotoFormat? get photoFormat => _photoFormat;
  File? get photoFile => _photo == null ? null : File(_photo!.path);
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isPickingPhoto => _isPickingPhoto;
  String? get errorMessage => _errorMessage;
  String? get photoError => _photoError;

  int get spotsOpen => _participants - 1;
  bool get canDecrement => _participants > ActivityConstants.minParticipants;
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
  bool get isDirty =>
      titleController.text.trim().isNotEmpty ||
      descriptionController.text.trim().isNotEmpty ||
      _locationName.isNotEmpty ||
      _date != null ||
      _time != null ||
      _photo != null ||
      _participants != ActivityConstants.defaultParticipants ||
      !_isPublic;

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
    notifyListeners();
  }

  void setDate(DateTime value) {
    _date = DateTime(value.year, value.month, value.day);
    notifyListeners();
  }

  void setTime(TimeOfDay value) {
    _time = value;
    notifyListeners();
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
        _photoError = "Couldn't open your photos. Please try again.";
        return;
      }

      if (picked == null) return; // Cancelled — nothing changes.

      final format = await _detectFormat(picked);
      if (format == null) {
        _photoError = "That file isn't a JPEG or PNG image.";
        return;
      }

      if (!_extensionMatches(picked.path, format)) {
        // e.g. JPEG bytes saved as ".png": the stored content type would be
        // wrong, so ask for a file whose name matches what it actually is.
        _photoError =
            "This image's file type and its contents don't match. Try another photo.";
        return;
      }

      _photo = picked;
      _photoFormat = format;
    } finally {
      _isPickingPhoto = false;
      notifyListeners();
    }
  }

  void removePhoto() {
    _photo = null;
    _photoFormat = null;
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

  String? validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Please give your activity a title';
    if (title.length > ActivityConstants.titleMaxLength) {
      return 'Title must be ${ActivityConstants.titleMaxLength} characters or fewer';
    }
    return null;
  }

  String? validateDescription(String? value) {
    final description = value?.trim() ?? '';
    if (description.isEmpty) return 'Please describe your activity';
    if (description.length > ActivityConstants.descriptionMaxLength) {
      return 'Description must be ${ActivityConstants.descriptionMaxLength} characters or fewer';
    }
    return null;
  }

  // Step 1: title + a chosen location.
  bool get step1Valid =>
      validateTitle(titleController.text) == null && _locationName.isNotEmpty;

  // Step 2: a date and time that are not in the past.
  bool get step2Valid {
    final start = startsAt;
    return start != null && start.isAfter(DateTime.now());
  }

  // Step 3: a description.
  bool get step3Valid => validateDescription(descriptionController.text) == null;

  bool get canSubmit =>
      step1Valid && step2Valid && step3Valid && !_isSubmitting && !_isLoading;

  // Message for the step the user is on, or null when it's complete.
  String? stepBlocker(int step) {
    switch (step) {
      case 0:
        if (validateTitle(titleController.text) != null) {
          return 'Please give your activity a title';
        }
        if (_locationName.isEmpty) return 'Please choose a location';
        return null;
      case 1:
        if (_date == null) return 'Please pick a date';
        if (_time == null) return 'Please pick a start time';
        if (!step2Valid) return 'Pick a date and time in the future';
        return null;
      case 2:
        return validateDescription(descriptionController.text);
      default:
        return null;
    }
  }

  // The first thing stopping a submit, checked across all three steps.
  String? get submitBlocker =>
      stepBlocker(0) ?? stepBlocker(1) ?? stepBlocker(2);

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
      _errorMessage = blocker ?? 'Please complete every step before creating.';
      notifyListeners();
      return const CreateActivityResult();
    }

    _isSubmitting = true;
    _setLoading(true);
    _errorMessage = null;

    Activity created;
    try {
      created = await _activitiesModel.create(
        Activity(
          id: '',
          title: titleController.text,
          description: descriptionController.text,
          dateTime: start,
          location: _locationName,
          locationAddress: _locationAddress,
          latitude: _latitude,
          longitude: _longitude,
          maxParticipants: _participants,
          isPublic: _isPublic,
        ),
      );
    } catch (_) {
      _errorMessage =
          "Couldn't create the activity. Check your connection and try again.";
      _isSubmitting = false;
      _setLoading(false);
      return const CreateActivityResult();
    }

    // From here the activity exists. Nothing below may undo that.
    final file = _photo;
    if (file == null) {
      _isSubmitting = false;
      _setLoading(false);
      return CreateActivityResult(activity: created);
    }

    final upload = await ActivityPhotoUploader.upload(
      activityId: created.id,
      file: file,
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
        final withPhoto = await _activitiesModel.updatePhotoUrl(
          created.id,
          upload.url,
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
          "Your activity was created, but the photo couldn't be added to it.",
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
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}