import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../models/activity_participation_model.dart';

class ActivityJoinRequestsController extends ChangeNotifier {
  ActivityJoinRequestsController({
    ActivityParticipationModel? participationModel,
  }) : _participationModel =
            participationModel ?? ActivityParticipationModel();

  final ActivityParticipationModel _participationModel;

  final List<PendingActivityRequest> _requests = [];
  final Set<String> _reviewingRequestIds = {};

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  List<PendingActivityRequest> get requests =>
      List.unmodifiable(_requests);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  bool isReviewing(String participationId) {
    return _reviewingRequestIds.contains(participationId);
  }

  // Loads pending requests for private activities hosted by this user.
  Future<void> loadRequests() async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final requests =
          await _participationModel.getPendingRequests();

      _requests
        ..clear()
        ..addAll(requests);
    } catch (_) {
      _errorMessage =
          appL10n.unableToLoadJoinRequestsPlease;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Accepts or rejects one private activity request.
  Future<void> reviewRequest({
    required PendingActivityRequest request,
    required bool accept,
  }) async {
    final participationId = request.participationId;

    // Prevents submitting the same request more than once.
    if (_reviewingRequestIds.contains(participationId)) {
      return;
    }

    _reviewingRequestIds.add(participationId);
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response =
          await _participationModel.reviewRequest(
        participationId: participationId,
        accept: accept,
      );

      final result = response.result.trim().toLowerCase();
      final status = response.status?.trim().toLowerCase();

      // Supports the possible success values returned by the RPC.
      final successfulStatuses = {
        'joined',
        'waitlisted',
        'rejected',
      };

          final successfulResults = {
        'joined',
        'waitlisted',
        'rejected',
      };

      final wasSuccessful =
          successfulStatuses.contains(status) ||
          successfulResults.contains(result);

      if (wasSuccessful) {
        // Removes the reviewed request immediately from the interface.
        _requests.removeWhere(
          (item) =>
              item.participationId == participationId,
        );

        if (status == 'waitlisted') {
          _successMessage =
              appL10n.requestApprovedTheUserWasAdded;
        } else if (accept) {
          _successMessage =
              appL10n.requestApprovedSuccessfully;
        } else {
          _successMessage =
              appL10n.requestRejectedSuccessfully;
        }
      } else {
        _errorMessage = response.message;
      }
    } catch (_) {
      _errorMessage =
          appL10n.unableToReviewTheRequestPlease;
    } finally {
      _reviewingRequestIds.remove(participationId);
      notifyListeners();
    }
  }

  void clearMessage() {
    if (_errorMessage == null &&
        _successMessage == null) {
      return;
    }

    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}