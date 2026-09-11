import 'package:flutter/foundation.dart';

class OnboardingController extends ChangeNotifier {
  int _currentStep = 0;

  // Step 1
  final List<String> _selectedInterests = [];

  // Step 2
  String? _activityType;

  // Step 3
  String? _locationPreference;

  int get currentStep => _currentStep;

  List<String> get selectedInterests => _selectedInterests;

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

  void next() {
    if (_currentStep < 2) {
      _currentStep++;
      notifyListeners();
    }
  }

  void skipQuestion() {
    next();
  }

  void previous() {
  if (_currentStep > 0) {
    _currentStep--;
    notifyListeners();
  }
}
void goToStep(int step) {
  if (step >= 0 && step <= 4) {
    _currentStep = step;
    notifyListeners();
  }
}
}