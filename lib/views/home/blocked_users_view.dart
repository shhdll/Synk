import 'package:flutter/material.dart';

import '../../controllers/friends_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/friends_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'widgets/empty_state.dart';
import 'widgets/friends_list_widgets.dart';

// People the user has blocked, each with an Unblock button.
class BlockedUsersView extends StatelessWidget {
  const BlockedUsersView({super.key});

  Future<void> _unblock(BuildContext context, FriendUser user) async {
    final ok = await FriendsController.instance.unblock(user.id);
    if (!context.mounted) return;
    if (!ok) {
      SynkFeedback.showError(
        context,
        context.l10n.somethingWentWrongPleaseTryAgain,
      );
      return;
    }
    SynkFeedback.showToast(
      context,
      title: context.l10n.userUnblocked(user.name.split(' ').first),
    );
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
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SynkColors.textPrimary,
          ),
        ),
        title: Text(
          context.l10n.blockedUsers,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: FriendsController.instance,
          builder: (context, _) {
            final friends = FriendsController.instance;
            final blocked = friends.blocked;

            if (!friends.hasLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: SynkColors.orangeDark),
              );
            }

            if (blocked.isEmpty) {
              return EmptyState(
                icon: Icons.verified_user_outlined,
                title: context.l10n.noBlockedUsers,
                message: context.l10n.peopleYouBlockShowUpHere,
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    context.l10n.blockedUsersInfo,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FriendsListCard(
                  children: [
                    for (final user in blocked)
                      FriendsPersonRow(
                        user: user,
                        trailing: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 4),
                          child: OutlinedButton(
                            onPressed: () => _unblock(context, user),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              foregroundColor: SynkColors.textPrimary,
                              side: BorderSide(
                                color: SynkColors.textSecondary.withValues(
                                  alpha: 0.30,
                                ),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              context.l10n.unblock,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
