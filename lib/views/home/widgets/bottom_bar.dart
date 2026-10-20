import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
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
    this.activitiesBadge = 0,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;
  final VoidCallback onAddTap;
  final int activitiesBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Fades the page out behind the bar, so cards don't run into it.
        // Stops below the "Have a code?" bubble, which sits above the bar.
        Positioned(
          left: 0,
          right: 0,
          top: -36,
          bottom: 0,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    SynkColors.background.withValues(alpha: 0),
                    SynkColors.background.withValues(alpha: 0.85),
                    SynkColors.background,
                  ],
                  stops: const [0, 0.5, 0.85],
                ),
              ),
            ),
          ),
        ),
        SafeArea(top: false, child: _buildBar(context)),
      ],
    );
  }

  Widget _buildBar(BuildContext context) {
    final radius = BorderRadius.circular(24);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          // Frosted glass: whatever is still behind the bar is blurred.
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  borderRadius: radius,
                  border: Border.all(
                    color: SynkColors.textSecondary.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    NavItem(
                      icon: Icons.home_rounded,
                      label: context.l10n.home,
                      selected: selected == HomeTab.home,
                      onTap: () => onSelect(HomeTab.home),
                    ),
                    NavItem(
                      icon: Icons.event_note_rounded,
                      label: context.l10n.activities,
                      selected: selected == HomeTab.activities,
                      badgeCount: activitiesBadge,
                      onTap: () => onSelect(HomeTab.activities),
                    ),
                    // Reserves space for the big + button floating above.
                    const SizedBox(width: 56),
                    NavItem(
                      icon: Icons.map_rounded,
                      label: context.l10n.map,
                      selected: selected == HomeTab.map,
                      onTap: () => onSelect(HomeTab.map),
                    ),
                    NavItem(
                      icon: Icons.person_rounded,
                      label: context.l10n.profile,
                      selected: selected == HomeTab.profile,
                      onTap: () => onSelect(HomeTab.profile),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(top: -30, child: _CreateAction(onTap: onAddTap)),
      ],
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
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 7, 8, 2),
            child: Text(
              context.l10n.create,
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
