import 'package:flutter/foundation.dart';

import '../models/onboarding_model.dart';

class OnboardingController extends ChangeNotifier {
  static const int stepCount = 5;
  static const int lastStepIndex = stepCount - 1;

  int _currentStep = 0;

  final List<String> _selectedInterests = [];

  String? _activityType;

  String? _locationPreference;

  int get currentStep => _currentStep;

  OnboardingStep get step => OnboardingStep.values[_currentStep];

  List<String> get selectedInterests => List.unmodifiable(_selectedInterests);

  String? get activityType => _activityType;

  String? get locationPreference => _locationPreference;

  void toggleInterest(String interest) {
    if (_selectedInterests.contains(interest)) {
      _selectedInterests.remove(interest);
    } else {
      _selectedInterests.add(interest);
    }

    notifyListeners();
  }

  void setActivityType(String value) {
    _activityType = value;
    notifyListeners();
  }

  void setLocationPreference(String value) {
    _locationPreference = value;
    notifyListeners();
  }

  void goToStep(int step) {
    if (step >= 0 && step <= lastStepIndex && step != _currentStep) {
      _currentStep = step;
      notifyListeners();
    }
  }

  void goToOnboardingStep(OnboardingStep step) {
    goToStep(step.index);
  }

  Map<String, dynamic> get onboardingData => {
    'interests': _selectedInterests,
    'activity_type': _activityType,
    'location_preference': _locationPreference,
  };
}
