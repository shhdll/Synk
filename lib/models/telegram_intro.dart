import 'package:shared_preferences/shared_preferences.dart';

// Decides when the Telegram popup shows on its own: once for each account
// on a device, never again after that.
class TelegramIntro {
  static String _key(String userId) => 'telegram_intro_shown_$userId';

  // True only the first time it's asked for this account on this device.
  // Errors count as "already shown" so the app never gets stuck.
  static Future<bool> takeTurn(String? userId) async {
    if (userId == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_key(userId)) == true) return false;
      await prefs.setBool(_key(userId), true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
