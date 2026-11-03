import 'package:shared_preferences/shared_preferences.dart';

// The last few searches of one search box, kept on this phone only.
class RecentSearches {
  const RecentSearches([this._key = 'home_recent_searches']);

  static const _max = 6;

  final String _key;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  // Newest first; the same search moves back to the top.
  Future<List<String>> add(String query) async {
    final text = query.trim();
    final current = await load();
    if (text.isEmpty) return current;
    return _save(
      [
        text,
        for (final q in current)
          if (q.toLowerCase() != text.toLowerCase()) q,
      ].take(_max).toList(),
    );
  }

  Future<List<String>> remove(String query) async {
    final current = await load();
    return _save([
      for (final q in current)
        if (q != query) q,
    ]);
  }

  Future<List<String>> _save(List<String> next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next);
    return next;
  }
}
