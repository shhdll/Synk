import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';

// An icon + label/value row used in the Preferences section of the
// Profile screen.
class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitleWidget,
    this.onEdit,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? subtitleWidget;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: SynkColors.orangeDark),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: SynkColors.textPrimary,
                ),
              ),
              if (subtitleWidget != null) ...[
                const SizedBox(height: 4),
                subtitleWidget!,
              ],
            ],
          ),
        ),
        if (onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SynkColors.textSecondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 14,
                color: SynkColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
