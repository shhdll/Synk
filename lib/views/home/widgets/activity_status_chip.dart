import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../models/activity_model.dart';

// Small pill showing whether an activity can still be joined:
// Available, One More Needed, or Full.
class ActivityStatusChip extends StatelessWidget {
  const ActivityStatusChip({super.key, required this.availability});

  final ActivityAvailability availability;

  static (IconData, Color) _styleFor(ActivityAvailability availability) {
    return switch (availability) {
      ActivityAvailability.available => (
        Icons.check_circle_rounded,
        SynkColors.teal,
      ),
      ActivityAvailability.oneMoreNeeded => (
        Icons.person_add_alt_1_rounded,
        SynkColors.orangeDark,
      ),
      ActivityAvailability.full => (
        Icons.lock_outline_rounded,
        SynkColors.textSecondary,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _styleFor(availability);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            availability.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
