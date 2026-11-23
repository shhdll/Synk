import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/l10n.dart';
import '../models/activity_participation_model.dart';

// Why a check-in didn't go through, ready to show.
typedef CheckInFailure = ({String title, String message});

// Checks the host or a joined member in at a running activity. The server makes the
// real decision (membership, time window and the 200 m radius); this side
// only gets the device's position and turns refusals into messages.
class ActivityCheckInController extends ChangeNotifier {
  ActivityCheckInController({ActivityParticipationModel? participationModel})
    : _participationModel = participationModel ?? ActivityParticipationModel();

  // Kept in step with check_in_radius_meters in
  // supabase/migrations/20261122100000_activity_check_in.sql.
  static const int radiusMeters = 200;

  final ActivityParticipationModel _participationModel;

  bool _isDisposed = false;

  bool _isBusy = false;

  bool get isBusy => _isBusy;

  DateTime? _checkedInAt;

  // When the viewer checked in; null until they do or while unknown.
  DateTime? get checkedInAt => _checkedInAt;

  bool get isCheckedIn => _checkedInAt != null;

  Future<void> loadStatus(String activityId) async {
    try {
      final checkedInAt = await _participationModel.fetchMyCheckIn(activityId);
      if (checkedInAt == null) return;
      _checkedInAt = checkedInAt;
      _notify();
    } catch (_) {
      // The Check in button stays; the server says if it's already done.
    }
  }

  // Returns null once the viewer is checked in, or why it failed.
  Future<CheckInFailure?> checkIn(String activityId) async {
    if (_isBusy) return null;

    _isBusy = true;
    _notify();

    try {
      final (position, failure) = await _currentPosition();
      if (position == null) {
        return failure ?? _failure(appL10n.checkInUnableToLocate);
      }

      final response = await _participationModel.checkIn(
        activityId: activityId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      switch (response.result) {
        case 'checked_in' || 'already_checked_in':
          _checkedInAt = response.checkedInAt ?? DateTime.now();
          return null;
        case 'too_far':
          debugPrint(
            'Synk check-in: ${response.distanceMeters} m from the activity '
            '(at ${position.latitude}, ${position.longitude})',
          );
          return (
            title: appL10n.checkInTooFarTitle,
            message: appL10n.checkInTooFar,
          );
        case 'not_started':
          return _failure(appL10n.checkInNotStarted);
        case 'ended':
          return _failure(appL10n.checkInEnded);
        case 'no_location':
          return _failure(appL10n.checkInNoLocation);
        case 'not_participating':
          return _failure(appL10n.checkInMembersOnly);
        default:
          return _failure(appL10n.checkInFailed);
      }
    } catch (error) {
      debugPrint('Synk check-in error: $error');
      return _failure(appL10n.checkInFailed);
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  // The device's position, or why it couldn't be read.
  Future<(Position?, CheckInFailure?)> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return (null, _failure(appL10n.checkInLocationOff));
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return (null, _failure(appL10n.checkInPermissionDenied));
    }
    if (permission == LocationPermission.denied) {
      return (null, _failure(appL10n.checkInPermissionDenied));
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      // Android reports positions from fake-GPS apps.
      if (position.isMocked) {
        return (null, _failure(appL10n.checkInMockedLocation));
      }
      return (position, null);
    } catch (_) {
      return (null, _failure(appL10n.checkInUnableToLocate));
    }
  }

  CheckInFailure _failure(String message) =>
      (title: appL10n.checkInFailedTitle, message: message);

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
