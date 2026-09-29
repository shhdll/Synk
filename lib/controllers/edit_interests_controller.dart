import 'package:flutter/foundation.dart';

import '../models/user_profile_model.dart';

class EditInterestsController extends ChangeNotifier {
  EditInterestsController({
    required List<String> initialInterests,
    UserProfileModel? profileModel,
  }) : _saved = List.of(initialInterests),
       _selected = List.of(initialInterests),
       _profileModel = profileModel ?? UserProfileModel();

  final UserProfileModel _profileModel;

  // What's currently stored on the profile.
  List<String> _saved;

  // What the user has picked on screen, not yet saved.
  final List<String> _selected;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  List<String> get selected => List.unmodifiable(_selected);

  bool isSelected(String interest) => _selected.contains(interest);

  // True when the on-screen selection differs from what's saved.
  // Order doesn't matter, only which interests are picked.
  bool get hasUnsavedChanges => !setEquals(_selected.toSet(), _saved.toSet());

  // Adds or removes the interest locally. Nothing is saved until save().
  void toggle(String interest) {
    if (_selected.contains(interest)) {
      _selected.remove(interest);
    } else {
      _selected.add(interest);
    }
    notifyListeners();
  }

  // Persists the current selection. Throws if the update fails.
  Future<void> save() async {
    _isSaving = true;
    notifyListeners();
    try {
      await _profileModel.updateProfile({'interests': _selected});
      _saved = List.of(_selected);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
