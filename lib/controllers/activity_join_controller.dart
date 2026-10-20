import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/activity_participation_model.dart';

class ActivityJoinController extends ChangeNotifier {
  ActivityJoinController({ActivityParticipationModel? participationModel})
    : _participationModel = participationModel ?? ActivityParticipationModel();

  final ActivityParticipationModel _participationModel;

  final TextEditingController codeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  ActivityJoinResult? _result;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  ActivityJoinResult? get result => _result;

  // Validates the code before sending it to Supabase.
  Future<ActivityJoinResult?> joinByCode() async {
    final code = codeController.text.trim();

    _errorMessage = null;
    _result = null;

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _errorMessage = appL10n.enterAValid6DigitActivity;
      notifyListeners();
      return null;
    }

    _setLoading(true);

    try {
      final response = await _participationModel.joinActivityByCode(code);

      // These results allow the sheet to close and show
      // a confirmation popup on the Home page.
      const successfulResults = {
        'joined',
        'waitlisted',
        'pending',
        'already_joined',
        'already_waitlisted',
        'already_pending',
        'time_conflict',
      };

      if (successfulResults.contains(response.result)) {
        _result = response;
      } else {
        // Invalid code, host-owned activity, or started activity
        // remains inside the sheet as an inline error.
        _errorMessage = response.message;
      }

      return response;
    } catch (_) {
      _errorMessage = appL10n.unableToJoinTheActivityPlease;
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Clears the previous feedback when the code changes.
  void clearFeedback() {
    if (_errorMessage == null && _result == null) {
      return;
    }

    _errorMessage = null;
    _result = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }
}
