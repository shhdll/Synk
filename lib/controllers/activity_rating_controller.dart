import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../models/activity_rating_model.dart';

// Holds the stars chosen in the rating prompt and sends them once.
class ActivityRatingController extends ChangeNotifier {
  ActivityRatingController({
    required this.pending,
    ActivityRatingModel? model,
  }) : _model = model ?? ActivityRatingModel();

  final PendingActivityRating pending;
  final ActivityRatingModel _model;

  // Half stars per user id; users without an entry are not rated.
  final Map<String, int> _halfStars = {};

  bool _isBusy = false;
  bool _isDisposed = false;
  String? _errorMessage;

  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  bool get canSubmit => _halfStars.isNotEmpty && !_isBusy;

  int halfStarsFor(String userId) => _halfStars[userId] ?? 0;

  // 0 clears the rating for that user.
  void setHalfStars(String userId, int halfStars) {
    if (_isBusy) return;

    if (halfStars <= 0) {
      _halfStars.remove(userId);
    } else {
      _halfStars[userId] = halfStars.clamp(1, 10);
    }
    _errorMessage = null;
    _notify();
  }

  // Returns true once the database has saved every rating.
  Future<bool> submit() async {
    if (!canSubmit) return false;

    _setBusy(true);
    try {
      final result = await _model.submit(
        activityId: pending.activity.id,
        halfStarsByUser: Map.of(_halfStars),
      );

      if (result == 'rated') return true;

      _errorMessage = _messageFor(result);
      return false;
    } catch (_) {
      _errorMessage = appL10n.somethingWentWrongPleaseTryAgain;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  // Stops offering this activity. A failure is ignored, so the prompt
  // simply returns on a later app opening.
  Future<void> skip() async {
    if (_isBusy) return;

    _setBusy(true);
    try {
      await _model.dismiss(pending.activity.id);
    } catch (_) {
      // The prompt is offered again later if dismissing fails.
    } finally {
      _setBusy(false);
    }
  }

  String _messageFor(String result) {
    final l = appL10n;
    return switch (result) {
      'not_ended' => l.ratingNotEnded,
      'not_eligible' => l.ratingNotEligible,
      'already_rated' => l.ratingAlreadyRated,
      'invalid_rating' => l.ratingInvalid,
      'not_found' => l.ratingActivityUnavailable,
      _ => l.somethingWentWrongPleaseTryAgain,
    };
  }

  void _setBusy(bool value) {
    _isBusy = value;
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
}
