import 'package:flutter/material.dart';

import '../../../models/home_tab.dart';
import 'add_button.dart';
import 'nav_item.dart';

// The pill-shaped bottom navigation bar with the floating add button,
// shown by MainShell.
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onAddTap,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: selected == HomeTab.home,
                  onTap: () => onSelect(HomeTab.home),
                ),
                NavItem(
                  icon: Icons.event_note_rounded,
                  label: 'Activities',
                  selected: selected == HomeTab.activities,
                  onTap: () => onSelect(HomeTab.activities),
                ),
                // Reserves space for the big + button floating above.
                const SizedBox(width: 56),
                NavItem(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  selected: selected == HomeTab.map,
                  onTap: () => onSelect(HomeTab.map),
                ),
                NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: selected == HomeTab.profile,
                  onTap: () => onSelect(HomeTab.profile),
                ),
              ],
            ),
          ),
          Positioned(top: -26, child: AddButton(onTap: onAddTap)),
        ],
      ),
    );
  }
}
