import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The app's language. The choice is saved on the device; until the user
// picks one, the app follows the phone's language (Arabic or English).
class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final LanguageController instance = LanguageController._();

  static const supportedLocales = [Locale('en'), Locale('ar')];
  static const _prefsKey = 'app_language';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;
  bool get isArabic => _locale.languageCode == 'ar';

  // Reads the saved choice. Call once before runApp.
  Future<void> load() async {
    String? saved;
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
      );
      saved = prefs.getString(_prefsKey);
    } catch (_) {
      // Fall back to the phone's language below.
    }
    final code =
        saved ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _locale = code == 'ar' ? const Locale('ar') : const Locale('en');
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == _locale.languageCode) return;
    _locale = Locale(locale.languageCode);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _locale.languageCode);
    } catch (_) {
      // The language still changes for this session.
    }
  }
}
