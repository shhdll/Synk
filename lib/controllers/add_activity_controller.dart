import 'package:flutter/material.dart';

import '../models/activity_model.dart';

class AddActivityController extends ChangeNotifier {
  AddActivityController({required ActivityStore activityStore})
    : _activityStore = activityStore;

  final ActivityStore _activityStore;

  static const List<Map<String, String>> categories = [
    {'emoji': '🎾', 'label': 'Padel'},
    {'emoji': '🎲', 'label': 'Board Games'},
    {'emoji': '🏎️', 'label': 'Karting'},
    {'emoji': '🗝️', 'label': 'Escape Room'},
    {'emoji': '♟️', 'label': 'Chess'},
    {'emoji': '🧗', 'label': 'Climbing'},
    {'emoji': '🎳', 'label': 'Bowling'},
    {'emoji': '⚽', 'label': 'Football'},
    {'emoji': '🏀', 'label': 'Basketball'},
    {'emoji': '🥾', 'label': 'Hiking'},
    {'emoji': '🍳', 'label': 'Cooking'},
    {'emoji': '🎨', 'label': 'Art'},
  ];

  final titleController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  int selectedCategory = 0;
  DateTime? date;
  TimeOfDay? time;

  String? titleError;
  String? dateError;
  String? locationError;

  void selectCategory(int index) {
    selectedCategory = index;
    notifyListeners();
  }

  void setDate(DateTime value) {
    date = value;
    notifyListeners();
  }

  void setTime(TimeOfDay value) {
    time = value;
    notifyListeners();
  }

  // Validates the form and, if valid, adds the activity to the store.
  // Returns true on success.
  bool submit() {
    titleError = titleController.text.trim().isEmpty
        ? 'Give your activity a title'
        : null;
    dateError = date == null ? 'Pick a date' : null;
    locationError = locationController.text.trim().isEmpty
        ? 'Add a location'
        : null;
    notifyListeners();

    if (titleError != null || dateError != null || locationError != null) {
      return false;
    }

    final pickedTime = time ?? TimeOfDay.now();
    final dateTime = DateTime(
      date!.year,
      date!.month,
      date!.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final category = categories[selectedCategory];

    _activityStore.add(
      Activity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: titleController.text.trim(),
        categoryEmoji: category['emoji']!,
        categoryLabel: category['label']!,
        dateTime: dateTime,
        location: locationController.text.trim(),
        description: descriptionController.text.trim(),
      ),
    );
    return true;
  }

  @override
  void dispose() {
    titleController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
