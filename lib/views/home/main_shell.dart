import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/friends_controller.dart';
import '../../controllers/home_discovery_controller.dart';
import '../../controllers/notification_center_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/activity_participation_model.dart';
import '../../models/auth_model.dart';
import '../../models/home_tab.dart';
import '../../services/push_notification_service.dart';
import '../create_activity/create_activity_view.dart';
import 'activities_view.dart';
import 'chats_view.dart';
import 'home_view.dart';
import 'map_view.dart';
import 'schedule_conflict_resolution_view.dart';
import 'widgets/bottom_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = HomeTab.home});

  final HomeTab initialTab;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  final ActivitiesModel _activitiesModel = ActivitiesModel();
  final ActivityParticipationModel _participationModel =
      ActivityParticipationModel();
  final AuthModel _authModel = AuthModel();

  // Poll for new join requests while the app is open.
  static const _requestPollInterval = Duration(minutes: 1);
  Timer? _requestPoll;
  bool _checkingScheduleConflicts = false;

  late final HomeDiscoveryController _discoveryController =
      HomeDiscoveryController(activitiesModel: _activitiesModel);

  late final ActivityStore _activityStore;
  late HomeTab _tab;

  final NotificationCenterController _notifications =
      NotificationCenterController();

  @override
  void initState() {
    super.initState();

    _activityStore = ActivityStore();

    // Defines which hosted activities belong to the signed-in user.
    _activityStore.currentUserId =
        Supabase.instance.client.auth.currentUser?.id;
    PushNotificationService.instance.setActivityUpdatedHandler(
      _refreshActivity,
    );
    // A push while the app is open adds to the list straight away.
    PushNotificationService.instance.setMessageReceivedHandler(
      () => unawaited(_notifications.refresh()),
    );
    unawaited(_notifications.refresh());
    unawaited(FriendsController.instance.refresh());
    unawaited(ChatController.instance.refresh());

    _tab = widget.initialTab;
    _activityStore.addListener(_openMapForFocus);

    unawaited(PushNotificationService.instance.registerForCurrentUser());
    unawaited(_authModel.refreshIfEmailChangePending());

    // Loads hosted, participating, and public activities.
    _loadActivities();

    WidgetsBinding.instance.addObserver(this);
    _requestPoll = Timer.periodic(
      _requestPollInterval,
      (_) {
        _loadPendingRequestCount();
        unawaited(_requireScheduleConflictResolution());
        unawaited(_notifications.refresh());
        unawaited(FriendsController.instance.refresh());
        unawaited(ChatController.instance.refresh());
      },
    );
  }

  void _openMapForFocus() {
    if (_activityStore.mapFocus != null && _tab != HomeTab.map) {
      setState(() => _tab = HomeTab.map);
    }
    if (_activityStore.detailsFocus != null && _tab != HomeTab.activities) {
      setState(() => _tab = HomeTab.activities);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadActivities());
      unawaited(_discoveryController.loadFeed(isSilent: true));
      _loadPendingRequestCount();
      unawaited(_notifications.refresh());
      unawaited(FriendsController.instance.refresh());
      unawaited(ChatController.instance.refresh());
      unawaited(PushNotificationService.instance.registerForCurrentUser());
      // Picks up an email change confirmed in the browser.
      unawaited(_authModel.refreshIfEmailChangePending());
    }
  }

  void _refreshActivity(String activityId) {
    unawaited(() async {
      try {
        final activity = await _activitiesModel.fetchById(activityId);
        if (mounted && activity != null) {
          final previous = _activityStore.byId(activityId);
          _activityStore.upsert(
            previous == null
                ? activity
                : activity.copyWith(
                    hostName: previous.hostName,
                    hostUsername: previous.hostUsername,
                    hostAvatarUrl: previous.hostAvatarUrl,
                    hostGender: previous.hostGender,
                    participantsCount: previous.participantsCount,
                    activityCode: previous.activityCode,
                    participationId: previous.participationId,
                    participationStatus: previous.participationStatus,
                  ),
          );
        }
      } catch (_) {
        // Keep the current activity visible when a refresh fails.
      }
      await _loadActivities();
    }());
  }

  Future<void> _loadActivities() async {
    await Future.wait([
      _loadMyActivities(),
      _loadParticipatingActivities(),
      _loadPublicFeed(),
      _loadPendingRequestCount(),
    ]);
    await _requireScheduleConflictResolution();
  }

  Future<void> _requireScheduleConflictResolution() async {
    if (_checkingScheduleConflicts || !mounted) return;
    _checkingScheduleConflicts = true;
    try {
      final conflicts = await _activitiesModel.fetchScheduleConflicts();
      if (conflicts.isNotEmpty && mounted) {
        await showScheduleConflictResolutionDialog(context);
      }
    } catch (_) {
      // A failed conflict lookup should not prevent the rest of the app loading.
    } finally {
      _checkingScheduleConflicts = false;
    }
  }

  Future<void> _loadPendingRequestCount() async {
    try {
      final count = await _participationModel.countPendingRequests();
      if (!mounted) return;
      _activityStore.pendingRequestCount = count;
    } catch (_) {}
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
      final activities = await _activitiesModel.fetchParticipating();

      if (!mounted) return;

      _activityStore.setParticipating(activities);
    } catch (_) {
      // Keep the current list when loading fails.
    }
  }

  // Loads upcoming public activities for the Home feed.
  Future<void> _loadPublicFeed() async {
    try {
      final activities = await _activitiesModel.fetchPublicFeed();

      if (!mounted) return;

      _activityStore.setFeed(activities);
    } catch (_) {
      // Keep the current list when loading fails.
    }
  }

  @override
  void dispose() {
    _requestPoll?.cancel();
    PushNotificationService.instance.setActivityUpdatedHandler(null);
    PushNotificationService.instance.setMessageReceivedHandler(null);
    _notifications.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _activityStore.removeListener(_openMapForFocus);
    _activityStore.dispose();
    _discoveryController.dispose();
    super.dispose();
  }

  Future<void> _openAddActivity() async {
    final outcome = await Navigator.of(context).push<CreateActivityOutcome>(
      MaterialPageRoute(
        builder: (context) {
          return CreateActivityView(store: _activityStore);
        },
        fullscreenDialog: true,
      ),
    );

    // Show the new activity straight away in My Activities.
    if (outcome != null && mounted) {
      _activityStore.showInActivities(outcome.activity);
    }

    // Refresh activities after returning from Create Activity.
    await Future.wait([
      _loadActivities(),
      _discoveryController.loadFeed(isSilent: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChatsView(activityStore: _activityStore),
      MapView(
        activityStore: _activityStore,
        discoveryController: _discoveryController,
        isActive: _tab == HomeTab.map,
      ),
      ActivitiesView(activityStore: _activityStore),
      HomeView(
        activityStore: _activityStore,
        discoveryController: _discoveryController,
        onCreateActivity: _openAddActivity,
        notifications: _notifications,
      ),
    ];

    final stackIndex = switch (_tab) {
      HomeTab.chat => 0,
      HomeTab.map => 1,
      HomeTab.activities => 2,
      HomeTab.home => 3,
    };

    return Scaffold(
      backgroundColor: SynkColors.background,
      extendBody: true,
      body: IndexedStack(index: stackIndex, children: pages),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge([_activityStore, ChatController.instance]),
        builder: (context, _) => BottomBar(
          selected: _tab,
          onSelect: (tab) {
            setState(() => _tab = tab);
            if (tab == HomeTab.activities) _loadPendingRequestCount();
            if (tab == HomeTab.chat) {
              unawaited(ChatController.instance.refresh());
            }
          },
          onAddTap: _openAddActivity,
          activitiesBadge: _activityStore.pendingRequestCount,
          chatBadge: ChatController.instance.unreadChatCount,
        ),
      ),
    );
  }
}
