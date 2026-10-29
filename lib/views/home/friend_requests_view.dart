import 'package:flutter/material.dart';

import '../../controllers/friends_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/friends_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'widgets/empty_state.dart';
import 'widgets/friend_options_sheet.dart';
import 'widgets/friends_list_widgets.dart';
import 'widgets/user_avatar.dart';

// Every friend request, received and sent. Opened from "See all" in the
// notification center and from friend request notifications.
class FriendRequestsView extends StatefulWidget {
  const FriendRequestsView({super.key});

  @override
  State<FriendRequestsView> createState() => _FriendRequestsViewState();
}

class _FriendRequestsViewState extends State<FriendRequestsView> {
  final FriendsController _friends = FriendsController.instance;

  @override
  void initState() {
    super.initState();
    _friends.refresh();
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
          context.l10n.friendRequests,
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
          listenable: _friends,
          builder: (context, _) => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_friends.hasLoaded) {
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
          FriendRequestsSectionTitle(
            '${context.l10n.receivedRequests} · ${received.length}',
          ),
          for (final request in received)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ReceivedRequestCard(request: request),
            ),
          const SizedBox(height: 10),
        ],
        if (sent.isNotEmpty) ...[
          FriendRequestsSectionTitle(
            '${context.l10n.sentRequests} · ${sent.length}',
          ),
          FriendsListCard(
            children: [
              for (final request in sent)
                FriendsPersonRow(
                  user: request.user,
                  subtitle: friendRequestSubtitle(context, request),
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

  Future<void> _cancel(FriendRequest request) async {
    final ok = await _friends.cancelRequest(request.user.id);
    if (!mounted) return;
    if (!ok) return _showRequestError(context);
    SynkFeedback.showToast(context, title: context.l10n.friendRequestCancelled);
  }
}

// "@username · 2h ago".
String friendRequestSubtitle(BuildContext context, FriendRequest request) {
  final l10n = context.l10n;
  final ago = DateTime.now().difference(request.createdAt.toLocal());
  final when = ago.inMinutes < 1
      ? l10n.justNow
      : ago.inHours < 1
      ? l10n.minutesAgo(ago.inMinutes)
      : ago.inDays < 1
      ? l10n.hoursAgo(ago.inHours)
      : ago.inDays < 7
      ? l10n.daysAgo(ago.inDays)
      : formatShortDate(request.createdAt.toLocal());
  final username = request.user.username;
  return [
    if (username != null && username.isNotEmpty) '@$username',
    when,
  ].join(' · ');
}

void _showRequestError(BuildContext context) {
  SynkFeedback.showError(
    context,
    context.l10n.somethingWentWrongPleaseTryAgain,
  );
}

// A request someone sent the user, with Reject and Accept.
class ReceivedRequestCard extends StatelessWidget {
  const ReceivedRequestCard({super.key, required this.request});

  final FriendRequest request;

  Future<void> _accept(BuildContext context) async {
    final ok = await FriendsController.instance.acceptRequest(request.user.id);
    if (!context.mounted) return;
    if (!ok) return _showRequestError(context);
    SynkFeedback.showToast(
      context,
      title: context.l10n.youAreNowFriendsWith(request.user.name),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final ok = await FriendsController.instance.rejectRequest(request.user.id);
    if (!context.mounted) return;
    if (!ok) return _showRequestError(context);
    SynkFeedback.showToast(context, title: context.l10n.friendRequestRejected);
  }

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
                    subtitle: friendRequestSubtitle(context, request),
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
                  onPressed: () => _reject(context),
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
                  onPressed: () => _accept(context),
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

class FriendRequestsSectionTitle extends StatelessWidget {
  const FriendRequestsSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
                color: SynkColors.labelGrey,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
