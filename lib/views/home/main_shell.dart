import 'package:flutter/material.dart';

import '../../models/activity_model.dart';
import '../../models/home_tab.dart';
import 'activities_view.dart';
import 'add_activity_view.dart';
import 'home_view.dart';
import 'map_view.dart';
import 'profile_view.dart';
import 'widgets/bottom_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.initialTab = HomeTab.home,
    this.isNewUser = false,
  });

  final HomeTab initialTab;

  // True when arriving straight from registration, so the Home tab's
  // greeting reads as a first hello rather than a returning-user welcome.
  final bool isNewUser;

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
        builder: (context) => const AddActivityView(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stack order (bottom-bar right-to-left, skipping the + slot):
    // Profile, Map, Activities, Home.
    final pages = [
      const ProfileView(),
      const MapView(),
      ActivitiesView(activityStore: _activityStore),
      HomeView(activityStore: _activityStore, isNewUser: widget.isNewUser),
    ];
    final stackIndex = switch (_tab) {
      HomeTab.profile => 0,
      HomeTab.map => 1,
      HomeTab.activities => 2,
      HomeTab.home => 3,
    };

    return Scaffold(
      body: IndexedStack(index: stackIndex, children: pages),
      bottomNavigationBar: BottomBar(
        selected: _tab,
        onSelect: (tab) => setState(() => _tab = tab),
        onAddTap: _openAddActivity,
      ),
    );
  }
}
