import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';

class OverlappingActivityNotice extends StatelessWidget {
  const OverlappingActivityNotice({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: SynkColors.orange.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: SynkColors.orangeDark.withValues(alpha: 0.18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.overlappingActivity,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: SynkColors.textPrimary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          context.l10n.overlappingActivityNotice,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: SynkColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
