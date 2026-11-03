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
            // A small dot when there's something new.
            if (count > 0)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: SynkColors.orangeDark,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
