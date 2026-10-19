import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/activity_constants.dart';
import '../models/activities_model.dart';
import '../models/activity_model.dart';
import '../models/activity_photo_uploader.dart';

// Image formats accepted for an activity photo.
enum PhotoFormat { jpeg, png }

enum CreateField { title, location, date, time }

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
  CreateActivityController({ActivitiesModel? activitiesModel})
    : _activitiesModel = activitiesModel ?? ActivitiesModel();

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
    _touched.add(CreateField.location);
    notifyListeners();
  }

  void setDate(DateTime value) {
    _date = DateTime(value.year, value.month, value.day);
    _touched.add(CreateField.date);
    notifyListeners();
  }

  void setTime(TimeOfDay value) {
    _time = value;
    _touched.add(CreateField.time);
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
        _photoError = "This image's file type and its contents don't match. Try another photo.";
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

  static final RegExp titleAllowed = RegExp(r'[\p{L} ]', unicode: true);

  String? validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.isEmpty) return 'Add a title';
    if (title.characters.length > ActivityConstants.titleMaxLength) {
      return 'Keep it to ${ActivityConstants.titleMaxLength} letters';
    }
    if (!RegExp(r'^[\p{L} ]+$', unicode: true).hasMatch(title)) {
      return 'Use letters only';
    }
    return null;
  }

  String? validateDescription(String? value) {
    final description = value?.trim() ?? '';
    if (description.length > ActivityConstants.descriptionMaxLength) {
      return 'Keep it to ${ActivityConstants.descriptionMaxLength} characters';
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
    CreateField.title => validateTitle(titleController.text),
    CreateField.location => _locationName.isEmpty ? 'Choose a location' : null,
    CreateField.date => _date == null
        ? 'Pick a date'
        : _date!.isAfter(ActivityConstants.latestAllowedDate(DateTime.now()))
        ? 'Choose a date within the next 3 months'
        : null,
    CreateField.time =>
      _time == null
          ? 'Pick a time'
          : startsAt != null && !startsAt!.isAfter(DateTime.now())
          ? 'This time has already passed'
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
    } catch (error) {
      debugPrint('SYNK: create activity failed: $error');
      _errorMessage = "We couldn't create your activity. Please try again.";
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
