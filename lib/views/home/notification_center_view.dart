import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../controllers/friends_controller.dart';
import '../../controllers/notification_center_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activity_model.dart';
import '../../models/activity_participation_model.dart';
import '../../models/notifications_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'activity_join_requests_view.dart';
import 'activity_notification_route.dart';
import 'friend_requests_view.dart';
import 'friends_view.dart';
import 'notification_settings_view.dart';
import 'schedule_conflict_resolution_view.dart';
import 'widgets/activity_thumbnail.dart';
import 'main_shell.dart';

// The list behind the bell: friend requests on top, then notifications in
// New, Today, Yesterday, This week and Earlier. Opening it marks everything
// read; what was unread stays highlighted until the user leaves. Swiping a
// row toward the start deletes it, with Undo.
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

  final ActivityParticipationModel _participation =
      ActivityParticipationModel();

  // Friend requests shown here; "See all" opens the rest.
  static const _requestsShown = 2;

  // Notifications shown at first, and how many more each Load more adds.
  static const _page = 15;
  int _shown = _page;

  // Unread when the screen opened.
  final Set<String> _newIds = {};

  // Join requests answered here: true when accepted.
  final Map<String, bool> _answered = {};
  final Set<String> _reviewing = {};

  // Swiped away, waiting for the Undo bar to close.
  final Set<String> _hidden = {};
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undoBar;

  @override
  void initState() {
    super.initState();
    _keepNew();
    _refresh();
  }

  @override
  void dispose() {
    // Closing the bar saves any delete still waiting on it.
    _undoBar?.close();
    super.dispose();
  }

  Future<void> _refresh() async {
    unawaited(MainShell.checkAccount());
    await Future.wait([_c.refresh(), _friends.refresh()]);
    if (!mounted) return;
    setState(_keepNew);
    _c.markAllSeen();
  }

  void _keepNew() {
    _newIds.addAll([
      for (final n in _c.items)
        if (n.isUnread) n.id,
    ]);
  }

  bool _isHighlighted(AppNotification n) {
    if (_answered.containsKey(n.id)) return false;
    return n.requestPending || _newIds.contains(n.id);
  }

  Future<void> _open(AppNotification notification) async {
    final activityId = notification.activityId;
    switch (notification.kind) {
      case 'join_request_received':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ActivityJoinRequestsView(activityStore: widget.activityStore),
          ),
        );
        // The request may have been answered there.
        if (mounted) await _refresh();
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

  Future<void> _review(AppNotification notification, bool accept) async {
    final participationId = notification.participationId;
    if (participationId == null || _reviewing.contains(notification.id)) {
      return;
    }
    setState(() => _reviewing.add(notification.id));
    try {
      final response = await _participation.reviewRequest(
        participationId: participationId,
        accept: accept,
      );
      if (!mounted) return;
      const done = {'joined', 'waitlisted', 'rejected'};
      final status = response.status?.trim().toLowerCase();
      final result = response.result.trim().toLowerCase();
      if (done.contains(status) || done.contains(result)) {
        setState(() => _answered[notification.id] = accept);
      } else {
        SynkFeedback.showError(context, response.message);
      }
    } catch (_) {
      if (mounted) {
        SynkFeedback.showError(
          context,
          context.l10n.somethingWentWrongPleaseTryAgain,
        );
      }
    } finally {
      if (mounted) setState(() => _reviewing.remove(notification.id));
    }
  }

  // Hidden at once; deleted for good when the Undo bar closes on its own.
  void _delete(AppNotification notification) {
    setState(() => _hidden.add(notification.id));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final bar = messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.notificationDeleted),
        behavior: SnackBarBehavior.floating,
        backgroundColor: SynkColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: SnackBarAction(
          label: context.l10n.undo,
          textColor: SynkColors.orange,
          onPressed: () {},
        ),
      ),
    );
    _undoBar = bar;
    bar.closed.then((reason) {
      if (_undoBar == bar) _undoBar = null;
      if (reason == SnackBarClosedReason.action) {
        if (mounted) setState(() => _hidden.remove(notification.id));
      } else {
        _c.delete(notification);
        _hidden.remove(notification.id);
      }
    });
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
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
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
    final items = [
      for (final n in _c.items)
        if (!_hidden.contains(n.id)) n,
    ];

    if (requests.isEmpty && items.isEmpty) return _buildEmpty();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (requests.isNotEmpty) ...[
          _SectionHeader(
            title: context.l10n.friendRequests,
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
          for (final (i, request) in requests.take(_requestsShown).indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: ReceivedRequestCard(request: request),
            ),
        ],
        for (final (title, section) in _sections(
          items.take(_shown).toList(),
        )) ...[_SectionHeader(title: title), _buildCard(section)],
        if (items.length > _shown)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Center(
              child: TextButton(
                onPressed: () => setState(() => _shown += _page),
                style: TextButton.styleFrom(
                  foregroundColor: SynkColors.orangeDeep,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  context.l10n.loadMore,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(List<AppNotification> items) {
    final rows = <Widget>[];
    for (final (i, notification) in items.indexed) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 76,
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
            highlighted: _isHighlighted(notification),
            answered: _answered[notification.id],
            reviewing: _reviewing.contains(notification.id),
            onTap: () => _open(notification),
            onAccept: () => _review(notification, true),
            onDecline: () => _review(notification, false),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }

  // New first, then by day, newest first. Empty sections are left out.
  List<(String, List<AppNotification>)> _sections(List<AppNotification> items) {
    final today = DateUtils.dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    final fresh = <AppNotification>[];
    final todays = <AppNotification>[];
    final yesterdays = <AppNotification>[];
    final thisWeek = <AppNotification>[];
    final earlier = <AppNotification>[];
    for (final n in items) {
      final day = DateUtils.dateOnly(n.createdAt);
      if (_newIds.contains(n.id)) {
        fresh.add(n);
      } else if (!day.isBefore(today)) {
        todays.add(n);
      } else if (!day.isBefore(yesterday)) {
        yesterdays.add(n);
      } else if (!day.isBefore(weekAgo)) {
        thisWeek.add(n);
      } else {
        earlier.add(n);
      }
    }
    final l = context.l10n;
    return [
      if (fresh.isNotEmpty) (l.notificationsNew, fresh),
      if (todays.isNotEmpty) (l.today, todays),
      if (yesterdays.isNotEmpty) (l.yesterday, yesterdays),
      if (thisWeek.isNotEmpty) (l.thisWeek, thisWeek),
      if (earlier.isNotEmpty) (l.notificationsEarlier, earlier),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 20, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SynkColors.textSecondary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.highlighted,
    required this.answered,
    required this.reviewing,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
  });

  final AppNotification notification;
  final bool highlighted;

  // Join requests answered on this screen: true when accepted.
  final bool? answered;
  final bool reviewing;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  bool get _isFriendKind => notification.kind.startsWith('friend_request');

  // Badge icon, badge colour and message for each kind of notification.
  (IconData, Color, String Function(String)) _style(BuildContext context) {
    final l = context.l10n;
    return switch (notification.kind) {
      'waitlist_promotion' => (
        Icons.check_rounded,
        SynkColors.teal,
        l.notifWaitlistPromotion,
      ),
      'activity_updated' => (
        Icons.edit_rounded,
        SynkColors.teal,
        l.notifActivityUpdated,
      ),
      'activity_deleted' => (
        Icons.close_rounded,
        SynkColors.badge,
        l.notifActivityDeleted,
      ),
      'join_request_accepted' => (
        Icons.check_rounded,
        SynkColors.teal,
        l.notifRequestAccepted,
      ),
      'join_request_rejected' => (
        Icons.close_rounded,
        SynkColors.badge,
        l.notifRequestRejected,
      ),
      'join_request_received' => (
        Icons.people_alt_rounded,
        SynkColors.orangeDark,
        l.notifRequestReceived,
      ),
      'host_assigned' => (
        Icons.star_rounded,
        SynkColors.beigeDark,
        l.notifHostAssigned,
      ),
      'activity_full' => (
        Icons.people_alt_rounded,
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
        Icons.priority_high_rounded,
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

  Widget _buildThumb(IconData badgeIcon, Color badgeColor) {
    final Widget image = _isFriendKind
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              color: SynkColors.pink.withValues(alpha: 0.22),
              child: Icon(
                badgeIcon,
                size: 20,
                color: Color.lerp(
                  SynkColors.pink,
                  SynkColors.textPrimary,
                  0.35,
                ),
              ),
            ),
          )
        : ActivityThumbnail(
            activity: Activity(
              id: notification.activityId ?? notification.id,
              title: notification.activityTitle,
              dateTime: notification.createdAt,
              location: '',
              categoryLabel: notification.categoryLabel,
              photoUrl: notification.photoUrl,
            ),
            size: 44,
            radius: 12,
          );
    if (_isFriendKind) return image;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          image,
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(badgeIcon, size: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildActions(BuildContext context) {
    final l = context.l10n;
    if (notification.kind == 'join_request_received' &&
        notification.participationId != null) {
      final answer = answered;
      if (answer != null) {
        return Text(
          answer ? l.requestAcceptedLabel : l.requestDeclinedLabel,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SynkColors.textSecondary,
          ),
        );
      }
      if (!notification.requestPending) return null;
      return Row(
        children: [
          _SmallButton(
            label: l.accept,
            filled: true,
            onPressed: reviewing ? null : onAccept,
          ),
          const SizedBox(width: 8),
          _SmallButton(
            label: l.decline,
            onPressed: reviewing ? null : onDecline,
          ),
        ],
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, message) = _style(context);
    final actions = _buildActions(context);

    // Bold title inside the translated sentence.
    const marker = '\u0000';
    final parts = message(marker).split(marker);

    return Material(
      color: highlighted
          ? SynkColors.orange.withValues(alpha: 0.07)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumb(icon, color),
              SizedBox(width: _isFriendKind ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(context),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                    if (actions != null) ...[
                      const SizedBox(height: 10),
                      actions,
                    ],
                  ],
                ),
              ),
              // Same width either way, so text doesn't shift.
              SizedBox(
                width: 16,
                child: highlighted
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 8,
                          top: 6,
                        ),
                        child: Container(
                          width: 8,
                          height: 8,
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

// Accept and Decline under a join request.
class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    const padding = EdgeInsets.symmetric(horizontal: 16);
    const size = Size(0, 34);
    final text = Text(
      label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    );
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: SynkColors.orangeDark,
          foregroundColor: Colors.white,
          minimumSize: size,
          padding: padding,
          shape: shape,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: text,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: SynkColors.textPrimary,
        side: BorderSide(
          color: SynkColors.textSecondary.withValues(alpha: 0.30),
        ),
        minimumSize: size,
        padding: padding,
        shape: shape,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: text,
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
