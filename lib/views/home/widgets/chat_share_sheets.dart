import 'dart:async';

import 'package:flutter/material.dart';

import '../../../controllers/chat_controller.dart';
import '../../../controllers/friends_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activities_model.dart';
import '../../../models/activity_model.dart';
import '../../../models/chat_model.dart';
import '../../../models/friends_model.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';
import '../../../utils/share_activity.dart';
import 'activity_thumbnail.dart';
import 'discovery_activity_card.dart';
import 'empty_state.dart';
import 'friends_list_widgets.dart';
import 'user_avatar.dart';

// Sheets for sending things other than text in a chat: the + menu, picking
// an activity, and sharing an activity into chats from its details.

enum ChatAttachment { photo, camera, location, activity }

// The chat's + button: what to send, in a menu that opens upward from
// [anchor], the button's rect on screen.
Future<ChatAttachment?> showAttachmentMenu(BuildContext context, Rect anchor) {
  return showGeneralDialog<ChatAttachment>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    // Keeps the keyboard up, so the + button stays under the menu.
    requestFocus: false,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (menuContext, _, _) {
      final l10n = menuContext.l10n;
      final screen = MediaQuery.sizeOf(menuContext);
      final isRtl = Directionality.of(menuContext) == TextDirection.rtl;

      // Each option gets its own color: a pale circle, a deeper icon.
      Widget option(
        ChatAttachment value,
        IconData icon,
        String label,
        Color color,
      ) {
        return InkWell(
          onTap: () => Navigator.pop(menuContext, value),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 20, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Stack(
        children: [
          Positioned(
            left: isRtl ? null : anchor.left,
            right: isRtl ? screen.width - anchor.right : null,
            bottom: screen.height - anchor.top + 8,
            child: Material(
              color: Colors.white,
              elevation: 8,
              shadowColor: Colors.black26,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      option(
                        ChatAttachment.activity,
                        Icons.event_outlined,
                        l10n.sendActivity,
                        SynkColors.orangeDeep,
                      ),
                      option(
                        ChatAttachment.location,
                        Icons.location_on_outlined,
                        l10n.sendLocation,
                        SynkColors.tealText,
                      ),
                      option(
                        ChatAttachment.camera,
                        Icons.photo_camera_outlined,
                        l10n.camera,
                        const Color(0xFFC2416F),
                      ),
                      option(
                        ChatAttachment.photo,
                        Icons.photo_library_outlined,
                        l10n.photos,
                        const Color(0xFF3F64C8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    // Grows up out of the + button.
    transitionBuilder: (menuContext, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
          alignment: Alignment(
            (anchor.center.dx / MediaQuery.sizeOf(menuContext).width) * 2 - 1,
            (anchor.top / MediaQuery.sizeOf(menuContext).height) * 2 - 1,
          ),
          child: child,
        ),
      );
    },
  );
}

// Your upcoming activities, then other upcoming ones from the Home feed.
// Uses [store] when the chat has it, otherwise loads them.
Future<Activity?> showActivityPickerSheet(
  BuildContext context, {
  ActivityStore? store,
}) {
  return showModalBottomSheet<Activity>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SynkColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ActivityPickerSheet(store: store),
  );
}

class _ActivityPickerSheet extends StatefulWidget {
  const _ActivityPickerSheet({this.store});

  final ActivityStore? store;

  @override
  State<_ActivityPickerSheet> createState() => _ActivityPickerSheetState();
}

class _ActivityPickerSheetState extends State<_ActivityPickerSheet> {
  List<Activity>? _activities;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final store = widget.store;
    List<Activity> personal;
    List<Activity> feed;
    if (store != null) {
      personal = store.all;
      feed = store.feed;
    } else {
      final model = ActivitiesModel();
      try {
        final results = await Future.wait([
          model.fetchMine(),
          model.fetchParticipating(),
          model.fetchPublicFeed(),
        ]);
        personal = [...results[0], ...results[1]];
        feed = results[2];
      } catch (error) {
        debugPrint('SYNK: activities failed to load: $error');
        personal = const [];
        feed = const [];
      }
    }

    // Pending requests aren't yours to share yet.
    final mine = personal.where((a) => !a.isPast && !a.isPending).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final ids = mine.map((a) => a.id).toSet();
    final others = feed.where((a) => !a.isPast && !ids.contains(a.id)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    if (mounted) setState(() => _activities = [...mine, ...others]);
  }

  @override
  Widget build(BuildContext context) {
    final activities = _activities;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const _Handle(),
          const SizedBox(height: 16),
          Text(
            context.l10n.shareAnActivity,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: SynkColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (activities == null)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: CircularProgressIndicator(color: SynkColors.orangeDark),
              ),
            )
          else if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: EmptyState(
                icon: Icons.event_busy_rounded,
                title: context.l10n.noUpcomingActivitiesToShare,
                message: context.l10n.joinOrCreateToShare,
              ),
            )
          else
            FriendsListCard(
              children: [
                for (final activity in activities)
                  _ActivityRow(
                    activity: activity,
                    onTap: () => Navigator.pop(context, activity),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// Sends [activity] into chats, picked from your chats and friends you don't
// have a chat with yet. The sheet stays open so it can go to several.
Future<void> showShareToChatSheet(BuildContext context, Activity activity) {
  unawaited(ChatController.instance.refresh());
  unawaited(FriendsController.instance.refresh());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SynkColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ShareToChatSheet(activity: activity),
  );
}

class _ShareToChatSheet extends StatefulWidget {
  const _ShareToChatSheet({required this.activity});

  final Activity activity;

  @override
  State<_ShareToChatSheet> createState() => _ShareToChatSheetState();
}

class _ShareToChatSheetState extends State<_ShareToChatSheet> {
  final TextEditingController _search = TextEditingController();

  // Keyed by chat id, or by user id for friends without a chat yet.
  final Set<String> _sending = {};
  final Set<String> _sent = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _send(String key, Future<String?> Function() chatId) async {
    setState(() => _sending.add(key));
    var result = '';
    try {
      final id = await chatId();
      if (id != null) {
        (:result, message: _) = await ChatController.instance.model.send(
          id,
          '',
          activityId: widget.activity.id,
        );
      }
    } catch (error) {
      debugPrint('SYNK: sharing activity failed: $error');
    }
    if (!mounted) return;
    setState(() {
      _sending.remove(key);
      if (result == 'sent') _sent.add(key);
    });
    if (result == 'sent') {
      unawaited(ChatController.instance.refresh());
      return;
    }
    SynkFeedback.showToast(
      context,
      title: result == 'not_visible_to_all'
          ? context.l10n.activityNotVisibleToAll
          : context.l10n.messageNotSent,
      success: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chats = ChatController.instance;
    final friends = FriendsController.instance;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ListenableBuilder(
        listenable: Listenable.merge([chats, friends]),
        builder: (context, _) {
          final q = _search.text.trim().toLowerCase();
          bool matches(String text) => text.toLowerCase().contains(q);
          final chatRows = [
            ...chats.activityChats,
            ...chats.directChats,
          ].where((c) => q.isEmpty || matches(c.title)).toList();
          final newFriends = friends
              .searchFriends(_search.text)
              .where((f) => chats.directChatWith(f.id) == null)
              .toList();

          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const _Handle(),
              const SizedBox(height: 16),
              Text(
                context.l10n.share,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              // Outside Synk: the phone's share menu with a link.
              Builder(
                builder: (buttonContext) => Material(
                  color: SynkColors.orangeDark.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () =>
                        shareActivityLink(buttonContext, widget.activity),
                    borderRadius: BorderRadius.circular(14),
                    // Same height as the search field below it.
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            size: 20,
                            color: SynkColors.orangeDark,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.l10n.shareLink,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: SynkColors.orangeDark,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.ios_share_rounded,
                            size: 18,
                            color: SynkColors.orangeDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                thickness: 1,
                color: SynkColors.textSecondary.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 16),
              FriendsSearchField(
                controller: _search,
                hint: context.l10n.searchChats,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              if (!chats.hasLoaded && !friends.hasLoaded)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: SynkColors.orangeDark,
                    ),
                  ),
                )
              else if (chatRows.isEmpty && newFriends.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: q.isEmpty
                        ? context.l10n.noChatsYet
                        : context.l10n.noChatsMatchYourSearch,
                  ),
                )
              else
                FriendsListCard(
                  children: [
                    for (final chat in chatRows)
                      _ShareTargetRow(
                        picture: _chatPicture(chat),
                        title: chat.title,
                        sending: _sending.contains(chat.id),
                        sent: _sent.contains(chat.id),
                        onSend: () => _send(chat.id, () async => chat.id),
                      ),
                    for (final friend in newFriends)
                      _ShareTargetRow(
                        picture: UserAvatar(
                          avatarUrl: friend.avatarUrl,
                          gender: friend.gender,
                        ),
                        title: friend.name,
                        sending: _sending.contains(friend.id),
                        sent: _sent.contains(friend.id),
                        onSend: () => _send(
                          friend.id,
                          () => chats.openDirectChat(friend.id),
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _chatPicture(ChatSummary chat) {
    final activity = chat.activity;
    if (activity != null) {
      return ActivityThumbnail(activity: activity, size: 44, radius: 12);
    }
    final FriendUser? friend = chat.otherUser;
    return UserAvatar(avatarUrl: friend?.avatarUrl, gender: friend?.gender);
  }
}

class _ShareTargetRow extends StatelessWidget {
  const _ShareTargetRow({
    required this.picture,
    required this.title,
    required this.sending,
    required this.sent,
    required this.onSend,
  });

  final Widget picture;
  final String title;
  final bool sending;
  final bool sent;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
      child: Row(
        children: [
          picture,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SynkColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (sent)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: SynkColors.tealText,
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.sent,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SynkColors.tealText,
                  ),
                ),
              ],
            )
          else
            FilledButton(
              onPressed: sending ? null : onSend,
              style: FilledButton.styleFrom(
                backgroundColor: SynkColors.orangeLight,
                foregroundColor: SynkColors.orangeDeep,
                disabledBackgroundColor: SynkColors.orangeLight,
                minimumSize: const Size(72, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: sending
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SynkColors.orangeDeep,
                      ),
                    )
                  : Text(context.l10n.send),
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.onTap});

  final Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            ActivityThumbnail(activity: activity, size: 48, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: FriendsNameAndSubtitle(
                name: activity.title,
                subtitle: [
                  DiscoveryActivityCard.formatWhen(activity.dateTime),
                  if (activity.location.trim().isNotEmpty)
                    activity.location.trim(),
                ].join(' · '),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: SynkColors.textSecondary.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
