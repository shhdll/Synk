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

  // True when arriving straight from registration, so the Home tab's
  // greeting reads as a first hello rather than a returning-user welcome.
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
    // The store starts empty; ownership checks (used by upsert() when a new
    // activity is created) need to know who "mine" means before anything
    // else touches the store.
    _activityStore.currentUserId =
        Supabase.instance.client.auth.currentUser?.id;
    _tab = widget.initialTab;
    _loadMyActivities();
    _loadPublicFeed();
  }

  // Populates the store with the signed-in user's existing activities from
  // Supabase, so Activities/Home show past data on a fresh launch rather
  // than only activities created in the current session (upsert() alone
  // never backfills prior rows). Best-effort: a failed fetch (offline, RLS,
  // etc.) leaves the store as-is rather than surfacing an error here — the
  // tabs just show whatever they already have, same as any other transient
  // network hiccup elsewhere in the app.
  Future<void> _loadMyActivities() async {
    try {
      final mine = await _activitiesModel.fetchMine();
      if (!mounted) return;
      _activityStore.setMine(mine);
    } catch (_) {
      // Swallowed intentionally — see method comment.
    }
  }

  // Populates the Home feed with upcoming public activities from every user.
  // Same best-effort handling as _loadMyActivities(): a failed fetch leaves
  // the feed as-is.
  Future<void> _loadPublicFeed() async {
    try {
      final feed = await _activitiesModel.fetchPublicFeed();
      if (!mounted) return;
      _activityStore.setFeed(feed);
    } catch (_) {
      // Swallowed intentionally — see method comment.
    }
  }

  @override
  void dispose() {
    _activityStore.dispose();
    super.dispose();
  }

  void _openAddActivity() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateActivityView(store: _activityStore),
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
      backgroundColor: SynkColors.background,
      extendBody: true,
      body: IndexedStack(index: stackIndex, children: pages),
      bottomNavigationBar: BottomBar(
        selected: _tab,
        onSelect: (tab) => setState(() => _tab = tab),
        onAddTap: _openAddActivity,
      ),
    );
  }
}
