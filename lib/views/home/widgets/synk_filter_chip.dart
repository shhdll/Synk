import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import 'activity_thumbnail.dart';

class SynkFilterChip extends StatelessWidget {
  const SynkFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  SynkFilterChip.category({
    super.key,
    required String category,
    required this.selected,
    required this.onTap,
  }) : label = valueLabel(category),
       icon = ActivityVisual.forText(category).icon;

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final background = selected ? SynkColors.selected : Colors.white;
    final foreground = selected ? SynkColors.onSelected : SynkColors.ink;

    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(19),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(19),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: foreground),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
