import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';

// A single labeled value row with a trailing edit button, used throughout
// the Edit Profile screen (name, bio, age, email, ...).
class EditableRow extends StatelessWidget {
  const EditableRow({
    super.key,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
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
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_rounded,
              size: 18,
              color: SynkColors.orangeDark,
            ),
          ),
        ],
      ),
    );
  }
}
