import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/synk_colors.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/home_tab.dart';
import '../create_activity/create_activity_view.dart';
import 'activities_view.dart';
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
  final bool isNewUser;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final ActivitiesModel _activitiesModel = ActivitiesModel();

  late final ActivityStore _activityStore;
  late HomeTab _tab;

  @override
  void initState() {
    super.initState();

    _activityStore = ActivityStore();

    // Defines which hosted activities belong to the signed-in user.
    _activityStore.currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    _tab = widget.initialTab;

    // Loads hosted, participating, and public activities.
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    await Future.wait([
      _loadMyActivities(),
      _loadParticipatingActivities(),
      _loadPublicFeed(),
    ]);
  }

  // Loads activities created by the signed-in user.
  Future<void> _loadMyActivities() async {
    try {
      final activities = await _activitiesModel.fetchMine();

      if (!mounted) return;

      _activityStore.setMine(activities);
    } catch (_) {
      // Keep the current list when loading fails.
    }
  }

  // Loads joined, pending, and waitlisted activities.
  Future<void> _loadParticipatingActivities() async {
    try {
      final activities =
          await _activitiesModel.fetchParticipating();

      if (!mounted) return;

      _activityStore.setParticipating(activities);
    } catch (_) {
      // Keep the current list when loading fails.
    }
  }

  // Loads upcoming public activities for the Home feed.
  Future<void> _loadPublicFeed() async {
    try {
      final activities =
          await _activitiesModel.fetchPublicFeed();

      if (!mounted) return;

      _activityStore.setFeed(activities);
    } catch (_) {
      // Keep the current list when loading fails.
    }
  }

  @override
  void dispose() {
    _activityStore.dispose();
    super.dispose();
  }

  Future<void> _openAddActivity() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return CreateActivityView(
            store: _activityStore,
          );
        },
        fullscreenDialog: true,
      ),
    );

    // Refresh activities after returning from Create Activity.
    await _loadActivities();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProfileView(activityStore: _activityStore),
       MapView( activityStore: _activityStore,
  isActive: _tab == HomeTab.map,),
      ActivitiesView(activityStore: _activityStore),
      HomeView(
        activityStore: _activityStore,
        isNewUser: widget.isNewUser,
      ),
    ];

    final stackIndex = switch (_tab) {
      HomeTab.profile => 0,
      HomeTab.map => 1,
      HomeTab.activities => 2,
      HomeTab.home => 3,
    };

    return Scaffold(
      backgroundColor: SynkColors.background,
      extendBody: true,
      body: IndexedStack(
        index: stackIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomBar(
        selected: _tab,
        onSelect: (tab) {
          setState(() => _tab = tab);
        },
        onAddTap: _openAddActivity,
      ),
    );
  }
}