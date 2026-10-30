import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/chat_controller.dart';
import '../../controllers/friends_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activity_model.dart';
import '../../models/chat_model.dart';
import '../../models/friends_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../../utils/text_direction.dart';
import 'chat_room_view.dart';
import 'find_people_view.dart';
import 'widgets/chat_list_tile.dart';
import 'widgets/empty_state.dart';
import 'widgets/friends_list_widgets.dart';

// Opens the chat with a friend, creating it the first time.
Future<void> openDirectChatWith(BuildContext context, FriendUser friend) async {
  final chatId = await ChatController.instance.openDirectChat(friend.id);
  if (!context.mounted) return;
  if (chatId == null) {
    SynkFeedback.showToast(
      context,
      title: context.l10n.couldntOpenChat,
      message: context.l10n.canOnlyMessageFriends,
      success: false,
    );
    return;
  }
  final chat =
      ChatController.instance.byId(chatId) ??
      ChatSummary(
        id: chatId,
        kind: ChatKind.direct,
        createdAt: DateTime.now(),
        otherUser: friend,
      );
  await openChatRoom(context, chat);
}

// A chat bubble with a small plus at its top-right corner.
class NewChatIcon extends StatelessWidget {
  const NewChatIcon({super.key, required this.color, this.size = 24});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.5;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: size, color: color),
          PositionedDirectional(
            top: -badge * 0.3,
            end: -badge * 0.3,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(
                Icons.add_rounded,
                size: badge * 0.85,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// The Chat tab: activity group chats first, then chats with friends.
class ChatsView extends StatefulWidget {
  const ChatsView({super.key, this.activityStore});

  // Where an activity chat's title opens the activity.
  final ActivityStore? activityStore;

  @override
  State<ChatsView> createState() => _ChatsViewState();
}

class _ChatsViewState extends State<ChatsView> {
  final ChatController _chats = ChatController.instance;
  final TextEditingController _search = TextEditingController();

  static const double _gutter = 16;

  @override
  void initState() {
    super.initState();
    unawaited(_chats.refresh());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ChatSummary> _matching(List<ChatSummary> chats) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return chats;
    return chats
        .where(
          (c) =>
              c.title.toLowerCase().contains(q) ||
              (c.otherUser?.username?.toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  void _openNewChatSheet() {
    unawaited(FriendsController.instance.refresh());
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SynkColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _NewChatSheet(
        onPick: (friend) {
          Navigator.pop(sheetContext);
          openDirectChatWith(context, friend);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: SynkColors.orangeDark,
          backgroundColor: Colors.white,
          onRefresh: _chats.refresh,
          child: ListenableBuilder(
            listenable: _chats,
            builder: (context, _) => _buildList(),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final activityChats = _matching(_chats.activityChats);
    final directChats = _matching(_chats.directChats);
    final searching = _search.text.trim().isNotEmpty;
    final nothingYet =
        _chats.hasLoaded &&
        _chats.activityChats.isEmpty &&
        _chats.directChats.isEmpty;

    // Swipe toward the start to show Mute and Delete.
    Widget tile(ChatSummary chat) => Slidable(
      key: ValueKey(chat.id),
      groupTag: 'chats',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _chats.setMuted(chat.id, !chat.isMuted),
            backgroundColor: SynkColors.textSecondary,
            foregroundColor: Colors.white,
            icon: chat.isMuted
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
            label: chat.isMuted ? context.l10n.unmute : context.l10n.mute,
          ),
          SlidableAction(
            onPressed: (_) => confirmDeleteChat(context, chat),
            backgroundColor: SynkColors.badge,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: context.l10n.deleteLabel,
          ),
        ],
      ),
      child: ChatListTile(
        chat: chat,
        currentUserId: me,
        onTap: () =>
            openChatRoom(context, chat, activityStore: widget.activityStore),
      ),
    );

    // Opening one row's actions closes any other.
    return SlidableAutoCloseBehavior(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        // Bottom room for MainShell's bar, which this tab extends behind.
        padding: const EdgeInsets.fromLTRB(_gutter, 20, _gutter, 140),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.chats,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    // Spacing pulls joined Arabic letters apart.
                    letterSpacing: hasArabic(context.l10n.chats) ? 0 : -0.8,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 1,
                shadowColor: Colors.black12,
                child: IconButton(
                  tooltip: context.l10n.newChat,
                  onPressed: _openNewChatSheet,
                  icon: const NewChatIcon(color: SynkColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FriendsSearchField(
            controller: _search,
            hint: context.l10n.searchChats,
            onChanged: (_) => setState(() {}),
          ),
          if (_chats.isLoading && !_chats.hasLoaded)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: CircularProgressIndicator(color: SynkColors.orangeDark),
              ),
            )
          else if (!_chats.hasLoaded && _chats.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: EmptyState(
                icon: Icons.cloud_off_rounded,
                title: context.l10n.weCouldntReachSynk,
                message: context.l10n.checkYourConnectionAndTryAgain,
                actionLabel: context.l10n.refresh,
                onAction: _chats.refresh,
              ),
            )
          else if (nothingYet)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: EmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: context.l10n.noChatsYet,
                message: context.l10n.chatsShowUpHere,
                actionLabel: context.l10n.messageAFriend,
                onAction: _openNewChatSheet,
              ),
            )
          else if (searching && activityChats.isEmpty && directChats.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: context.l10n.noChatsMatchYourSearch,
              ),
            )
          else ...[
            if (activityChats.isNotEmpty) ...[
              _SectionHeader(
                title: context.l10n.activityChats,
                trailing: context.l10n.activeChatsCount(activityChats.length),
              ),
              FriendsListCard(
                children: [for (final c in activityChats) tile(c)],
              ),
            ],
            if (directChats.isNotEmpty) ...[
              _SectionHeader(title: context.l10n.friends),
              FriendsListCard(children: [for (final c in directChats) tile(c)]),
            ],
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 24, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                // Spacing pulls joined Arabic letters apart.
                letterSpacing: hasArabic(title) ? 0 : 0.8,
                color: SynkColors.labelGrey,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SynkColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

// Friends you don't have a chat with yet, to start one.
class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet({required this.onPick});

  final ValueChanged<FriendUser> onPick;

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsController = FriendsController.instance;
    final chats = ChatController.instance;
    bool isNew(FriendUser friend) => chats.directChatWith(friend.id) == null;

    void openFindPeople() {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const FindPeopleView()),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ListenableBuilder(
        listenable: Listenable.merge([friendsController, chats]),
        builder: (context, _) {
          final friends = friendsController
              .searchFriends(_search.text)
              .where(isNew)
              .toList();
          final noFriends =
              friendsController.hasLoaded && friendsController.friends.isEmpty;
          final chattingWithAll =
              friendsController.hasLoaded &&
              !noFriends &&
              !friendsController.friends.any(isNew);

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SynkColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.messageAFriend,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              if (noFriends)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.people_alt_outlined,
                    title: context.l10n.noFriendsYet,
                    message: context.l10n.findPeopleYouKnow,
                    actionLabel: context.l10n.findPeople,
                    onAction: openFindPeople,
                  ),
                )
              else if (chattingWithAll)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.mark_chat_read_outlined,
                    title: context.l10n.youreChattingWithAllYourFriends,
                    message: context.l10n.findPeopleYouKnow,
                    actionLabel: context.l10n.findPeople,
                    onAction: openFindPeople,
                  ),
                )
              else ...[
                FriendsSearchField(
                  controller: _search,
                  hint: context.l10n.searchChats,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                if (!friendsController.hasLoaded)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: SynkColors.orangeDark,
                      ),
                    ),
                  )
                else if (friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: context.l10n.noFriendsMatchYourSearch,
                    ),
                  )
                else
                  FriendsListCard(
                    children: [
                      for (final friend in friends)
                        FriendsPersonRow(
                          user: friend,
                          onTap: () => widget.onPick(friend),
                          trailing: const Padding(
                            padding: EdgeInsetsDirectional.only(end: 6),
                            child: NewChatIcon(
                              size: 20,
                              color: SynkColors.orangeDark,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
