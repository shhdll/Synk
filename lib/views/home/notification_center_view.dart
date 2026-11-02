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
import 'notification_settings_view.dart';
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

  static const _requestsKey = 'requests';
  static const _earlierKey = 'earlier';

  bool _unreadOnly = false;

  // Folded sections. Earlier starts folded.
  final Set<String> _collapsed = {_earlierKey};

  // Sections opened with "Show more".
  final Set<String> _showAll = {};

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
          IconButton(
            tooltip: context.l10n.notificationSettings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsView(),
              ),
            ),
            icon: const Icon(
              Icons.settings_outlined,
              color: SynkColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        if (_c.items.isNotEmpty) ...[
          _buildFilter(),
          const SizedBox(height: 18),
        ],
        if (requests.isNotEmpty)
          _FoldableSection(
            title: context.l10n.friendRequests,
            count: requests.length,
            expanded: !_collapsed.contains(_requestsKey),
            onToggle: () => _toggle(_requestsKey),
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
            child: Column(
              children: [
                for (final request in requests.take(_requestsShown))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ReceivedRequestCard(request: request),
                  ),
              ],
            ),
          ),
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
        for (final (key, title, items) in groups)
          _buildSection(key, title, items),
      ],
    );
  }

  void _toggle(String key) => setState(
    () => _collapsed.contains(key)
        ? _collapsed.remove(key)
        : _collapsed.add(key),
  );

  // All or only unread notifications, with "Mark all read" at the end.
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
        const Spacer(),
        TextButton(
          onPressed: unread == 0 ? null : _c.markAllSeen,
          style: TextButton.styleFrom(
            foregroundColor: SynkColors.orangeDark,
            disabledForegroundColor: SynkColors.textSecondary.withValues(
              alpha: 0.5,
            ),
            minimumSize: const Size(44, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(
            context.l10n.markAllRead,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String key, String title, List<AppNotification> items) {
    final showAll = _showAll.contains(key);
    final hidden = items.length - _perSection;
    final visible = showAll || hidden <= 0
        ? items
        : items.take(_perSection).toList();

    final rows = <Widget>[];
    for (var i = 0; i < visible.length; i++) {
      final notification = visible[i];
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 66,
            color: SynkColors.textSecondary.withValues(alpha: 0.10),
          ),
        );
      }
      rows.add(
        _SwipeToDelete(
          key: ValueKey(notification.id),
          id: notification.id,
          deleteLabel: context.l10n.delete,
          onDelete: () => _delete(notification),
          child: _NotificationTile(
            notification: notification,
            onTap: () => _open(notification),
            onMarkRead: () => _c.markRead(notification),
          ),
        ),
      );
    }

    return _FoldableSection(
      title: title,
      count: items.length,
      expanded: !_collapsed.contains(key),
      onToggle: () => _toggle(key),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: SynkColors.textSecondary.withValues(alpha: 0.10),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(children: rows),
          ),
          if (hidden > 0)
            TextButton(
              onPressed: () => setState(
                () => showAll ? _showAll.remove(key) : _showAll.add(key),
              ),
              style: TextButton.styleFrom(
                foregroundColor: SynkColors.orangeDark,
                minimumSize: const Size(44, 44),
              ),
              child: Text(
                showAll
                    ? context.l10n.showLess
                    : context.l10n.showMoreCount(hidden),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }

  void _delete(AppNotification notification) {
    _c.delete(notification);
    SynkFeedback.showToast(context, title: context.l10n.notificationDeleted);
  }

  // Today, Last 7 days and Earlier, newest first; empty groups are left out.
  List<(String, String, List<AppNotification>)> _groups(
    List<AppNotification> items,
  ) {
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
      if (todays.isNotEmpty) ('today', context.l10n.today, todays),
      if (lastWeek.isNotEmpty)
        ('week', context.l10n.notificationsLast7Days, lastWeek),
      if (earlier.isNotEmpty)
        (_earlierKey, context.l10n.notificationsEarlier, earlier),
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

// A section title that folds its content away when tapped.
class _FoldableSection extends StatelessWidget {
  const _FoldableSection({
    required this.title,
    required this.count,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.trailing,
  });

  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 0, 10),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SynkColors.textSecondary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (expanded && trailing != null) trailing!,
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? child
              : const SizedBox(width: double.infinity, height: 8),
        ),
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

  // Icon, colour and message for each kind of notification.
  (IconData, Color, String Function(String)) _style(BuildContext context) {
    final l = context.l10n;
    return switch (notification.kind) {
      'waitlist_promotion' => (
        Icons.celebration_rounded,
        SynkColors.orangeDark,
        l.notifWaitlistPromotion,
      ),
      'activity_updated' => (
        Icons.edit_calendar_rounded,
        SynkColors.teal,
        l.notifActivityUpdated,
      ),
      'activity_deleted' => (
        Icons.event_busy_rounded,
        SynkColors.badge,
        l.notifActivityDeleted,
      ),
      'join_request_accepted' => (
        Icons.check_circle_rounded,
        SynkColors.teal,
        l.notifRequestAccepted,
      ),
      'join_request_rejected' => (
        Icons.cancel_rounded,
        SynkColors.badge,
        l.notifRequestRejected,
      ),
      'join_request_received' => (
        Icons.person_add_alt_1_rounded,
        SynkColors.orangeDark,
        l.notifRequestReceived,
      ),
      'host_assigned' => (
        Icons.workspace_premium_rounded,
        SynkColors.beigeDark,
        l.notifHostAssigned,
      ),
      'activity_full' => (
        Icons.groups_rounded,
        SynkColors.teal,
        l.notifActivityFull,
      ),
      'activity_reminder' => (
        Icons.alarm_rounded,
        SynkColors.orangeDark,
        l.notifActivityReminder,
      ),
      'friend_request_received' => (
        Icons.person_add_alt_1_rounded,
        SynkColors.pink,
        l.notifFriendRequestReceived,
      ),
      'friend_request_accepted' => (
        Icons.people_alt_rounded,
        SynkColors.pink,
        l.notifFriendRequestAccepted,
      ),
      'activity_conflict' => (
        Icons.warning_amber_rounded,
        SynkColors.orangeDeep,
        l.notifActivityConflict,
      ),
      _ => (
        Icons.notifications_none_rounded,
        SynkColors.textSecondary,
        l.notifActivityUpdated,
      ),
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
    final (icon, color, message) = _style(context);
    final unread = notification.isUnread;

    // Bold title inside the translated sentence.
    const marker = '\u0000';
    final parts = message(marker).split(marker);

    return Material(
      color: unread
          ? SynkColors.orange.withValues(alpha: 0.07)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 14),
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
                              ? FontWeight.w600
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
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: unread
                            ? SynkColors.orangeDark
                            : SynkColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Same width read or unread, so text doesn't shift.
              SizedBox(
                width: 36,
                height: 36,
                child: unread
                    ? IconButton(
                        tooltip: context.l10n.markAsRead,
                        onPressed: onMarkRead,
                        padding: EdgeInsets.zero,
                        icon: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: SynkColors.orangeDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
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
    super.key,
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
      child: Dismissible(
        key: ValueKey('dismiss-$id'),
        direction: DismissDirection.endToStart,
        dismissThresholds: const {DismissDirection.endToStart: 0.35},
        onDismissed: (_) => onDelete(),
        background: Container(
          padding: const EdgeInsetsDirectional.only(end: 24),
          alignment: AlignmentDirectional.centerEnd,
          color: SynkColors.badge,
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
    );
  }
}
