import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/friends_model.dart';
import 'widgets/empty_state.dart';
import 'widgets/friend_options_sheet.dart';
import 'widgets/friends_list_widgets.dart';

// Someone else's friends, opened from the count on their profile.
class UserFriendsView extends StatelessWidget {
  const UserFriendsView({super.key, required this.name, required this.friends});

  final String name;
  final List<FriendUser> friends;

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final firstName = name.split(' ').first;

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
          context.l10n.friendsOfName(firstName),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: friends.isEmpty
            ? EmptyState(
                icon: Icons.people_alt_outlined,
                title: context.l10n.noFriendsYet,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  FriendsListCard(
                    children: [
                      for (final friend in friends)
                        FriendsPersonRow(
                          user: friend,
                          onTap: friend.id == me
                              ? null
                              : () => openFriendProfile(context, friend),
                          trailing: friend.id == me
                              ? Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 8,
                                  ),
                                  child: Text(
                                    context.l10n.you,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: SynkColors.textSecondary,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  color: SynkColors.textSecondary,
                                ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
