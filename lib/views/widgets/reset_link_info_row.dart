import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';

// A bullet-style row (teal icon badge + text) used on the "check your
// inbox" state of the Forgot Password screen.
class ResetLinkInfoRow extends StatelessWidget {
  const ResetLinkInfoRow({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: SynkColors.teal.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: SynkColors.teal),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: SynkColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
