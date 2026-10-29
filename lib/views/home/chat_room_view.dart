import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/chat_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/chat_model.dart';
import '../../models/friends_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../../utils/text_direction.dart';
import 'activity_notification_route.dart';
import 'widgets/activity_thumbnail.dart';
import 'widgets/chat_list_tile.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/discovery_activity_card.dart';
import 'widgets/friend_options_sheet.dart';
import 'widgets/user_avatar.dart';

// [activityStore] lets an activity chat's title open the activity in the
// Activities tab; without it the activity opens on its own page.
Future<void> openChatRoom(
  BuildContext context,
  ChatSummary chat, {
  ActivityStore? activityStore,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ChatRoomView(chat: chat, activityStore: activityStore),
    ),
  );
}

// One conversation: an activity's group chat or a chat with a friend.
// New messages arrive live while the screen is open.
class ChatRoomView extends StatefulWidget {
  const ChatRoomView({super.key, required this.chat, this.activityStore});

  final ChatSummary chat;
  final ActivityStore? activityStore;

  @override
  State<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends State<ChatRoomView> {
  final ChatController _chats = ChatController.instance;
  final TextEditingController _input = TextEditingController();

  ChatModel get _model => _chats.model;

  List<ChatMessage> _messages = [];
  Map<String, FriendUser> _members = {};
  RealtimeChannel? _channel;
  bool _isLoading = true;
  bool _failed = false;
  bool _isSending = false;

  // Temporary links for photo messages, keyed by storage path.
  Map<String, String> _photoLinks = {};

  // Friend chats: interests you both have, shown before the first message.
  List<String> _sharedInterests = const [];

  String? get _me => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _channel = _model.listenForMessages(widget.chat.id, _onMessage);
    _load();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) unawaited(_model.removeChannel(channel));
    unawaited(_chats.markRead(widget.chat.id));
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object>([
        _model.fetchMessages(widget.chat.id),
        _model.fetchMembers(widget.chat.id),
      ]);
      if (!mounted) return;
      final loaded = results[0] as List<ChatMessage>;
      setState(() {
        // Keeps anything realtime delivered while this was loading.
        final ids = loaded.map((m) => m.id).toSet();
        _messages = [...loaded, ..._messages.where((m) => !ids.contains(m.id))]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _members = {for (final u in results[1] as List<FriendUser>) u.id: u};
        _isLoading = false;
        _failed = false;
      });
      unawaited(_chats.markRead(widget.chat.id));
      unawaited(_loadPhotoLinks(_messages));
      if (_messages.isEmpty) unawaited(_loadSharedInterests());
    } catch (error) {
      debugPrint('SYNK: chat failed to load: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _failed = true;
        });
      }
    }
  }

  void _onMessage(ChatMessage message) {
    if (!mounted || _messages.any((m) => m.id == message.id)) return;
    setState(() => _messages = [..._messages, message]);
    unawaited(_chats.markRead(widget.chat.id));
    unawaited(_loadPhotoLinks([message]));
    // Someone who joined after the chat opened.
    final sender = message.senderId;
    if (sender != null && !_members.containsKey(sender)) {
      unawaited(_reloadMembers());
    }
  }

  Future<void> _loadPhotoLinks(List<ChatMessage> messages) async {
    final paths = [
      for (final m in messages)
        if (m.hasPhoto && !_photoLinks.containsKey(m.imagePath)) m.imagePath!,
    ];
    if (paths.isEmpty) return;
    try {
      final links = await _model.photoLinks(paths);
      if (mounted) setState(() => _photoLinks = {..._photoLinks, ...links});
    } catch (error) {
      debugPrint('SYNK: photo links failed to load: $error');
    }
  }

  Future<void> _loadSharedInterests() async {
    final me = _me;
    final friendId = widget.chat.otherUser?.id;
    if (me == null || friendId == null) return;
    try {
      final interests = await _model.fetchInterests([me, friendId]);
      final theirs = (interests[friendId] ?? const []).toSet();
      final shared = (interests[me] ?? const [])
          // Says nothing about what you have in common.
          .where((i) => i != 'Open to Anything' && theirs.contains(i))
          .toList();
      if (mounted) setState(() => _sharedInterests = shared);
    } catch (error) {
      debugPrint('SYNK: interests failed to load: $error');
    }
  }

  Future<void> _reloadMembers() async {
    try {
      final members = await _model.fetchMembers(widget.chat.id);
      if (!mounted) return;
      setState(() => _members = {for (final u in members) u.id: u});
    } catch (_) {
      // Unknown senders show without a name until the next load.
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _isSending) return;
    if (await _deliver(text: text)) _input.clear();
  }

  Future<void> _sendPhoto() async {
    if (_isSending) return;
    final XFile? file;
    try {
      file = await _model.pickPhoto();
    } catch (error) {
      debugPrint('SYNK: photo picker failed: $error');
      return;
    }
    if (file == null || !mounted) return;
    await _deliver(photo: file);
  }

  // Sends text or a photo; true when it was sent.
  Future<bool> _deliver({String text = '', XFile? photo}) async {
    setState(() => _isSending = true);
    var result = '';
    ChatMessage? sent;
    try {
      final imagePath = photo == null
          ? null
          : await _model.uploadPhoto(widget.chat.id, photo);
      (:result, message: sent) = await _model.send(
        widget.chat.id,
        text,
        imagePath: imagePath,
      );
    } catch (error) {
      debugPrint('SYNK: message failed to send: $error');
    }
    if (!mounted) return false;

    setState(() => _isSending = false);
    if (result == 'finished') {
      SynkFeedback.showToast(
        context,
        title: context.l10n.chatClosed,
        message: context.l10n.chatClosedActivityFinished,
        success: false,
      );
      unawaited(_chats.refresh());
      Navigator.pop(context);
      return false;
    }
    if (sent == null) {
      SynkFeedback.showToast(
        context,
        title: context.l10n.messageNotSent,
        message: widget.chat.isActivity
            ? null
            : context.l10n.canOnlyMessageFriends,
        success: false,
      );
      return false;
    }
    _onMessage(sent);
    unawaited(_chats.refresh());
    return true;
  }

  // Shows the activity over the chat; closing it comes back here.
  Future<void> _openActivity() async {
    final activityId = widget.chat.activity?.id;
    if (activityId == null) return;
    final store = widget.activityStore;

    if (store == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ActivityNotificationRoute(activityId: activityId),
        ),
      );
      await _closeIfNoLongerMember();
      return;
    }

    Activity? activity = store.byId(activityId);
    if (activity == null) {
      try {
        activity = await ActivitiesModel().fetchById(activityId);
      } catch (error) {
        debugPrint('SYNK: activity failed to load: $error');
      }
    }
    if (!mounted) return;
    if (activity == null) {
      SynkFeedback.showToast(
        context,
        title: context.l10n.thisActivityIsNoLongerAvailable,
        success: false,
      );
      return;
    }
    await showActivityDetailsSheet(
      context: context,
      activity: activity,
      activityStore: store,
    );
    await _closeIfNoLongerMember();
  }

  // Leaving the activity from its sheet also takes you out of its chat.
  Future<void> _closeIfNoLongerMember() async {
    await _chats.refresh();
    if (!mounted || !_chats.hasLoaded || _chats.error != null) return;
    if (_chats.byId(widget.chat.id) == null) Navigator.pop(context);
  }

  void _openProfile(FriendUser user) {
    if (user.id == _me) return;
    openFriendProfile(
      context,
      user,
      // You're already in your chat with them.
      showMessageButton: user.id != widget.chat.otherUser?.id,
    );
  }

  // "Shahad, Reem, You": everyone in the chat, you last.
  String _memberNames() {
    final others = _members.values
        .where((u) => u.id != _me)
        .map((u) => u.name.split(' ').first)
        .where((name) => name.isNotEmpty);
    return [
      ...others.map(bidiIsolate),
      if (_members.containsKey(_me)) context.l10n.you,
    ].join(context.l10n.listSeparator);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      appBar: AppBar(
        backgroundColor: SynkColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SynkColors.textPrimary,
          ),
        ),
        title: _buildTitle(),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    final chat = widget.chat;
    final activity = chat.activity;
    final friend = chat.otherUser;
    // The member count until the names have loaded.
    final subtitle = activity != null
        ? (_members.isEmpty
              ? context.l10n.membersCount(chat.memberCount)
              : _memberNames())
        : (friend?.username?.isNotEmpty ?? false)
        ? '@${friend!.username}'
        : null;

    final title = Row(
      children: [
        if (activity != null)
          ActivityThumbnail(activity: activity, size: 40, radius: 12)
        else
          UserAvatar(
            avatarUrl: friend?.avatarUrl,
            gender: friend?.gender,
            size: 40,
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chat.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SynkColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    if (activity == null && friend == null) return title;
    return Semantics(
      button: true,
      hint: activity != null
          ? context.l10n.viewActivity
          : context.l10n.viewProfile,
      child: InkWell(
        onTap: activity != null ? _openActivity : () => _openProfile(friend!),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: title,
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: SynkColors.orangeDark),
      );
    }
    if (_failed && _messages.isEmpty) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() => _isLoading = true);
            _load();
          },
          child: Text(context.l10n.retry),
        ),
      );
    }
    if (_messages.isEmpty) return _buildEmptyState();

    // Newest at the bottom, and the list starts there.
    final messages = _messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final older = index + 1 < messages.length ? messages[index + 1] : null;
        final newer = index > 0 ? messages[index - 1] : null;
        final newDay =
            older == null ||
            !DateUtils.isSameDay(older.createdAt, message.createdAt);
        // Consecutive messages from one person are grouped under one name.
        final firstInGroup = newDay || older.senderId != message.senderId;
        final lastInGroup =
            newer == null ||
            newer.senderId != message.senderId ||
            !DateUtils.isSameDay(newer.createdAt, message.createdAt);

        return Column(
          children: [
            if (newDay) _DayDivider(date: message.createdAt),
            _MessageBubble(
              message: message,
              sender: _members[message.senderId],
              isMine: message.senderId == _me,
              showSender: widget.chat.isActivity && firstInGroup,
              showAvatar: widget.chat.isActivity && lastInGroup,
              isGroupChat: widget.chat.isActivity,
              photoLink: _photoLinks[message.imagePath],
              onSenderTap: _openProfile,
            ),
          ],
        );
      },
    );
  }

  // Before the first message: who or what the chat is about.
  Widget _buildEmptyState() {
    final chat = widget.chat;
    final summaryActivity = chat.activity;
    // The loaded activity has the location; the chat summary doesn't.
    final activity = summaryActivity == null
        ? null
        : widget.activityStore?.byId(summaryActivity.id) ?? summaryActivity;
    final friend = chat.otherUser;

    final String title;
    final String? detail;
    final String? message;
    final Widget picture;

    if (activity != null) {
      picture = ActivityThumbnail(activity: activity, size: 96, radius: 28);
      title = context.l10n.planActivityTogether(bidiIsolate(activity.title));
      detail = [
        DiscoveryActivityCard.formatWhen(activity.dateTime),
        if (activity.location.trim().isNotEmpty) activity.location.trim(),
      ].join(' · ');
      message = context.l10n.sortOutTheDetails;
    } else {
      picture = Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: UserAvatar(
          avatarUrl: friend?.avatarUrl,
          gender: friend?.gender,
          size: 96,
        ),
      );
      final firstName = (friend?.name ?? '').split(' ').first;
      title = context.l10n.sayHiToName(bidiIsolate(firstName));
      detail = null;
      message = _sharedInterests.isEmpty
          ? null
          : context.l10n.youBothLike(_joinInterests(_sharedInterests));
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            picture,
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.orangeDark,
                ),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: SynkColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // "Board Games, Hiking and Movies", at most three.
  String _joinInterests(List<String> interests) {
    final labels = interests.take(3).map(valueLabel).toList();
    if (labels.length == 1) return labels.first;
    return context.l10n.listAnd(
      labels.sublist(0, labels.length - 1).join(context.l10n.listSeparator),
      labels.last,
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton.filled(
              tooltip: context.l10n.sendAPhoto,
              onPressed: _isSending ? null : _sendPhoto,
              style: IconButton.styleFrom(
                backgroundColor: SynkColors.textSecondary.withValues(
                  alpha: 0.12,
                ),
                disabledBackgroundColor: SynkColors.textSecondary.withValues(
                  alpha: 0.06,
                ),
                foregroundColor: SynkColors.textPrimary,
                fixedSize: const Size(46, 46),
              ),
              icon: const Icon(Icons.add_rounded, size: 26),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ListenableBuilder(
                listenable: _input,
                builder: (context, _) => TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  textDirection: textDirectionOf(_input.text),
                  style: const TextStyle(
                    fontSize: 15,
                    color: SynkColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: context.l10n.messageHint,
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: SynkColors.textSecondary.withValues(alpha: 0.14),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                        color: SynkColors.textSecondary.withValues(alpha: 0.14),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: SynkColors.orange),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            ListenableBuilder(
              listenable: _input,
              builder: (context, _) {
                final canSend = _input.text.trim().isNotEmpty && !_isSending;
                return IconButton.filled(
                  tooltip: context.l10n.send,
                  onPressed: canSend ? _send : null,
                  style: IconButton.styleFrom(
                    backgroundColor: SynkColors.orangeDark,
                    disabledBackgroundColor: SynkColors.orangeDark.withValues(
                      alpha: 0.35,
                    ),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    fixedSize: const Size(46, 46),
                  ),
                  icon: _isSending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Shows a chat photo full screen; pinch to zoom, tap to close.
Future<void> _showPhoto(BuildContext context, String link) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(dialogContext).pop(),
      child: SafeArea(
        child: InteractiveViewer(
          maxScale: 4,
          child: Center(child: Image.network(link, fit: BoxFit.contain)),
        ),
      ),
    ),
  );
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.isSameDay(date, DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        today ? context.l10n.today : formatChatTime(date),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: SynkColors.textSecondary,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.sender,
    required this.isMine,
    required this.showSender,
    required this.showAvatar,
    required this.isGroupChat,
    this.photoLink,
    this.onSenderTap,
  });

  final ChatMessage message;
  final FriendUser? sender;
  final bool isMine;
  final bool showSender;
  final bool showAvatar;
  final bool isGroupChat;

  // Null until the photo's link has loaded.
  final String? photoLink;

  // Opens the sender's profile from their photo.
  final ValueChanged<FriendUser>? onSenderTap;

  static const double _avatarSize = 28;
  static const double _photoSize = 220;

  Widget _buildPhoto(BuildContext context) {
    final link = photoLink;
    final placeholder = Container(
      width: _photoSize,
      height: _photoSize,
      color: isMine
          ? Colors.white.withValues(alpha: 0.18)
          : SynkColors.backgroundLight,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 32,
        color: isMine ? Colors.white : SynkColors.textSecondary,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: link == null
          ? placeholder
          : GestureDetector(
              onTap: () => _showPhoto(context, link),
              child: Image.network(
                link,
                width: _photoSize,
                height: _photoSize,
                fit: BoxFit.cover,
                semanticLabel: context.l10n.photo,
                frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
                    wasSynchronouslyLoaded || frame != null
                    ? child
                    : placeholder,
                errorBuilder: (_, _, _) => placeholder,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: message.hasPhoto
          ? const EdgeInsets.fromLTRB(4, 4, 4, 6)
          : const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: isMine ? SynkColors.orangeDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: isMine
            ? null
            : Border.all(
                color: SynkColors.textSecondary.withValues(alpha: 0.10),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.hasPhoto) _buildPhoto(context),
          if (message.body.isNotEmpty)
            Padding(
              padding: message.hasPhoto
                  ? const EdgeInsets.fromLTRB(8, 6, 8, 0)
                  : EdgeInsets.zero,
              child: Text(
                message.body,
                textDirection: textDirectionOf(message.body),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  color: isMine ? Colors.white : SynkColors.textPrimary,
                ),
              ),
            ),
          const SizedBox(height: 2),
          Padding(
            padding: message.hasPhoto
                ? const EdgeInsetsDirectional.only(end: 8)
                : EdgeInsets.zero,
            child: Text(
              formatTime(message.createdAt.hour, message.createdAt.minute),
              style: TextStyle(
                fontSize: 10.5,
                color: isMine
                    ? Colors.white.withValues(alpha: 0.8)
                    : SynkColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    if (isMine) {
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Align(alignment: AlignmentDirectional.centerEnd, child: bubble),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isGroupChat) ...[
            showAvatar
                ? GestureDetector(
                    onTap: sender == null || onSenderTap == null
                        ? null
                        : () => onSenderTap!(sender!),
                    child: UserAvatar(
                      avatarUrl: sender?.avatarUrl,
                      gender: sender?.gender,
                      size: _avatarSize,
                    ),
                  )
                : const SizedBox(width: _avatarSize),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSender && sender != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 12,
                      bottom: 3,
                      top: 6,
                    ),
                    child: Text(
                      sender!.name,
                      textDirection: textDirectionOf(sender!.name),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SynkColors.tealText,
                      ),
                    ),
                  ),
                bubble,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
