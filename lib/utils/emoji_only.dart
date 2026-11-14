import 'package:flutter/widgets.dart';

// Messages that are only a few emoji show big and without a bubble, like
// WhatsApp.

// The valid_regexps lint doesn't know Unicode property escapes, which work
// with unicode: true.
final _pictographic = RegExp(
  // ignore: valid_regexps
  r'\p{Extended_Pictographic}|\p{Regional_Indicator}|⃣',
  unicode: true,
);

final _emojiParts = RegExp(
  // ignore: valid_regexps
  r'^(?:\p{Extended_Pictographic}|\p{Emoji_Modifier}|\p{Regional_Indicator}'
  r'|\p{Emoji_Component}|[‍️⃣])+$',
  unicode: true,
);

// How many emoji [text] is when it's nothing else (spaces aside), up to
// [max]; 0 when it has anything else in it or more than [max].
int emojiOnlyCount(String text, {int max = 3}) {
  // Asked for every bubble on every rebuild: remember recent answers.
  final key = '$max|$text';
  final cached = _cache[key];
  if (cached != null) return cached;
  final count = _emojiOnlyCount(text, max);
  if (_cache.length >= 500) _cache.remove(_cache.keys.first);
  _cache[key] = count;
  return count;
}

final Map<String, int> _cache = {};

int _emojiOnlyCount(String text, int max) {
  var count = 0;
  for (final character in text.characters) {
    if (character.trim().isEmpty) continue;
    // Digits, # and * are emoji components too, but alone they're text.
    if (!_emojiParts.hasMatch(character) ||
        !_pictographic.hasMatch(character)) {
      return 0;
    }
    if (++count > max) return 0;
  }
  return count;
}

// The font size for a message of [count] emoji: one is biggest.
double emojiOnlyFontSize(int count) => switch (count) {
  1 => 52,
  2 => 44,
  _ => 36,
};
