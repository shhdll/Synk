import 'package:flutter/material.dart';

import '../../controllers/friends_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import 'blocked_users_view.dart';
import 'find_people_view.dart';
import 'widgets/empty_state.dart';
import 'widgets/friend_options_sheet.dart';
import 'widgets/friends_list_widgets.dart';

// The user's friends. Friend requests live in the notification center.
class FriendsView extends StatefulWidget {
  const FriendsView({super.key});

  @override
  State<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> {
  final FriendsController _friends = FriendsController.instance;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _friends.addListener(_refresh);
    _friends.refresh();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _friends.removeListener(_refresh);
    _search.dispose();
    super.dispose();
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
          '${context.l10n.friends} · ${_friends.friends.length}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.findPeople,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FindPeopleView()),
            ),
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
              color: SynkColors.textPrimary,
            ),
          ),
          IconButton(
            tooltip: context.l10n.blockedUsers,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BlockedUsersView()),
            ),
            icon: const Icon(
              Icons.block_rounded,
              color: SynkColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !_friends.hasLoaded ? _buildFirstLoad() : _buildFriends(),
      ),
    );
  }

  Widget _buildFirstLoad() {
    if (_friends.error == null) {
      return const Center(
        child: CircularProgressIndicator(color: SynkColors.orangeDark),
      );
    }
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: context.l10n.somethingWentWrong,
      message: context.l10n.checkYourConnectionAndTryAgain,
      actionLabel: context.l10n.tryAgain,
      onAction: _friends.refresh,
    );
  }

  Widget _buildFriends() {
    final all = _friends.friends;
    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.people_alt_rounded,
        title: context.l10n.noFriendsYet,
        message: context.l10n.findPeopleYouKnow,
        actionLabel: context.l10n.findPeople,
        onAction: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const FindPeopleView())),
      );
    }

    final shown = _friends.searchFriends(_search.text);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        FriendsSearchField(
          controller: _search,
          hint: context.l10n.searchFriends,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Text(
              context.l10n.noFriendsMatchYourSearch,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: SynkColors.textSecondary,
              ),
            ),
          )
        else
          FriendsListCard(
            children: [
              for (final friend in shown)
                FriendsPersonRow(
                  user: friend,
                  onTap: () => openFriendProfile(context, friend),
                  trailing: IconButton(
                    tooltip: context.l10n.friendOptions,
                    onPressed: () => showFriendOptionsSheet(
                      context: context,
                      friend: friend,
                    ),
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
