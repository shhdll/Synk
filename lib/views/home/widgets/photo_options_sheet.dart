import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';

// Asks whether to change, adjust or remove the profile photo. Pops
// 'change', 'adjust', 'remove', or null (dismissed without choosing).
class PhotoOptionsSheet extends StatelessWidget {
  const PhotoOptionsSheet({super.key, required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Runs under the navigation bar so no dark strip shows below it.
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: SynkColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: SynkColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            context.l10n.profilePhoto,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: SynkColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _OptionTile(
            icon: Icons.photo_camera_outlined,
            label: hasPhoto ? context.l10n.changePhoto : context.l10n.addPhoto,
            onTap: () => Navigator.of(context).pop('change'),
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.crop_rounded,
              label: context.l10n.adjustPhoto,
              onTap: () => Navigator.of(context).pop('adjust'),
            ),
            const SizedBox(height: 10),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: context.l10n.removePhoto,
              iconColor: const Color(0xFFE53935),
              textColor: const Color(0xFFE53935),
              onTap: () => Navigator.of(context).pop('remove'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? SynkColors.textPrimary),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? SynkColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
