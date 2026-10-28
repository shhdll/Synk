import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../models/friends_model.dart';
import 'user_avatar.dart';

// "Sara is going", "Sara and Lina are going", "Sara and 2 other friends…".
// Uses appL10n like the home card, which builds without a context lookup.
String friendsGoingText(List<FriendUser> friends) {
  String first(FriendUser u) => u.name.split(' ').first;
  final l10n = appL10n;
  return switch (friends.length) {
    1 => l10n.friendIsGoing(first(friends[0])),
    2 => l10n.twoFriendsAreGoing(first(friends[0]), first(friends[1])),
    _ => l10n.friendAndOthersAreGoing(first(friends[0]), friends.length - 1),
  };
}

// Up to three overlapping friend photos, each in a thin ring.
class FriendAvatarStack extends StatelessWidget {
  const FriendAvatarStack({
    super.key,
    required this.friends,
    this.size = 22,
    this.ringColor = Colors.white,
  });

  final List<FriendUser> friends;
  final double size;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final shown = friends.take(3).toList();
    final step = size * 0.68;

    return SizedBox(
      width: size + step * (shown.length - 1),
      height: size,
      child: Stack(
        children: [
          for (final (i, friend) in shown.indexed)
            PositionedDirectional(
              start: step * i,
              child: Container(
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  color: ringColor,
                  shape: BoxShape.circle,
                ),
                child: UserAvatar(
                  avatarUrl: friend.avatarUrl,
                  gender: friend.gender,
                  size: size - 3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
