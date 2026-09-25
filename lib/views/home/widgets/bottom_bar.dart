import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
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
          Positioned(top: -30, child: _CreateAction(onTap: onAddTap)),
        ],
      ),
    );
  }
}

// The floating + button with its "Create" label directly beneath it.
//
// Both live in one centred column so the label is always exactly under the
// +, independent of the neighbouring tab widths (the Row's middle spacer is
// not at the true centre, because "Activities" is wider than "Map").
// The label is in the primary-action orange, sized like the other tab labels,
// with a 7px gap below the button's cream ring. It sits inside the bar, so the
// bar height is unchanged. Tapping the label calls the same onTap as the +.
class _CreateAction extends StatelessWidget {
  const _CreateAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AddButton(onTap: onTap),
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(8, 7, 8, 2),
            child: Text(
              'Create',
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: SynkColors.orangeDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
