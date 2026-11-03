import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/home_tab.dart';
import 'add_button.dart';
import 'nav_item.dart';

// The pill-shaped bottom navigation bar with the floating + in the middle,
// shown by MainShell.
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onAddTap,
    this.activitiesBadge = 0,
    this.chatBadge = 0,
  });

  final HomeTab selected;
  final ValueChanged<HomeTab> onSelect;
  final VoidCallback onAddTap;
  final int activitiesBadge;
  final int chatBadge;

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
                    // Room for the + floating above.
                    const SizedBox(width: 60),
                    NavItem(
                      icon: Icons.map_rounded,
                      label: context.l10n.map,
                      selected: selected == HomeTab.map,
                      onTap: () => onSelect(HomeTab.map),
                    ),
                    NavItem(
                      icon: Icons.sms_outlined,
                      iconSize: 28,
                      label: context.l10n.chat,
                      selected: selected == HomeTab.chat,
                      badgeCount: chatBadge,
                      onTap: () => onSelect(HomeTab.chat),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(top: -28, child: AddButton(onTap: onAddTap)),
      ],
    );
  }
}
