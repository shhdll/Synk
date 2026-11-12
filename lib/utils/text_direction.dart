import 'package:flutter/services.dart';

// Arabic (and other right-to-left) letters, and Latin letters.
final _rtlLetter = RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]');
final _ltrLetter = RegExp(r'[A-Za-z\u00C0-\u024F]');

/// Whether [text] has any Arabic letters, for checks on save.
bool hasArabic(String text) => _rtlLetter.hasMatch(text);

/// The direction of [text], taken from its first letter: right to left when
/// it starts with Arabic, left to right when it starts with a Latin letter,
/// or null (use the app's direction) when it has no letters yet.
TextDirection? textDirectionOf(String text) {
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (_rtlLetter.hasMatch(char)) return TextDirection.rtl;
    if (_ltrLetter.hasMatch(char)) return TextDirection.ltr;
  }
  return null;
}

/// Wraps [text] so its direction doesn't spill into the text around it, e.g.
/// an Arabic message after "You: " keeps its punctuation in place.
String bidiIsolate(String text) => '\u2068$text\u2069';
