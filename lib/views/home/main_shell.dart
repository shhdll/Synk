import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/friends_controller.dart';
import '../../controllers/home_discovery_controller.dart';
import '../../controllers/notification_center_controller.dart';
import '../../controllers/notification_preferences_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/activity_participation_model.dart';
import '../../models/activity_rating_model.dart';
import '../../models/auth_model.dart';
import '../../models/home_tab.dart';
import '../../models/streak_intro.dart';
import '../../models/telegram_intro.dart';
import '../../services/push_notification_service.dart';
import '../create_activity/create_activity_view.dart';
import 'activities_view.dart';
import 'chats_view.dart';
import 'home_view.dart';
import 'map_view.dart';
import 'schedule_conflict_resolution_view.dart';
import 'widgets/activity_rating_sheet.dart';
import 'widgets/bottom_bar.dart';
import 'widgets/streak_widgets.dart';
import 'widgets/telegram_connect.dart';
import '../welcome_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = HomeTab.home});

  final HomeTab initialTab;

  // Pull to refresh in the tabs also checks that the account wasn't
  // suspended or deleted, so the user is sent out right away.
  static Future<void> checkAccount() => _accountCheck?.call() ?? Future.value();
  static Future<void> Function()? _accountCheck;

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

  final ActivityRatingModel _ratingModel = ActivityRatingModel();
  // At most one rating prompt per app opening or resume.
  bool _ratingOffered = false;
  bool _offeringRating = false;

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
    FriendsController.instance.onBlocksChanged = _reloadAfterBlockChange;
    unawaited(_notifications.refresh());
    unawaited(FriendsController.instance.refresh());
    unawaited(ChatController.instance.refresh());

    _tab = widget.initialTab;
    _activityStore.addListener(_openMapForFocus);

    unawaited(PushNotificationService.instance.registerForCurrentUser());
    unawaited(_authModel.refreshIfEmailChangePending());
    MainShell._accountCheck = _leaveIfAccountGone;
    unawaited(_leaveIfAccountGone());

    // Loads hosted, participating, and public activities once, then shows
    // the opening pop-ups one after another.
    unawaited(_loadActivities().then((_) => _showOpeningPopups()));

    WidgetsBinding.instance.addObserver(this);
    _requestPoll = Timer.periodic(_requestPollInterval, (_) {
      _loadPendingRequestCount();
      unawaited(_leaveIfAccountGone());
      unawaited(_requireScheduleConflictResolution());
      unawaited(_notifications.refresh());
      unawaited(FriendsController.instance.refresh());
      unawaited(ChatController.instance.refresh());
    });
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
      _ratingOffered = false;
      unawaited(_loadActivities().then((_) => _offerActivityRating()));
      unawaited(_discoveryController.loadFeed(isSilent: true));
      _loadPendingRequestCount();
      unawaited(_notifications.refresh());
      unawaited(FriendsController.instance.refresh());
      unawaited(ChatController.instance.refresh());
      unawaited(PushNotificationService.instance.registerForCurrentUser());
      // Picks up an email change confirmed in the browser.
      unawaited(_authModel.refreshIfEmailChangePending());
      unawaited(_leaveIfAccountGone());
    }
  }

  // The account was deleted or suspended: back to the welcome screen, the
  // same way Log out does it.
  Future<void> _leaveIfAccountGone() async {
    if (!await _authModel.signOutIfAccountGone() || !mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeView()),
      (route) => false,
    );
  }

  // After a block or unblock: the lists and chats the server changed, so
  // an activity the user was taken out of doesn't stay on screen.
  void _reloadAfterBlockChange() {
    if (!mounted) return;
    unawaited(_loadActivities());
    unawaited(_discoveryController.loadFeed(isSilent: true));
    unawaited(ChatController.instance.refresh());
  }

  void _refreshActivity(String activityId) {
    unawaited(() async {
      try {
        final activity = await _activitiesModel.fetchById(activityId);
        // Deleted, or no longer visible to this user.
        if (mounted && activity == null) _activityStore.removeById(activityId);
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

  // Set once each list has loaded, so the streak is never shown from
  // half-loaded data.
  bool _mineLoaded = false;
  bool _participatingLoaded = false;

  // The streak greeting first, then a rating offer once it is closed, so
  // the two sheets never stack.
  Future<void> _showOpeningPopups() async {
    await _offerTelegram();
    await _showStreakOnOpen();
    await _offerActivityRating();
  }

  // iPhones have no native push, so offer Telegram once for each account on
  // the device. Skipped if they already have it.
  Future<void> _offerTelegram() async {
    if (!Platform.isIOS || !mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final controller = NotificationPreferencesController();
    try {
      await controller.load();
      if (controller.loadFailed) return;
      if (controller.telegramLinked) return;
      if (!await TelegramIntro.takeTurn(_activityStore.currentUserId)) return;
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      await showTelegramPrompt(context, controller);
    } finally {
      controller.dispose();
    }
  }

  // Pops up the streak sheet once a day when the app opens. Skipped, without
  // using up the day's turn, while another screen, sheet or dialog is open.
  Future<void> _showStreakOnOpen() async {
    if (!mounted || !_mineLoaded || !_participatingLoaded) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (!await StreakIntro.takeTurn(_activityStore.currentUserId)) return;
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    await showStreakSheet(context, _activityStore);
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

  // Offers one ended activity to rate, after activities and any schedule
  // conflict prompt have loaded. Never covers another screen or sheet.
  Future<void> _offerActivityRating() async {
    if (_ratingOffered || _offeringRating || !mounted) return;
    _offeringRating = true;
    try {
      final pending = await _ratingModel.fetchPending();
      if (pending.isEmpty || !mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;

      _ratingOffered = true;
      await showActivityRatingSheet(context: context, pending: pending.first);
    } catch (_) {
      // Rating is optional; a failed lookup is retried on the next opening.
    } finally {
      _offeringRating = false;
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
      _mineLoaded = true;
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
      _participatingLoaded = true;
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
    if (MainShell._accountCheck == _leaveIfAccountGone) {
      MainShell._accountCheck = null;
    }
    _requestPoll?.cancel();
    PushNotificationService.instance.setActivityUpdatedHandler(null);
    PushNotificationService.instance.setMessageReceivedHandler(null);
    if (FriendsController.instance.onBlocksChanged == _reloadAfterBlockChange) {
      FriendsController.instance.onBlocksChanged = null;
    }
    _notifications.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _activityStore.removeListener(_openMapForFocus);
    _activityStore.dispose();
    _discoveryController.dispose();
    super.dispose();
  }

  Future<void> _openAddActivity([String? title]) async {
    final outcome = await Navigator.of(context).push<CreateActivityOutcome>(
      MaterialPageRoute(
        builder: (context) {
          return CreateActivityView(store: _activityStore, initialTitle: title);
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
            unawaited(_leaveIfAccountGone());
            if (tab == HomeTab.activities) {
              _loadPendingRequestCount();
              // Drops activities deleted since the last load.
              unawaited(_loadMyActivities());
              unawaited(_loadParticipatingActivities());
            }
            if (tab == HomeTab.chat) {
              unawaited(ChatController.instance.refresh());
            }
          },
          onAddTap: () => _openAddActivity(),
          activitiesBadge: _activityStore.pendingRequestCount,
          chatBadge: ChatController.instance.unreadChatCount,
        ),
      ),
    );
  }
}
