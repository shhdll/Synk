import 'package:flutter/foundation.dart';

class Activity {
  Activity({
    required this.id,
    required this.title,
    required this.categoryEmoji,
    required this.categoryLabel,
    required this.dateTime,
    required this.location,
    this.description = '',
  });

  final String id;
  final String title;
  final String categoryEmoji;
  final String categoryLabel;
  final DateTime dateTime;
  final String location;
  final String description;

  bool get isPast => dateTime.isBefore(DateTime.now());
}

// In-memory placeholder store. Starts empty; a real backend (e.g. a
// Supabase `activities` table) will replace this later.
class ActivityStore extends ChangeNotifier {
  final List<Activity> _activities = [];

  List<Activity> get all => List.unmodifiable(_activities);

  List<Activity> get upcoming =>
      _activities.where((a) => !a.isPast).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  List<Activity> get past =>
      _activities.where((a) => a.isPast).toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

  void add(Activity activity) {
    _activities.add(activity);
    notifyListeners();
  }
}
