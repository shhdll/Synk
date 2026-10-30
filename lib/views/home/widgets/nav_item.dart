import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';

// A single icon tab in the bottom navigation bar. The label isn't shown,
// but screen readers and a long press still get it. Takes a Material [icon]
// or an [image] with a transparent background, tinted the same way.
class NavItem extends StatelessWidget {
  const NavItem({
    super.key,
    this.icon,
    this.image,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData? icon;
  final ImageProvider? image;
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
              // Material icons leave ~2/24 empty around the shape; an image
              // drawn edge to edge is shrunk to match, in the same 32 box.
              child: image != null
                  ? SizedBox.square(
                      dimension: 32,
                      child: Center(
                        child: ImageIcon(image, size: 26, color: color),
                      ),
                    )
                  : Icon(icon, size: 32, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
