import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants/activity_categories.dart';
import '../models/activities_model.dart';
import '../models/activity_filters.dart';
import '../models/activity_model.dart';
import '../models/user_profile_model.dart';

// Discovery feed plus the one shared filter state. Home (search, day strip,
// category chips, filter sheet) and the Map tab all read and write it here.
class HomeDiscoveryController extends ChangeNotifier {
  HomeDiscoveryController({
    ActivitiesModel? activitiesModel,
    UserProfileModel? profileModel,
  }) : _activitiesModel = activitiesModel ?? ActivitiesModel(),
       _profileModel = profileModel ?? UserProfileModel();

  final ActivitiesModel _activitiesModel;
  final UserProfileModel _profileModel;

  final TextEditingController searchController = TextEditingController();

  // Every category, then "Other"; only those found in the feed are offered,
  // so each activity in the feed is reachable from some chip.
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
  // Permission denied or location services off, as opposed to a slow fix.
  bool get locationBlocked => _locationBlocked;

  bool get hasActiveFilters => searchQuery.isNotEmpty || !_filters.isDefault;

  // Sheet sections that differ from their defaults (the filter badge).
  int get activeFilterCount => _filters.changedSectionCount;

  // Categories to offer: those present in the feed, plus any still selected
  // so they can be turned off.
  List<String> get feedCategories {
    final labels = categoriesInFeed(knownCategories);
    for (final selected in _filters.categories) {
      if (!labels.contains(selected)) labels.add(selected);
    }
    return labels;
  }

  // Activities per day for the day strip. Uses every filter except the
  // date itself, so picking Padel only marks days that have Padel.
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

  // Loads the feed and, without prompting, the user's location. Safe to
  // call from both Home and Map; only the first call does anything.
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

      // 2. Fetch discovery feed with exclusion & female visibility rule
      final activities = await _activitiesModel.fetchDiscoveryFeed(
        currentUserId: _currentUserId,
        currentUserGender: _currentUserGender,
      );

      _allActivities = activities;
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Unable to load activities. Pull down to refresh.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Gets the user's location for "Near me". With [request], asks for
  // permission or opens the relevant settings page if it was refused.
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

  // How many activities [draft] would show; the sheet's live count.
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

  // Day strip tap: selects that day, or clears the date if it was the
  // only day selected.
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

  // Category chip tap on Home or Map.
  void toggleCategory(String category) {
    applyFilters(_filters.toggleCategory(category));
  }

  void clearCategories() {
    applyFilters(_filters.copyWith(categories: const {}));
  }

  // Resets the search, the sheet, the day strip and the category chips.
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
