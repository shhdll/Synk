import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';

// Small bold heading used to divide a page into clearly labeled sections.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: SynkColors.textPrimary,
      ),
    );
  }
}
