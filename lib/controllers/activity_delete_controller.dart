import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../models/activities_model.dart';

class ActivityDeleteController extends ChangeNotifier {
  ActivityDeleteController({ActivitiesModel? activitiesModel})
    : _activitiesModel = activitiesModel ?? ActivitiesModel();

  final ActivitiesModel _activitiesModel;

  final Set<String> _deletingActivityIds = {};

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  // Allows each activity card to know whether its delete request is running.
  bool isDeleting(String activityId) {
    return _deletingActivityIds.contains(activityId);
  }

  // Deletes an activity from Supabase.
  Future<bool> deleteActivity(String activityId) async {
    if (_deletingActivityIds.contains(activityId)) {
      return false;
    }

    _deletingActivityIds.add(activityId);
    _errorMessage = null;
    notifyListeners();

    try {
      await _activitiesModel.delete(activityId);
      return true;
    } catch (_) {
      _errorMessage = appL10n.unableToDeleteTheActivityPlease;
      return false;
    } finally {
      _deletingActivityIds.remove(activityId);
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;

    _errorMessage = null;
    notifyListeners();
  }
}
