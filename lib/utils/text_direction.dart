import 'package:flutter/services.dart';

// Arabic (and other right-to-left) letters, and Latin letters.
final _rtlLetter = RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]');
final _ltrLetter = RegExp(r'[A-Za-z\u00C0-\u024F]');

/// Drops Arabic as it's typed or pasted. Used on activity titles, which stay
/// in Latin letters; names, bios and descriptions accept Arabic.
final noArabicFormatter = FilteringTextInputFormatter.deny(_rtlLetter);

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
