import 'package:flutter/material.dart';

import '../models/activities_model.dart';
import '../models/activity_model.dart';
import '../models/user_profile_model.dart';

enum TimeFilterOption {
  all('All Time'),
  today('Today'),
  thisWeek('This Week'),
  customDate('Custom Date');

  const TimeFilterOption(this.label);
  final String label;
}

class HomeDiscoveryController extends ChangeNotifier {
  HomeDiscoveryController({
    ActivitiesModel? activitiesModel,
    UserProfileModel? profileModel,
  }) : _activitiesModel = activitiesModel ?? ActivitiesModel(),
       _profileModel = profileModel ?? UserProfileModel();

  final ActivitiesModel _activitiesModel;
  final UserProfileModel _profileModel;

  final TextEditingController searchController = TextEditingController();

  List<Activity> _allActivities = [];
  List<Activity> _filteredActivities = [];

  bool _isLoading = true;
  String? _errorMessage;

  String _currentUserName = 'there';
  String? _currentUserGender;
  String? _currentUserId;

  TimeFilterOption _selectedTimeFilter = TimeFilterOption.all;
  DateTime? _customSelectedDate;

  String? _selectedLocation;
  String? _selectedCategory;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Activity> get filteredActivities => _filteredActivities;
  List<Activity> get allActivities => _allActivities;
  String get currentUserName => _currentUserName;
  String? get currentUserGender => _currentUserGender;

  TimeFilterOption get selectedTimeFilter => _selectedTimeFilter;
  DateTime? get customSelectedDate => _customSelectedDate;
  String? get selectedLocation => _selectedLocation;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => searchController.text.trim();

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      _selectedTimeFilter != TimeFilterOption.all ||
      _selectedLocation != null ||
      _selectedCategory != null;

  // Filters set from the filter sheet (time and location). Category has
  // its own always-visible chips, so it is not counted here.
  int get activeFilterCount {
    int count = 0;
    if (_selectedTimeFilter != TimeFilterOption.all) count++;
    if (_selectedLocation != null) count++;
    return count;
  }

  // Extract distinct locations from activities
  List<String> get availableLocations {
    final set = <String>{};
    for (final act in _allActivities) {
      final loc = act.location.trim();
      if (loc.isNotEmpty) {
        // Take the main city or neighborhood if comma-separated
        final parts = loc.split(',');
        set.add(parts.first.trim());
      }
    }
    return set.toList()..sort();
  }

  // Extract distinct categories from activities
  List<Map<String, String>> get availableCategories {
    final map = <String, String>{};
    for (final act in _allActivities) {
      if (act.categoryLabel.isNotEmpty) {
        map[act.categoryLabel] = act.categoryEmoji.isNotEmpty
            ? act.categoryEmoji
            : '✨';
      }
    }
    return map.entries.map((e) => {'label': e.key, 'emoji': e.value}).toList();
  }

  Future<void> init() async {
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

  void onSearchChanged(String query) {
    _applyFilters();
    notifyListeners();
  }

  void clearSearch() {
    searchController.clear();
    _applyFilters();
    notifyListeners();
  }

  void setTimeFilter(TimeFilterOption option, {DateTime? customDate}) {
    _selectedTimeFilter = option;
    if (option == TimeFilterOption.customDate) {
      _customSelectedDate = customDate;
    } else {
      _customSelectedDate = null;
    }
    _applyFilters();
    notifyListeners();
  }

  // Sets (not toggles) the location, so re-applying the filter sheet with
  // an unchanged location keeps it.
  void setLocationFilter(String? location) {
    final clean = location?.trim();
    _selectedLocation = clean == null || clean.isEmpty ? null : clean;
    _applyFilters();
    notifyListeners();
  }

  void setCategoryFilter(String? categoryLabel) {
    if (_selectedCategory == categoryLabel) {
      _selectedCategory = null;
    } else {
      _selectedCategory = categoryLabel;
    }
    _applyFilters();
    notifyListeners();
  }

  void clearAllFilters() {
    searchController.clear();
    _selectedTimeFilter = TimeFilterOption.all;
    _customSelectedDate = null;
    _selectedLocation = null;
    _selectedCategory = null;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    final query = searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    _filteredActivities = _allActivities.where((activity) {
      // 1. Text Search: title, description, or location (name or address)
      if (query.isNotEmpty) {
        final searchable = [
          activity.title,
          activity.description,
          activity.location,
          activity.locationAddress ?? '',
          activity.categoryLabel,
        ];
        if (!searchable.any((field) => field.toLowerCase().contains(query))) {
          return false;
        }
      }

      // 2. Time Filter
      final actDate = activity.dateTime;
      final actDay = DateTime(actDate.year, actDate.month, actDate.day);

      switch (_selectedTimeFilter) {
        case TimeFilterOption.all:
          break;
        case TimeFilterOption.today:
          if (actDay != today) return false;
          break;
        case TimeFilterOption.thisWeek:
          final nextWeek = today.add(const Duration(days: 7));
          if (actDay.isBefore(today) || actDay.isAfter(nextWeek)) return false;
          break;
        case TimeFilterOption.customDate:
          if (_customSelectedDate != null) {
            final customDay = DateTime(
              _customSelectedDate!.year,
              _customSelectedDate!.month,
              _customSelectedDate!.day,
            );
            if (actDay != customDay) return false;
          }
          break;
      }

      // 3. Location Filter
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        final locFilter = _selectedLocation!.toLowerCase();
        final actLoc = activity.location.toLowerCase();
        final actAddr = (activity.locationAddress ?? '').toLowerCase();
        if (!actLoc.contains(locFilter) && !actAddr.contains(locFilter)) {
          return false;
        }
      }

      // 4. Category Filter. Most activities have no category label, so
      // also match the category name in the title or description.
      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        if (!matchesCategory(activity, _selectedCategory!)) return false;
      }

      return true;
    }).toList();
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

  static bool matchesCategory(Activity activity, String category) {
    final wanted = category.trim().toLowerCase();
    if (activity.categoryLabel.trim().toLowerCase() == wanted) return true;
    final text = '${activity.title} ${activity.description}'.toLowerCase();
    return RegExp('\\b${RegExp.escape(wanted)}').hasMatch(text);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}
