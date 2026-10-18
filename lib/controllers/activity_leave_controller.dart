import 'package:flutter/foundation.dart';

import '../models/activity_participation_model.dart';

class ActivityLeaveController extends ChangeNotifier {
  ActivityLeaveController({ActivityParticipationModel? participationModel})
    : _participationModel = participationModel ?? ActivityParticipationModel();

  final ActivityParticipationModel _participationModel;

  // Database results that confirm a completed withdrawal.
  static const Set<String> _leaveSuccessResults = {
    'left',
    'left_waitlist',
    'cancelled',
  };

  static const Set<String> _transferSuccessResults = {'transferred'};

  // Refusals whose database message is safe to show as is.
  static const Set<String> _knownFailureResults = {
    'not_found',
    'host',
    'not_host',
    'activity_started',
    'not_participating',
    'invalid_new_host',
    'not_eligible',
  };

  final Set<String> _busyActivityIds = {};

  // Requests may finish after the details sheet closes.
  bool _isDisposed = false;

  String? _errorMessage;

  String? _failureResult;

  String? get errorMessage => _errorMessage;

  // The database result of the last refused request, such as
  // 'not_participating', or null after a success or a network failure.
  String? get failureResult => _failureResult;

  // Allows the details sheet to know whether its request is running.
  bool isBusy(String activityId) {
    return _busyActivityIds.contains(activityId);
  }

  // Leaves a joined activity, leaves its waitlist, or cancels a request.
  // Returns the confirmed result, or null when nothing was changed.
  Future<ActivityJoinResult?> leaveActivity(String activityId) {
    return _run(
      activityId: activityId,
      request: () => _participationModel.leaveActivity(activityId),
      successResults: _leaveSuccessResults,
      fallbackError: 'Unable to leave the activity. Please try again.',
    );
  }

  // Makes the chosen joined participant the host and removes the current host.
  Future<ActivityJoinResult?> transferHostAndLeave({
    required String activityId,
    required String newHostUserId,
  }) {
    return _run(
      activityId: activityId,
      request: () => _participationModel.transferHostAndLeave(
        activityId: activityId,
        newHostUserId: newHostUserId,
      ),
      successResults: _transferSuccessResults,
      fallbackError: 'Unable to transfer hosting. Please try again.',
    );
  }

  void clearError() {
    if (_errorMessage == null && _failureResult == null) return;

    _errorMessage = null;
    _failureResult = null;
    _notify();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<ActivityJoinResult?> _run({
    required String activityId,
    required Future<ActivityJoinResult> Function() request,
    required Set<String> successResults,
    required String fallbackError,
  }) async {
    // A request for this activity is already running.
    if (_busyActivityIds.contains(activityId)) {
      return null;
    }

    _busyActivityIds.add(activityId);
    _errorMessage = null;
    _failureResult = null;
    _notify();

    try {
      final result = await request();

      if (successResults.contains(result.result)) {
        return result;
      }

      if (_knownFailureResults.contains(result.result)) {
        _failureResult = result.result;
        _errorMessage = result.message;
      } else {
        _errorMessage = fallbackError;
      }

      return null;
    } catch (_) {
      _errorMessage = fallbackError;
      return null;
    } finally {
      _busyActivityIds.remove(activityId);
      _notify();
    }
  }
}
