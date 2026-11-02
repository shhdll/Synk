import 'package:shared_preferences/shared_preferences.dart';

// Decides when the streak sheet pops up on its own when the app opens:
// at most once a day for each user, so it greets them without nagging.
class StreakIntro {
  static String _key(String userId) => 'streak_intro_shown_$userId';

  static String _day(DateTime time) => '${time.year}-${time.month}-${time.day}';

  // True the first time it's asked on a given day, then false until
  // tomorrow. Errors count as "already shown" so the app never gets stuck.
  static Future<bool> takeTurn(String? userId, {DateTime? now}) async {
    if (userId == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _day(now ?? DateTime.now());
      if (prefs.getString(_key(userId)) == today) return false;
      await prefs.setString(_key(userId), today);
      return true;
    } catch (_) {
      return false;
    }
  }
}
