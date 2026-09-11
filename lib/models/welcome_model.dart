class ActivityItem {
  final String emoji;
  final String label;

  const ActivityItem({required this.emoji, required this.label});
}

class WelcomeModel {
  final int totalSlides;
  final List<ActivityItem> activities;

  const WelcomeModel({
    this.totalSlides = 2,
    this.activities = const [
      ActivityItem(emoji: '🎾', label: 'Padel'),
      ActivityItem(emoji: '🎲', label: 'Board Games'),
      ActivityItem(emoji: '🏎️', label: 'Karting'),
      ActivityItem(emoji: '🗝️', label: 'Escape Room'),
      ActivityItem(emoji: '♟️', label: 'Chess'),
      ActivityItem(emoji: '🧗', label: 'Climbing'),
    ],
  });
}
