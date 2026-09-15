import 'package:flutter/foundation.dart';

import '../models/user_profile_model.dart';

class EditInterestsController extends ChangeNotifier {
  EditInterestsController({
    required List<String> initialInterests,
    UserProfileModel? profileModel,
  }) : _selected = List.of(initialInterests),
       _profileModel = profileModel ?? UserProfileModel();

  final UserProfileModel _profileModel;
  final List<String> _selected;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  List<String> get selected => List.unmodifiable(_selected);

  bool isSelected(String interest) => _selected.contains(interest);

  // Adds or removes the interest and persists the change right away.
  Future<void> toggle(String interest) async {
    final wasSelected = _selected.contains(interest);
    if (wasSelected) {
      _selected.remove(interest);
    } else {
      _selected.add(interest);
    }
    notifyListeners();

    _isSaving = true;
    notifyListeners();
    try {
      await _profileModel.updateProfile({'interests': _selected});
    } catch (_) {
      // Roll back on failure so the UI reflects what's actually saved.
      if (wasSelected) {
        _selected.add(interest);
      } else {
        _selected.remove(interest);
      }
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
