import 'dart:math' as math;

// Search that forgives typos and unfinished words, in English and Arabic:
// "padl", "Padle" and "pad" all find "Padel"; "البادل" finds "بادل".
// Words match from their start, so "p" finds "Pool" but not "Escape".
class FuzzySearch {
  // Searches shorter than this only look at [title] and [primary], since
  // one or two letters match too much of a long address or description.
  static const int shortQuery = 3;

  // How well [query] matches an item: null when it doesn't, otherwise a
  // score where lower is better (0 = every word found whole in [title]).
  //
  // Every word of the query must start some word of the item. Places are
  // tried in order, each one scoring a little worse than the last: [title],
  // [primary] (e.g. place), [secondary] (e.g. address), [loose]
  // (e.g. a description), and finally typo matches in [primary] and
  // [secondary]. Typos are never matched in [loose], where they'd find too
  // many unrelated words.
  static int? score(
    String query, {
    required String title,
    List<String> primary = const [],
    List<String> secondary = const [],
    List<String> loose = const [],
  }) {
    final queryWords = words(query);
    if (queryWords.isEmpty) return 0;

    // Fields keep "ال" words both ways, so "الرياض" and "رياض" find each
    // other.
    List<String> wordsOf(List<String> fields) =>
        words(fields.join(' '), keepArticle: true);
    final titleWords = wordsOf([title]);
    final primaryWords = wordsOf(primary);
    final secondaryWords = wordsOf(secondary);
    final looseWords = wordsOf(loose);

    var total = 0;
    for (final word in queryWords) {
      final near =
          _startCost(word, titleWords) ??
          _plus(2, _startCost(word, primaryWords));
      final cost = word.length < shortQuery
          ? near
          : near ??
                _plus(4, _startCost(word, secondaryWords)) ??
                _plus(6, _startCost(word, looseWords)) ??
                // Typos last, still name before place before address.
                _plus(8, _closestTypos(word, titleWords)) ??
                _plus(11, _closestTypos(word, primaryWords)) ??
                _plus(14, _closestTypos(word, secondaryWords));
      if (cost == null) return null;
      total += cost;
    }
    return total;
  }

  // 0 when [word] is one of [candidates], 1 when it's only the start of
  // one, null when it starts none.
  static int? _startCost(String word, List<String> candidates) {
    int? best;
    for (final candidate in candidates) {
      if (candidate == word) return 0;
      if (candidate.startsWith(word)) best = 1;
    }
    return best;
  }

  static int? _plus(int base, int? cost) => cost == null ? null : base + cost;
  // Typos allowed for a query word of this length. Short words get none,
  // or almost everything would match.
  static int allowedTypos(int length) {
    if (length < 4) return 0;
    if (length < 7) return 1;
    return 2;
  }

  // Fewest typos between [word] and any of [candidates] (whole, or just its
  // start, for unfinished words), or null when none is close enough.
  static int? _closestTypos(String word, List<String> candidates) {
    final allowed = allowedTypos(word.length);
    if (allowed == 0) return null;

    int? best;
    for (final candidate in candidates) {
      if (candidate.isEmpty) continue;
      if ((candidate.length - word.length).abs() > allowed &&
          candidate.length < word.length) {
        continue;
      }
      var d = distance(word, candidate);
      // Compare against the start of longer words: "padl" vs "pade(l...)".
      // Never a start shorter than the word, or "padl" would match "pal(aces)".
      for (var len = word.length; len <= word.length + 1; len++) {
        if (len >= candidate.length) continue;
        d = math.min(d, distance(word, candidate.substring(0, len)));
      }
      if (d <= allowed && (best == null || d < best)) best = d;
      if (best == 0) break;
    }
    return best;
  }

  // Edits (insert, delete, replace, swap two neighbours) to turn [a] into
  // [b]. Optimal string alignment distance.
  static int distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var before = List<int>.filled(b.length + 1, 0);
    var previous = List<int>.generate(b.length + 1, (j) => j);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var value = math.min(
          math.min(previous[j] + 1, current[j - 1] + 1),
          previous[j - 1] + cost,
        );
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          value = math.min(value, before[j - 2] + 1);
        }
        current[j] = value;
      }
      final spare = before;
      before = previous;
      previous = current;
      current = spare;
    }
    return previous[b.length];
  }

  // Splits [text] into comparable words: lower case, without accents,
  // Arabic diacritics or the "ال" prefix, and with letter variants unified
  // (أ إ آ → ا, ة → ه, ى → ي) and Arabic digits made Western.
  // With [keepArticle], words starting with "ال" are also kept as written.
  static List<String> words(String text, {bool keepArticle = false}) {
    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      if (_dropped.hasMatch(char)) continue;
      buffer.write(_replacements[char] ?? char);
    }
    return buffer
        .toString()
        .split(_separators)
        .where((word) => word.isNotEmpty)
        .expand(
          (word) => [
            _withoutArticle(word),
            if (keepArticle && _withoutArticle(word) != word) word,
          ],
        )
        .toList();
  }

  static String _withoutArticle(String word) =>
      word.length > 3 && word.startsWith('ال') ? word.substring(2) : word;

  // Arabic diacritics and the tatweel stretch.
  static final RegExp _dropped = RegExp('[ً-ٰٟـ]');

  static final RegExp _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static const Map<String, String> _replacements = {
    'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', //
    'ة': 'ه', 'ى': 'ي', 'ؤ': 'و', 'ئ': 'ي',
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
}
