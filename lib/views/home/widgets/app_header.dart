import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';

// Logo tile + wordmark used at the top of every tab for a consistent brand
// header, matching the style used across the auth screens.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.asset(
              'assets/synk_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.all_inclusive_rounded,
                color: SynkColors.orange,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Synk',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: SynkColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
