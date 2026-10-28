import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants/activity_categories.dart';
import '../l10n/l10n.dart';
import '../models/activities_model.dart';
import 'friends_controller.dart';
import '../models/activity_filters.dart';
import '../models/activity_model.dart';
import '../models/user_profile_model.dart';

// Feed + filters shared by Home and Map.
class HomeDiscoveryController extends ChangeNotifier {
  HomeDiscoveryController({
    ActivitiesModel? activitiesModel,
    UserProfileModel? profileModel,
  }) : _activitiesModel = activitiesModel ?? ActivitiesModel(),
       _profileModel = profileModel ?? UserProfileModel();

  final ActivitiesModel _activitiesModel;
  final UserProfileModel _profileModel;

  final TextEditingController searchController = TextEditingController();

  static final List<String> knownCategories = [
    ...kActivityCategories.keys,
    kOtherCategory,
  ];

  List<Activity> _allActivities = [];
  List<Activity> _filteredActivities = [];

  bool _isLoading = true;
  String? _errorMessage;
  bool _started = false;

  String _currentUserName = 'there';
  String? _currentUserGender;
  String? _currentUserId;

  ActivityFilters _filters = ActivityFilters.defaults;

  GeoPoint? _userLocation;
  bool _isLocating = false;
  bool _locationBlocked = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Activity> get filteredActivities => _filteredActivities;
  List<Activity> get allActivities => _allActivities;
  String get currentUserName => _currentUserName;
  String? get currentUserGender => _currentUserGender;

  ActivityFilters get filters => _filters;
  String get searchQuery => searchController.text.trim();

  GeoPoint? get userLocation => _userLocation;
  bool get isLocating => _isLocating;
  bool get locationBlocked => _locationBlocked;

  bool get hasActiveFilters => searchQuery.isNotEmpty || !_filters.isDefault;

  int get activeFilterCount => _filters.changedSectionCount;

  List<String> get feedCategories {
    final labels = categoriesInFeed(knownCategories);
    for (final selected in _filters.categories) {
      if (!labels.contains(selected)) labels.add(selected);
    }
    return labels;
  }

  // Ignores the date filter so the strip still shows other days.
  Map<DateTime, int> get activityCountsByDay {
    final matching = _filters
        .withDate(DateOption.any)
        .apply(_allActivities, userLocation: _userLocation, search: searchQuery);
    final counts = <DateTime, int>{};
    for (final a in matching) {
      final day = DateUtils.dateOnly(a.dateTime);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  // Safe to call from both tabs, only loads once.
  Future<void> init() async {
    if (_started) return;
    _started = true;
    refreshLocation();
    await loadFeed();
  }

  Future<void> loadFeed({bool isSilent = false}) async {
    if (!isSilent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      // 1. Fetch user profile for name, gender, and ID
      final profile = await _profileModel.fetchProfile();
      final fullName = (profile['full_name'] as String?)?.trim();
      if (fullName != null && fullName.isNotEmpty) {
        _currentUserName = fullName.split(' ').first;
      }

      _currentUserGender = profile['gender'] as String?;
      _currentUserId = _activitiesModel.currentUserId;

      // 2. Fetch discovery feed with exclusion & same-gender visibility rule
      final activities = await _activitiesModel.fetchDiscoveryFeed(
        currentUserId: _currentUserId,
        currentUserGender: _currentUserGender,
      );

      _allActivities = activities;
      _applyFilters();

      // Which friends are going, for the cards.
      unawaited(
        FriendsController.instance.loadFriendsGoing(
          activities.map((a) => a.id),
        ),
      );
    } catch (e) {
      _errorMessage = appL10n.unableToLoadActivitiesPullDown;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshLocation({bool request = false}) async {
    if (_isLocating) return;
    _isLocating = true;
    notifyListeners();

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationBlocked = true;
        if (request) await Geolocator.openLocationSettings();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (request && permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationBlocked = true;
        if (request && permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
        return;
      }

      _locationBlocked = false;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _userLocation = (
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error) {
      debugPrint('SYNK: Could not get location for filters: $error');
    } finally {
      _isLocating = false;
      _applyFilters();
      notifyListeners();
    }
  }

  @visibleForTesting
  set userLocation(GeoPoint? value) {
    _userLocation = value;
    _applyFilters();
    notifyListeners();
  }

  int countFor(ActivityFilters draft) => draft
      .apply(_allActivities, userLocation: _userLocation, search: searchQuery)
      .length;

  void applyFilters(ActivityFilters filters) {
    _filters = filters;
    _applyFilters();
    notifyListeners();
  }

  void onSearchChanged(String query) {
    _applyFilters();
    notifyListeners();
  }

  void clearSearch() {
    searchController.clear();
    _applyFilters();
    notifyListeners();
  }

  void selectDay(DateTime day, {DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final picked = DateUtils.dateOnly(day);

    if (_filters.singleDay(today) == picked) {
      applyFilters(_filters.withDate(DateOption.any));
      return;
    }

    final offset = picked.difference(today).inDays;
    applyFilters(switch (offset) {
      0 => _filters.withDate(DateOption.today),
      1 => _filters.withDate(DateOption.tomorrow),
      _ => _filters.withDate(DateOption.custom, customDate: picked),
    });
  }

  void toggleCategory(String category) {
    applyFilters(_filters.toggleCategory(category));
  }

  void clearCategories() {
    applyFilters(_filters.copyWith(categories: const {}));
  }

  void clearAllFilters() {
    searchController.clear();
    applyFilters(ActivityFilters.defaults);
  }

  void _applyFilters() {
    _filteredActivities = _filters.apply(
      _allActivities,
      userLocation: _userLocation,
      search: searchQuery,
    );
  }

  // Category labels set on loaded activities, then any [known] category
  // that at least one loaded activity matches (by title or description).
  // Uses the whole feed, not the filtered list, so chips stay put while
  // filtering.
  List<String> categoriesInFeed(Iterable<String> known) {
    final labels = <String>[];
    for (final activity in _allActivities) {
      final label = activity.categoryLabel.trim();
      if (label.isNotEmpty && !labels.contains(label)) labels.add(label);
    }
    for (final category in known) {
      if (labels.contains(category)) continue;
      if (_allActivities.any((a) => matchesCategory(a, category))) {
        labels.add(category);
      }
    }
    return labels;
  }

  static bool matchesCategory(Activity activity, String category) =>
      ActivityFilters.matchesCategory(activity, category);

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
