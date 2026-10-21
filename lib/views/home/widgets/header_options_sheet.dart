import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/profile_header.dart';

// Lets the user pick a header color or photo. Pops 'style:<id>', 'change',
// 'adjust', 'remove', or null (dismissed without choosing).
class HeaderOptionsSheet extends StatelessWidget {
  const HeaderOptionsSheet({
    super.key,
    required this.selectedStyle,
    required this.hasPhoto,
  });

  final String selectedStyle;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: SingleChildScrollView(
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
              context.l10n.profileHeader,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _Label(context.l10n.synkColors),
            _Swatches(
              styles: ProfileHeaders.synk,
              selected: hasPhoto ? null : selectedStyle,
            ),
            const SizedBox(height: 16),
            _Label(context.l10n.moreColors),
            _Swatches(
              styles: ProfileHeaders.general,
              selected: hasPhoto ? null : selectedStyle,
            ),
            const SizedBox(height: 16),
            _Label(context.l10n.headerPhoto),
            _OptionTile(
              icon: Icons.photo_camera_outlined,
              label: hasPhoto
                  ? context.l10n.changePhoto
                  : context.l10n.addPhoto,
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
                color: const Color(0xFFE53935),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: SynkColors.textSecondary,
        ),
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.styles, required this.selected});

  final List<ProfileHeaderStyle> styles;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final style in styles)
          GestureDetector(
            onTap: () => Navigator.of(context).pop('style:${style.id}'),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: style.gradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: style.id == selected
                      ? SynkColors.textPrimary
                      : Colors.white,
                  width: style.id == selected ? 2.5 : 2,
                ),
              ),
              child: style.id == selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 22,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

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
              Icon(icon, color: color ?? SynkColors.textPrimary),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color ?? SynkColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
