import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../controllers/friends_controller.dart';
import '../../controllers/notification_center_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activity_model.dart';
import '../../models/notifications_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'activity_join_requests_view.dart';
import 'activity_notification_route.dart';
import 'friend_requests_view.dart';
import 'friends_view.dart';
import 'schedule_conflict_resolution_view.dart';
import 'widgets/synk_filter_chip.dart';

// The list behind the bell: friend requests on top, then notifications
// grouped by Today, Last 7 days and Earlier. Tapping a notification marks it
// read; swiping it toward the start reveals Delete.
class NotificationCenterView extends StatefulWidget {
  const NotificationCenterView({
    super.key,
    required this.controller,
    required this.activityStore,
    this.friends,
  });

  final NotificationCenterController controller;
  final ActivityStore activityStore;

  // Injectable for tests; defaults to the app-wide instance.
  final FriendsController? friends;

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView> {
  NotificationCenterController get _c => widget.controller;
  FriendsController get _friends =>
      widget.friends ?? FriendsController.instance;

  // Friend requests shown here; "See all" opens the rest.
  static const _requestsShown = 2;

  // Notifications per section before "Show more".
  static const _perSection = 6;

  bool _unreadOnly = false;

  // Sections opened with "Show more", by title.
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => Future.wait([_c.refresh(), _friends.refresh()]);

  Future<void> _open(AppNotification notification) async {
    _c.markRead(notification);
    final activityId = notification.activityId;
    switch (notification.kind) {
      case 'join_request_received':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ActivityJoinRequestsView(activityStore: widget.activityStore),
          ),
        );
      case 'friend_request_received':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FriendRequestsView()),
        );
      case 'friend_request_accepted':
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const FriendsView()));
      case 'activity_conflict':
        await showScheduleConflictResolutionDialog(context);
      // The activity is gone, or the user isn't part of it.
      case 'activity_deleted' || 'join_request_rejected':
        return;
      default:
        if (activityId == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ActivityNotificationRoute(activityId: activityId),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      appBar: AppBar(
        backgroundColor: SynkColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SynkColors.textPrimary,
          ),
        ),
        title: Text(
          context.l10n.notifications,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: SynkColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          ListenableBuilder(
            listenable: _c,
            builder: (context, _) => TextButton(
              onPressed: _c.unreadCount == 0 ? null : _c.markAllSeen,
              style: TextButton.styleFrom(
                foregroundColor: SynkColors.orangeDark,
                disabledForegroundColor: SynkColors.textSecondary.withValues(
                  alpha: 0.5,
                ),
                minimumSize: const Size(44, 44),
              ),
              child: Text(
                context.l10n.markAllRead,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([_c, _friends]),
          builder: (context, _) {
            if (_c.isLoading && !_c.hasLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: SynkColors.orangeDark),
              );
            }
            return RefreshIndicator(
              color: SynkColors.orangeDark,
              backgroundColor: Colors.white,
              onRefresh: _refresh,
              child: _buildList(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildList() {
    final requests = _friends.receivedRequests;
    final shown = _unreadOnly
        ? _c.items.where((n) => n.isUnread).toList()
        : _c.items;
    final groups = _groups(shown);

    if (requests.isEmpty && _c.items.isEmpty) return _buildEmpty();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (requests.isNotEmpty) ...[
          FriendRequestsSectionTitle(
            '${context.l10n.friendRequests} · ${requests.length}',
            // Always there: the full list also has the requests sent.
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FriendRequestsView(),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: SynkColors.orangeDark,
                minimumSize: const Size(44, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                context.l10n.seeAll,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          for (final request in requests.take(_requestsShown))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ReceivedRequestCard(request: request),
            ),
          const SizedBox(height: 12),
        ],
        if (_c.items.isNotEmpty) ...[
          _buildFilter(),
          const SizedBox(height: 16),
        ],
        if (_unreadOnly && groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              context.l10n.allCaughtUp,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SynkColors.textSecondary,
              ),
            ),
          ),
        for (final (title, items) in groups) ..._buildSection(title, items),
      ],
    );
  }

  // All or only unread notifications; the requests above always show.
  Widget _buildFilter() {
    final unread = _c.unreadCount;
    return Row(
      children: [
        SynkFilterChip(
          label: context.l10n.all,
          selected: !_unreadOnly,
          onTap: () => setState(() => _unreadOnly = false),
        ),
        const SizedBox(width: 8),
        SynkFilterChip(
          label: unread == 0
              ? context.l10n.notificationsUnread
              : '${context.l10n.notificationsUnread} · $unread',
          selected: _unreadOnly,
          onTap: () => setState(() => _unreadOnly = true),
        ),
      ],
    );
  }

  List<Widget> _buildSection(String title, List<AppNotification> items) {
    final expanded = _expanded.contains(title);
    final hidden = items.length - _perSection;
    final visible = expanded || hidden <= 0 ? items : items.take(_perSection);

    return [
      FriendRequestsSectionTitle(title),
      for (final notification in visible)
        Padding(
          key: ValueKey(notification.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: _SwipeToDelete(
            id: notification.id,
            deleteLabel: context.l10n.delete,
            onDelete: () => _delete(notification),
            child: _NotificationTile(
              notification: notification,
              onTap: () => _open(notification),
              onMarkRead: () => _c.markRead(notification),
            ),
          ),
        ),
      if (hidden > 0)
        Center(
          child: TextButton(
            onPressed: () => setState(
              () => expanded ? _expanded.remove(title) : _expanded.add(title),
            ),
            style: TextButton.styleFrom(
              foregroundColor: SynkColors.orangeDark,
              minimumSize: const Size(44, 44),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  expanded
                      ? context.l10n.showLess
                      : context.l10n.showMoreCount(hidden),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
    ];
  }

  void _delete(AppNotification notification) {
    _c.delete(notification);
    SynkFeedback.showToast(context, title: context.l10n.notificationDeleted);
  }

  // Today, Last 7 days and Earlier, newest first; empty groups are left out.
  List<(String, List<AppNotification>)> _groups(List<AppNotification> items) {
    final today = DateUtils.dateOnly(DateTime.now());
    final weekAgo = today.subtract(const Duration(days: 7));
    final todays = <AppNotification>[];
    final lastWeek = <AppNotification>[];
    final earlier = <AppNotification>[];
    for (final n in items) {
      final day = DateUtils.dateOnly(n.createdAt);
      if (!day.isBefore(today)) {
        todays.add(n);
      } else if (!day.isBefore(weekAgo)) {
        lastWeek.add(n);
      } else {
        earlier.add(n);
      }
    }
    return [
      if (todays.isNotEmpty) (context.l10n.today, todays),
      if (lastWeek.isNotEmpty) (context.l10n.notificationsLast7Days, lastWeek),
      if (earlier.isNotEmpty) (context.l10n.notificationsEarlier, earlier),
    ];
  }

  Widget _buildEmpty() {
    final failed = _c.error != null && !_c.hasLoaded;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0x1FFF7A36),
              shape: BoxShape.circle,
            ),
            child: Icon(
              failed
                  ? Icons.cloud_off_rounded
                  : Icons.notifications_none_rounded,
              size: 30,
              color: SynkColors.orangeDark,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          failed
              ? context.l10n.couldntLoadNotifications
              : context.l10n.noNotificationsYet,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
        if (!failed) ...[
          const SizedBox(height: 6),
          Text(
            context.l10n.noNotificationsHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: SynkColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onMarkRead,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  // The unread dot is a button that marks it read without opening it.
  final VoidCallback onMarkRead;

  // Icon and message for each kind of notification.
  (IconData, String Function(String)) _style(BuildContext context) {
    final l = context.l10n;
    return switch (notification.kind) {
      'waitlist_promotion' => (
        Icons.celebration_rounded,
        l.notifWaitlistPromotion,
      ),
      'activity_updated' => (
        Icons.edit_calendar_rounded,
        l.notifActivityUpdated,
      ),
      'activity_deleted' => (Icons.event_busy_rounded, l.notifActivityDeleted),
      'join_request_accepted' => (
        Icons.check_circle_rounded,
        l.notifRequestAccepted,
      ),
      'join_request_rejected' => (Icons.cancel_rounded, l.notifRequestRejected),
      'join_request_received' => (
        Icons.person_add_alt_1_rounded,
        l.notifRequestReceived,
      ),
      'host_assigned' => (Icons.workspace_premium_rounded, l.notifHostAssigned),
      'activity_full' => (Icons.groups_rounded, l.notifActivityFull),
      'friend_request_received' => (
        Icons.person_add_alt_1_rounded,
        l.notifFriendRequestReceived,
      ),
      'friend_request_accepted' => (
        Icons.people_alt_rounded,
        l.notifFriendRequestAccepted,
      ),
      _ => (Icons.warning_amber_rounded, l.notifActivityConflict),
    };
  }

  String _timeAgo(BuildContext context) {
    final ago = DateTime.now().difference(notification.createdAt);
    if (ago.inMinutes < 1) return context.l10n.justNow;
    if (ago.inHours < 1) return context.l10n.minutesAgo(ago.inMinutes);
    if (ago.inDays < 1) return context.l10n.hoursAgo(ago.inHours);
    if (ago.inDays < 7) return context.l10n.daysAgo(ago.inDays);
    return formatShortDate(notification.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final (icon, message) = _style(context);
    final unread = notification.isUnread;

    // Bold title inside the translated sentence.
    const marker = '\u0000';
    final parts = message(marker).split(marker);

    return Material(
      color: unread ? const Color(0xFFFFF1E8) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0x1FFF7A36),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: SynkColors.orangeDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: SynkColors.textPrimary,
                        ),
                        children: [
                          TextSpan(text: parts.first),
                          TextSpan(
                            text: notification.activityTitle,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (parts.length > 1)
                            TextSpan(text: parts.sublist(1).join()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(context),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                        color: unread
                            ? SynkColors.orangeDark
                            : SynkColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                // 44px target around the dot, pulled in so the row keeps
                // its size.
                Transform.translate(
                  offset: Offset(
                    Directionality.of(context) == TextDirection.rtl ? -10 : 10,
                    -10,
                  ),
                  child: IconButton(
                    tooltip: context.l10n.markAsRead,
                    onPressed: onMarkRead,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: SynkColors.orangeDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Swipe the row toward the start (left, or right in Arabic) to delete it.
// A red Delete shows behind the row as it slides away.
class _SwipeToDelete extends StatelessWidget {
  const _SwipeToDelete({
    required this.id,
    required this.child,
    required this.onDelete,
    required this.deleteLabel,
  });

  final String id;
  final Widget child;
  final VoidCallback onDelete;
  final String deleteLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: deleteLabel): onDelete,
      },
      // Keeps the sliding row inside its own rounded box.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Dismissible(
          key: ValueKey('dismiss-$id'),
          direction: DismissDirection.endToStart,
          dismissThresholds: const {DismissDirection.endToStart: 0.35},
          onDismissed: (_) => onDelete(),
          background: Container(
            padding: const EdgeInsetsDirectional.only(end: 24),
            alignment: AlignmentDirectional.centerEnd,
            decoration: BoxDecoration(
              color: SynkColors.badge,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(height: 2),
                Text(
                  deleteLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
