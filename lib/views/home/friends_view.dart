import 'package:flutter/material.dart';

import '../../controllers/friends_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/friends_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'blocked_users_view.dart';
import 'find_people_view.dart';
import 'widgets/empty_state.dart';
import 'widgets/friend_options_sheet.dart';
import 'widgets/friends_list_widgets.dart';
import 'widgets/user_avatar.dart';

// The user's friends, plus a tab of friend requests sent and received.
class FriendsView extends StatefulWidget {
  const FriendsView({super.key, this.showRequestsFirst = false});

  // Opens on the Requests tab, e.g. when the home badge shows requests.
  final bool showRequestsFirst;

  @override
  State<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> {
  final FriendsController _friends = FriendsController.instance;
  final TextEditingController _search = TextEditingController();
  late bool _showRequests = widget.showRequestsFirst;

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

  String _formatAgo(DateTime dateTime) {
    final ago = DateTime.now().difference(dateTime.toLocal());
    if (ago.inMinutes < 1) return context.l10n.justNow;
    if (ago.inHours < 1) return context.l10n.minutesAgo(ago.inMinutes);
    if (ago.inDays < 1) return context.l10n.hoursAgo(ago.inHours);
    if (ago.inDays < 7) return context.l10n.daysAgo(ago.inDays);
    return formatShortDate(dateTime.toLocal());
  }

  Future<void> _accept(FriendRequest request) async {
    final ok = await _friends.acceptRequest(request.user.id);
    if (!mounted) return;
    if (!ok) return _showError();
    SynkFeedback.showToast(
      context,
      title: context.l10n.youAreNowFriendsWith(request.user.name),
    );
  }

  Future<void> _reject(FriendRequest request) async {
    final ok = await _friends.rejectRequest(request.user.id);
    if (!mounted) return;
    if (!ok) return _showError();
    SynkFeedback.showToast(context, title: context.l10n.friendRequestRejected);
  }

  Future<void> _cancel(FriendRequest request) async {
    final ok = await _friends.cancelRequest(request.user.id);
    if (!mounted) return;
    if (!ok) return _showError();
    SynkFeedback.showToast(context, title: context.l10n.friendRequestCancelled);
  }

  void _showError() {
    SynkFeedback.showError(
      context,
      context.l10n.somethingWentWrongPleaseTryAgain,
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
          context.l10n.friends,
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: _buildTabs(),
            ),
            Expanded(
              child: !_friends.hasLoaded
                  ? _buildFirstLoad()
                  : _showRequests
                  ? _buildRequests()
                  : _buildFriends(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final pending = _friends.pendingCount;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SynkColors.textSecondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: '${context.l10n.friends} · ${_friends.friends.length}',
              selected: !_showRequests,
              onTap: () => setState(() => _showRequests = false),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _TabButton(
              label: context.l10n.friendRequestsTab,
              selected: _showRequests,
              badge: pending,
              onTap: () => setState(() => _showRequests = true),
            ),
          ),
        ],
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

  Widget _buildRequests() {
    final received = _friends.receivedRequests;
    final sent = _friends.sentRequests;

    if (received.isEmpty && sent.isEmpty) {
      return EmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: context.l10n.noFriendRequests,
        message: context.l10n.newFriendRequestsShowUpHere,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        if (received.isNotEmpty) ...[
          _SectionTitle(
            '${context.l10n.receivedRequests} · ${received.length}',
          ),
          for (final request in received)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ReceivedRequestCard(
                request: request,
                subtitle: _subtitle(request),
                onAccept: () => _accept(request),
                onReject: () => _reject(request),
              ),
            ),
          const SizedBox(height: 10),
        ],
        if (sent.isNotEmpty) ...[
          _SectionTitle('${context.l10n.sentRequests} · ${sent.length}'),
          FriendsListCard(
            children: [
              for (final request in sent)
                FriendsPersonRow(
                  user: request.user,
                  subtitle: _subtitle(request),
                  onTap: () => openFriendProfile(context, request.user),
                  trailing: TextButton(
                    onPressed: () => _cancel(request),
                    style: TextButton.styleFrom(
                      foregroundColor: SynkColors.textSecondary,
                    ),
                    child: Text(
                      context.l10n.cancel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _subtitle(FriendRequest request) {
    final username = request.user.username;
    return [
      if (username != null && username.isNotEmpty) '@$username',
      _formatAgo(request.createdAt),
    ].join(' · ');
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    color: selected
                        ? SynkColors.textPrimary
                        : SynkColors.labelGrey,
                  ),
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SynkColors.badge,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceivedRequestCard extends StatelessWidget {
  const _ReceivedRequestCard({
    required this.request,
    required this.subtitle,
    required this.onAccept,
    required this.onReject,
  });

  final FriendRequest request;
  final String subtitle;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return FriendsCardBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          InkWell(
            onTap: () => openFriendProfile(context, request.user),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                UserAvatar(
                  avatarUrl: request.user.avatarUrl,
                  gender: request.user.gender,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FriendsNameAndSubtitle(
                    name: request.user.name,
                    subtitle: subtitle,
                    nameSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: SynkColors.textPrimary,
                    side: BorderSide(
                      color: SynkColors.textSecondary.withValues(alpha: 0.30),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    context.l10n.reject,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: onAccept,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: SynkColors.orangeDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    context.l10n.accept,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
          color: SynkColors.labelGrey,
        ),
      ),
    );
  }
}
