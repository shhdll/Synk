import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile_model.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({UserProfileModel? profileModel})
    : _profileModel = profileModel ?? UserProfileModel();

  final UserProfileModel _profileModel;

  Map<String, dynamic> _profile = {};
  Map<String, dynamic> get profile => _profile;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? get email => Supabase.instance.client.auth.currentUser?.email;

  // Loads the current user's row from the public "users" table.
  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();

    _profile = await _profileModel.fetchProfile();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateActivityType(String value) async {
    await _profileModel.updateProfile({'activity_type': value});
    _profile = {..._profile, 'activity_type': value};
    notifyListeners();
  }

  Future<void> updateLocationPreference(String value) async {
    await _profileModel.updateProfile({'location_preference': value});
    _profile = {..._profile, 'location_preference': value};
    notifyListeners();
  }
}
