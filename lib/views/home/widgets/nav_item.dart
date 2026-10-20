import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';

// A single icon tab in the bottom navigation bar. The label isn't shown,
// but screen readers and a long press still get it.
class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SynkColors.orangeDark : SynkColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            child: Badge(
              isLabelVisible: badgeCount > 0,
              label: Text(badgeCount > 9 ? '9+' : '$badgeCount'),
              backgroundColor: SynkColors.badge,
              textColor: Colors.white,
              child: Icon(icon, size: 32, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
