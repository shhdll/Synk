import 'package:flutter/material.dart';

import '../../../controllers/friends_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../friends_view.dart';

// The friends button in the home header, next to the bell, with a badge for
// friend requests waiting for an answer.
class FriendsButton extends StatelessWidget {
  const FriendsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final friends = FriendsController.instance;

    return ListenableBuilder(
      listenable: friends,
      builder: (context, _) {
        final count = friends.pendingCount;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 1,
              shadowColor: Colors.black12,
              child: IconButton(
                tooltip: context.l10n.friends,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FriendsView(showRequestsFirst: count > 0),
                  ),
                ),
                icon: const Icon(
                  Icons.people_alt_outlined,
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
