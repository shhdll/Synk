import 'dart:async';

import 'package:flutter/material.dart';

import '../../../controllers/chat_controller.dart';
import '../../../controllers/friends_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/friends_model.dart';
import '../../../utils/custom_widgets/synk_dialog.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';
import '../chats_view.dart';
import 'user_avatar.dart';
import 'user_profile_sheet.dart';
import 'report_user_sheet.dart';

// The ⋮ menu on a friend: view profile, message, remove friend, report, block.
Future<void> showFriendOptionsSheet({
  required BuildContext context,
  required FriendUser friend,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final username = friend.username;

      return Container(
        decoration: const BoxDecoration(
          color: SynkColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SynkColors.textSecondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 4, 16),
                  child: Row(
                    children: [
                      UserAvatar(
                        avatarUrl: friend.avatarUrl,
                        gender: friend.gender,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              friend.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: SynkColors.textPrimary,
                              ),
                            ),
                            if (username != null && username.isNotEmpty)
                              Text(
                                '@$username',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: SynkColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: SynkColors.textSecondary.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        _OptionTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: l10n.message,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            openDirectChatWith(context, friend);
                          },
                        ),
                        const _OptionDivider(),
                        _OptionTile(
                          icon: Icons.person_outline_rounded,
                          label: l10n.viewProfile,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            openFriendProfile(context, friend);
                          },
                        ),
                        const _OptionDivider(),
                        _OptionTile(
                          icon: Icons.person_remove_outlined,
                          label: l10n.removeFriend,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            confirmRemoveFriend(context, friend);
                          },
                        ),
                        const _OptionDivider(),
                        _OptionTile(
                          icon: Icons.flag_outlined,
                          label: l10n.reportName(friend.name.split(' ').first),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            showReportUserSheet(context: context, user: friend);
                          },
                        ),
                        const _OptionDivider(),
                        _OptionTile(
                          icon: Icons.block_rounded,
                          label: l10n.blockName(friend.name.split(' ').first),
                          color: SynkColors.badge,
                          onTap: () {
                            Navigator.pop(sheetContext);
                            confirmBlockUser(context, friend);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> openFriendProfile(
  BuildContext context,
  FriendUser user, {
  bool showMessageButton = true,
}) {
  return showUserProfileSheet(
    context: context,
    userId: user.id,
    name: user.name,
    username: user.username,
    avatarUrl: user.avatarUrl,
    gender: user.gender,
    showMessageButton: showMessageButton,
  );
}

Future<void> confirmRemoveFriend(
  BuildContext context,
  FriendUser friend,
) async {
  final firstName = friend.name.split(' ').first;
  final action = await SynkDialog.destructive(
    icon: Icons.person_remove_rounded,
    title: context.l10n.removeFriendTitle(firstName),
    message: context.l10n.removeFriendMessage(firstName),
    primaryLabel: context.l10n.cancel,
    secondaryLabel: context.l10n.remove,
  ).show(context);
  if (action != SynkDialogAction.secondary) return;

  final ok = await FriendsController.instance.removeFriend(friend.id);
  if (!context.mounted) return;
  if (!ok) return _showError(context);
  SynkFeedback.showToast(context, title: context.l10n.friendRemoved(firstName));
}

Future<void> confirmBlockUser(BuildContext context, FriendUser user) async {
  final firstName = user.name.split(' ').first;
  // Blocking someone who hosts an activity you're in takes you out of it.
  final leavesActivity = await FriendsController.instance
      .blockRemovesMeFromActivity(user.id);
  if (!context.mounted) return;
  final action = await SynkDialog.destructive(
    icon: Icons.block_rounded,
    title: context.l10n.blockUserTitle(firstName),
    message: leavesActivity
        ? context.l10n.blockHostMessage
        : context.l10n.blockUserMessage,
    primaryLabel: context.l10n.cancel,
    secondaryLabel: context.l10n.block,
  ).show(context);
  if (action != SynkDialogAction.secondary) return;

  final ok = await FriendsController.instance.block(user);
  // A block can take one of you out of the other's activity and its chat.
  if (ok) unawaited(ChatController.instance.refresh());
  if (!context.mounted) return;
  if (!ok) return _showError(context);
  SynkFeedback.showToast(context, title: context.l10n.userBlocked(firstName));
}

void _showError(BuildContext context) {
  SynkFeedback.showError(
    context,
    context.l10n.somethingWentWrongPleaseTryAgain,
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = SynkColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionDivider extends StatelessWidget {
  const _OptionDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: SynkColors.textSecondary.withValues(alpha: 0.10),
    );
  }
}
