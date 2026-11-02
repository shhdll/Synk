import 'package:flutter/material.dart';

class SynkColors {
  static const Color background = Color(0xFFF6F1E6);
  static const Color textPrimary = Color(0xFF1E1C24);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color pink = Color(0xFFFF9EC0);
  static const Color orange = Color(0xFFFF9F5C);
  static const Color orangeDark = Color(0xFFFF7A36);
  static const Color teal = Color(0xFF4FA89B);
  static const Color backgroundLight = Color(0xFFFFF5EF);

  // A step darker than background, for headers that sit on it. Matches
  // textSecondary at 12% over background, like the chat's + button.
  static const Color backgroundDark = Color(0xFFE5E2DA);
  static const Color beige = Color(0xFFE8D2B0);
  static const Color beigeDark = Color(0xFFC7A06B);

  // Deeper than orangeDark: text on orangeLight, or a fill under white text.
  static const Color orangeDeep = Color(0xFFCA602F);

  // Light orange fill for secondary buttons, e.g. Following and Message.
  static const Color orangeLight = Color(0xFFFCE3D4);

  // Filter colors (tealText/labelGrey darkened for contrast).
  static const Color ink = Color(0xFF2D2A32);
  static const Color tealText = Color(0xFF2A6F65);
  static const Color labelGrey = Color(0xFF5F6672);

  static const Color selected = orangeDark;
  static const Color onSelected = Colors.white;

  static const Color badge = Color(0xFFE5383B);
}
