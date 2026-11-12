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

enum ChatAttachment { photo, camera, location, activity, contact, poll }

// The chat's + options, shown where the keyboard would be like WhatsApp.
// In the app's own style: a white rounded card on the beige background, a
// pale circle in a Synk colour with a deeper icon, a label under each.
class AttachmentPanel extends StatelessWidget {
  const AttachmentPanel({super.key, required this.onPick, this.height = 290});

  final ValueChanged<ChatAttachment> onPick;

  // Fixed, like the keyboard it replaces; scrolls if large text needs more.
  final double height;

  // The pink from SynkColors, deep enough to read as an icon.
  static const _pinkDeep = Color(0xFFD9578A);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = [
      (
        ChatAttachment.photo,
        Icons.photo_library_rounded,
        l10n.photos,
        SynkColors.orangeDark,
      ),
      (
        ChatAttachment.camera,
        Icons.photo_camera_rounded,
        l10n.camera,
        _pinkDeep,
      ),
      (
        ChatAttachment.location,
        Icons.location_on_rounded,
        l10n.sendLocation,
        SynkColors.tealText,
      ),
      (
        ChatAttachment.contact,
        Icons.person_rounded,
        l10n.friendAccount,
        SynkColors.beigeDark,
      ),
      (ChatAttachment.poll, Icons.poll_rounded, l10n.poll, SynkColors.teal),
      (
        ChatAttachment.activity,
        Icons.event_rounded,
        l10n.sendActivity,
        SynkColors.orangeDeep,
      ),
    ];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        height: height,
        color: SynkColors.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: SynkColors.textSecondary.withValues(alpha: 0.10),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Three to a row.
                final width = constraints.maxWidth / 3;
                return Wrap(
                  runSpacing: 14,
                  children: [
                    for (final (value, icon, label, color) in options)
                      SizedBox(
                        width: width,
                        child: _AttachmentOption(
                          icon: icon,
                          label: label,
                          color: color,
                          onTap: () => onPick(value),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 27, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SynkColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
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

// One of your friends, to share their account in a chat. [exclude] leaves
// people out, e.g. the friend you're already chatting with.
Future<FriendUser?> showFriendPickerSheet(
  BuildContext context, {
  Set<String> exclude = const {},
}) {
  unawaited(FriendsController.instance.refresh());
  return showModalBottomSheet<FriendUser>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SynkColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _FriendPickerSheet(exclude: exclude),
  );
}

class _FriendPickerSheet extends StatefulWidget {
  const _FriendPickerSheet({required this.exclude});

  final Set<String> exclude;

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = FriendsController.instance;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scrollController) => ListenableBuilder(
        listenable: friends,
        builder: (context, _) {
          final list = friends
              .searchFriends(_search.text)
              .where((f) => !widget.exclude.contains(f.id))
              .toList();
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              const _Handle(),
              const SizedBox(height: 16),
              Text(
                context.l10n.shareAFriend,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              FriendsSearchField(
                controller: _search,
                hint: context.l10n.searchFriends,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              if (!friends.hasLoaded)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: SynkColors.orangeDark,
                    ),
                  ),
                )
              else if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: context.l10n.noFriendsToShare,
                  ),
                )
              else
                FriendsListCard(
                  children: [
                    for (final friend in list)
                      InkWell(
                        onTap: () => Navigator.pop(context, friend),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                avatarUrl: friend.avatarUrl,
                                gender: friend.gender,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FriendsNameAndSubtitle(
                                  name: friend.name,
                                  subtitle:
                                      (friend.username?.isNotEmpty ?? false)
                                      ? '@${friend.username}'
                                      : null,
                                ),
                              ),
                            ],
                          ),
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
          // Only chats you can still send to: open activity chats and
          // current friends. Removed or blocked friends are left out.
          final friendIds = {for (final f in friends.friends) f.id};
          final chatRows = [
            ...chats.activityChats.where((c) => !c.isClosed),
            ...chats.directChats.where(
              (c) =>
                  !c.isUnfriended &&
                  (!friends.hasLoaded || friendIds.contains(c.otherUser?.id)),
            ),
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
