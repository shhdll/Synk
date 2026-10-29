import 'package:flutter/material.dart';

import '../../controllers/notification_center_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activity_model.dart';
import '../../models/notifications_model.dart';
import 'activity_join_requests_view.dart';
import 'activity_notification_route.dart';
import 'friends_view.dart';
import 'schedule_conflict_resolution_view.dart';

// The list behind the bell. Opening it clears the badge.
class NotificationCenterView extends StatefulWidget {
  const NotificationCenterView({
    super.key,
    required this.controller,
    required this.activityStore,
  });

  final NotificationCenterController controller;
  final ActivityStore activityStore;

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView> {
  NotificationCenterController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _c.refresh();
    await _c.markAllSeen();
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
      case 'friend_request_received':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const FriendsView(showRequestsFirst: true),
          ),
        );
      case 'friend_request_accepted':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const FriendsView()),
        );
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
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            if (_c.isLoading && !_c.hasLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: SynkColors.orangeDark),
              );
            }
            return RefreshIndicator(
              color: SynkColors.orangeDark,
              backgroundColor: Colors.white,
              onRefresh: _c.refresh,
              child: _c.items.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: _c.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notification = _c.items[index];
                        return _NotificationTile(
                          notification: notification,
                          onTap: () => _open(notification),
                        );
                      },
                    ),
            );
          },
        ),
      ),
    );
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
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

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
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(context),
                      style: const TextStyle(
                        fontSize: 12,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsetsDirectional.only(start: 8, top: 6),
                  decoration: const BoxDecoration(
                    color: SynkColors.orangeDark,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
