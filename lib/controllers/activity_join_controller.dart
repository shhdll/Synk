import 'package:flutter/material.dart';

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
      _errorMessage = 'Enter a valid 6-digit activity code.';
      notifyListeners();
      return null;
    }

    _setLoading(true);

    try {
      final response = await _participationModel.joinActivityByCode(code);

      // These results represent valid join states.
      const validResults = {
        'joined',
        'waitlisted',
        'pending',
        'already_joined',
        'already_waitlisted',
        'already_pending',
        'host',
      };

      if (validResults.contains(response.result)) {
        _result = response;
      } else {
        _errorMessage = response.message;
      }

      return response;
    } catch (_) {
      _errorMessage = 'Unable to join the activity. Please try again.';
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Clears the previous message when the user changes the code.
  void clearFeedback() {
    if (_errorMessage == null && _result == null) return;

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
