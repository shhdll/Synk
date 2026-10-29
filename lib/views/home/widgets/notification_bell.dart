import 'package:flutter/material.dart';

import '../../../controllers/friends_controller.dart';
import '../../../controllers/notification_center_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_model.dart';
import '../notification_center_view.dart';

// The bell in the home header, with a badge for unread notifications plus
// friend requests waiting for an answer.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.controller,
    required this.activityStore,
  });

  final NotificationCenterController controller;
  final ActivityStore activityStore;

  @override
  Widget build(BuildContext context) {
    final friends = FriendsController.instance;

    return AnimatedBuilder(
      animation: Listenable.merge([controller, friends]),
      builder: (context, _) {
        final count = controller.unreadCount + friends.pendingCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 1,
              shadowColor: Colors.black12,
              child: IconButton(
                tooltip: context.l10n.notifications,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => NotificationCenterView(
                      controller: controller,
                      activityStore: activityStore,
                    ),
                  ),
                ),
                icon: Icon(
                  count > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  color: SynkColors.textPrimary,
                ),
              ),
            ),
            if (count > 0)
              PositionedDirectional(
                top: -2,
                end: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SynkColors.badge,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SynkColors.background, width: 2),
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
