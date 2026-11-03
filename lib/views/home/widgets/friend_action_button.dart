import 'package:flutter/material.dart';

import '../../../controllers/friends_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/friends_model.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';
import 'friend_options_sheet.dart';

// Add / Requested / Accept / Following, depending on where the signed-in
// user stands with [user]. Tapping Following asks to remove the friend.
// [compact] is the small version used in lists.
class FriendActionButton extends StatelessWidget {
  const FriendActionButton({
    super.key,
    required this.user,
    this.compact = false,
  });

  final FriendUser user;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final friends = FriendsController.instance;

    return ListenableBuilder(
      listenable: friends,
      builder: (context, _) {
        final l10n = context.l10n;
        return switch (friends.statusFor(user.id)) {
          FriendshipStatus.none => _button(
            label: compact ? l10n.addShort : l10n.addFriend,
            icon: Icons.person_add_alt_1_rounded,
            background: SynkColors.orangeDark,
            foreground: Colors.white,
            onTap: () async {
              final ok = await friends.sendRequest(user);
              if (!context.mounted) return;
              if (!ok) return _showError(context);
              SynkFeedback.showToast(
                context,
                title: friends.statusFor(user.id) == FriendshipStatus.friends
                    ? l10n.youAreNowFriendsWith(user.name)
                    : l10n.friendRequestSent,
              );
            },
          ),
          FriendshipStatus.requestSent => _button(
            label: l10n.requested,
            icon: Icons.schedule_rounded,
            background: SynkColors.textSecondary.withValues(alpha: 0.12),
            foreground: SynkColors.textPrimary,
            tooltip: l10n.cancelRequest,
            onTap: () async {
              final ok = await friends.cancelRequest(user.id);
              if (!context.mounted) return;
              if (!ok) return _showError(context);
              SynkFeedback.showToast(
                context,
                title: l10n.friendRequestCancelled,
              );
            },
          ),
          FriendshipStatus.requestReceived => _button(
            label: compact ? l10n.accept : l10n.acceptRequest,
            icon: Icons.check_rounded,
            background: SynkColors.tealText,
            foreground: Colors.white,
            onTap: () async {
              final ok = await friends.acceptRequest(user.id);
              if (!context.mounted) return;
              if (!ok) return _showError(context);
              SynkFeedback.showToast(
                context,
                title: l10n.youAreNowFriendsWith(user.name),
              );
            },
          ),
          FriendshipStatus.friends => _button(
            label: l10n.following,
            icon: Icons.check_rounded,
            background: SynkColors.textSecondary.withValues(alpha: 0.10),
            foreground: SynkColors.textPrimary,
            tooltip: l10n.removeFriend,
            onTap: () => confirmRemoveFriend(context, user),
          ),
          FriendshipStatus.blocked => const SizedBox.shrink(),
        };
      },
    );
  }

  void _showError(BuildContext context) {
    SynkFeedback.showError(
      context,
      context.l10n.somethingWentWrongPleaseTryAgain,
    );
  }

  Widget _button({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    String? tooltip,
    VoidCallback? onTap,
  }) {
    // Same corners as the buttons beside it on the profile.
    final radius = BorderRadius.circular(compact ? 12 : 16);
    final button = Material(
      color: background,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: compact ? 38 : 52,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!compact) ...[
                Icon(icon, size: 20, color: foreground),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
