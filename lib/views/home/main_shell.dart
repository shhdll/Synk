import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../models/activity_model.dart';
import 'activities_view.dart';
import 'add_activity_view.dart';
import 'home_view.dart';
import 'map_view.dart';
import 'profile_view.dart';

enum HomeTab { profile, map, activities, home }

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = HomeTab.home});

  final HomeTab initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final ActivityStore _activityStore;
  late HomeTab _tab;

  @override
  void initState() {
    super.initState();
    _activityStore = ActivityStore();
    _tab = widget.initialTab;
  }

  @override
  void dispose() {
    _activityStore.dispose();
    super.dispose();
  }

  void _openAddActivity() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddActivityView(activityStore: _activityStore),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stack order (bottom-bar left-to-right, skipping the + slot):
    // Profile, Map, Activities, Home.
    final pages = [
      const ProfileView(),
      const MapView(),
      ActivitiesView(activityStore: _activityStore),
      HomeView(activityStore: _activityStore),
    ];
    final stackIndex = switch (_tab) {
      HomeTab.profile => 0,
      HomeTab.map => 1,
      HomeTab.activities => 2,
      HomeTab.home => 3,
    };

    return Scaffold(
      body: IndexedStack(index: stackIndex, children: pages),
      bottomNavigationBar: _BottomBar(
        selected: _tab,
        onSelect: (tab) => setState(() => _tab = tab),
        onAddTap: _openAddActivity,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
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
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: selected == HomeTab.profile,
                  onTap: () => onSelect(HomeTab.profile),
                ),
                _NavItem(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  selected: selected == HomeTab.map,
                  onTap: () => onSelect(HomeTab.map),
                ),
                // Reserves space for the big + button floating above.
                const SizedBox(width: 56),
                _NavItem(
                  icon: Icons.event_note_rounded,
                  label: 'Activities',
                  selected: selected == HomeTab.activities,
                  onTap: () => onSelect(HomeTab.activities),
                ),
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: selected == HomeTab.home,
                  onTap: () => onSelect(HomeTab.home),
                ),
              ],
            ),
          ),
          Positioned(
            top: -26,
            child: _AddButton(onTap: onAddTap),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? SynkColors.orangeDark : SynkColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        height: 68,
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: SynkColors.background,
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [SynkColors.orange, SynkColors.orangeDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: SynkColors.orange.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
