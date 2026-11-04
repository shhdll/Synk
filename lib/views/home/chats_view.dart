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
import 'chat_room_view.dart';
import 'find_people_view.dart';
import 'widgets/chat_list_tile.dart';
import 'widgets/empty_state.dart';
import 'widgets/friends_list_widgets.dart';
import '../widgets/synk_blob_background.dart';
import 'main_shell.dart';

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
  const NewChatIcon({
    super.key,
    required this.color,
    this.size = 24,
    this.plusColor = Colors.white,
  });

  final Color color;
  final double size;
  // Set it apart from a white [color], or the plus disappears.
  final Color plusColor;

  @override
  Widget build(BuildContext context) {
    // Both the bubble and the plus stay inside the box, so the icon
    // centres like any other icon.
    final badge = size * 0.46;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: size * 0.86,
              color: color,
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(
                Icons.add_rounded,
                size: badge * 0.85,
                color: plusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChatFilter { all, activities, friends }

// The Chat tab: activity group chats and friend chats in one list.
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
  _ChatFilter _filter = _ChatFilter.all;
  bool _searchOpen = false;

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

  void _closeSearch() => setState(() {
    _searchOpen = false;
    _search.clear();
  });

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
    // MainShell's bar is this page's bottom padding; clear it and its fade.
    final fabBottom = MediaQuery.paddingOf(context).bottom + 40;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: SynkBlobBackground()),
          SafeArea(
            bottom: false,
            // A tap outside the search field (not on a chat) closes it.
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _searchOpen ? _closeSearch : null,
              child: RefreshIndicator(
                color: SynkColors.orangeDark,
                backgroundColor: Colors.white,
                onRefresh: () {
                  unawaited(MainShell.checkAccount());
                  return _chats.refresh();
                },
                child: ListenableBuilder(
                  listenable: _chats,
                  builder: (context, _) => _buildList(fabBottom + 72),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            end: _gutter,
            bottom: fabBottom,
            child: FloatingActionButton(
              tooltip: context.l10n.newChat,
              onPressed: _openNewChatSheet,
              backgroundColor: SynkColors.orangeDark,
              elevation: 4,
              shape: const CircleBorder(),
              child: const NewChatIcon(
                color: Colors.white,
                plusColor: SynkColors.orangeDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(double bottomPadding) {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final showActivities = _filter != _ChatFilter.friends;
    final showFriends = _filter != _ChatFilter.activities;
    final activityChats = showActivities
        ? _matching(_chats.activityChats)
        : <ChatSummary>[];
    final directChats = showFriends
        ? _matching(_chats.directChats)
        : <ChatSummary>[];
    // Activities and friends in one list, latest message first.
    final mixed = [...activityChats, ...directChats]
      ..sort((a, b) => b.sortTime.compareTo(a.sortTime));
    final searching = _search.text.trim().isNotEmpty;
    final nothingYet =
        _chats.hasLoaded &&
        (!showActivities || _chats.activityChats.isEmpty) &&
        (!showFriends || _chats.directChats.isEmpty);

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
        // Bottom room for MainShell's bar and the new chat button.
        padding: EdgeInsets.fromLTRB(_gutter, 20, _gutter, bottomPadding),
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  // The search button opens a field in place of the title.
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [...previous, ?current],
                    ),
                    child: _searchOpen
                        ? FriendsSearchField(
                            key: const ValueKey('search'),
                            controller: _search,
                            hint: context.l10n.searchChats,
                            autofocus: true,
                            borderRadius: 24,
                            onChanged: (_) => setState(() {}),
                          )
                        // Shrinks to stay on one line beside the button.
                        : FittedBox(
                            key: const ValueKey('title'),
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              context.l10n.catchUpWithFriends,
                              maxLines: 1,
                              // Matches the Activities tab title.
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: SynkColors.textPrimary,
                              ),
                            ),
                          ),
                  ),
                ),
                if (!_searchOpen) ...[
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 1,
                    shadowColor: Colors.black12,
                    child: IconButton(
                      tooltip: context.l10n.searchChats,
                      onPressed: () => setState(() => _searchOpen = true),
                      icon: const Icon(
                        Icons.search_rounded,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _FilterTabs(
            selected: _filter,
            onChanged: (filter) => setState(() => _filter = filter),
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
                actionLabel: showFriends ? context.l10n.messageAFriend : null,
                onAction: showFriends ? _openNewChatSheet : null,
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
            const SizedBox(height: 20),
            FriendsListCard(
              padding: EdgeInsets.zero,
              children: [for (final c in mixed) tile(c)],
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onChanged});

  final _ChatFilter selected;
  final ValueChanged<_ChatFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 220);

    Widget segment(String label, _ChatFilter filter) {
      final isSelected = selected == filter;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(filter),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: duration,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : SynkColors.textSecondary,
              ),
              child: Text(label),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: StadiumBorder(),
      ),
      child: Stack(
        children: [
          // The orange oval slides under the selected label.
          AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional(selected.index - 1.0, 0),
            child: const FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: SynkColors.orangeDark,
                  shape: StadiumBorder(),
                ),
              ),
            ),
          ),
          Row(
            children: [
              segment(context.l10n.all, _ChatFilter.all),
              segment(context.l10n.activities, _ChatFilter.activities),
              segment(context.l10n.friends, _ChatFilter.friends),
            ],
          ),
        ],
      ),
    );
  }
}

// All friends; ones you already chat with are marked and open that chat.
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
    bool hasChat(FriendUser friend) => chats.directChatWith(friend.id) != null;

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
          final friends = friendsController.searchFriends(_search.text);
          final noFriends =
              friendsController.hasLoaded && friendsController.friends.isEmpty;

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
                    actionLabel: context.l10n.findPeople,
                    onAction: openFindPeople,
                  ),
                )
              else ...[
                FriendsSearchField(
                  controller: _search,
                  hint: context.l10n.searchFriends,
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
                          trailing: hasChat(friend)
                              ? const _HasChatTag()
                              : const SizedBox.square(
                                  dimension: 40,
                                  child: Center(
                                    child: NewChatIcon(
                                      size: 22,
                                      color: SynkColors.orangeDark,
                                    ),
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

// On a friend you already have a chat with.
class _HasChatTag extends StatelessWidget {
  const _HasChatTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SynkColors.textSecondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        context.l10n.openChat,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: SynkColors.textSecondary,
        ),
      ),
    );
  }
}
