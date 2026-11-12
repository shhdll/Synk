import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/chat_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/chat_model.dart';
import '../../models/friends_model.dart';
import '../../models/place_search_model.dart';
import '../../utils/custom_widgets/synk_dialog.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../../utils/emoji_only.dart';
import '../../utils/maps_launcher.dart';
import '../../utils/text_direction.dart';
import '../create_activity/location_search_sheet.dart';
import 'activity_notification_route.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/activity_thumbnail.dart';
import 'widgets/chat_list_tile.dart';
import 'widgets/chat_poll.dart';
import 'widgets/chat_share_sheets.dart';
import 'widgets/chat_stickers.dart';
import 'widgets/chat_view_once.dart';
import 'widgets/chat_voice.dart';
import 'widgets/discovery_activity_card.dart';
import 'widgets/friend_options_sheet.dart';
import 'widgets/user_avatar.dart';
import '../widgets/chat_wallpaper.dart';
import '../widgets/default_avatar.dart';

// [activityStore] lets activities open over the chat with the app's own
// activity data; without it they open on their own page.
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

// Asks first, then deletes the chat for you only. True when it was deleted.
Future<bool> confirmDeleteChat(BuildContext context, ChatSummary chat) async {
  final delete = await SynkDialog.confirm(
    context,
    icon: Icons.delete_outline_rounded,
    title: context.l10n.deleteThisChat,
    message: context.l10n.chatDeletedOnlyForYou,
    action: context.l10n.deleteLabel,
  );
  if (!delete || !context.mounted) return false;

  final ok = await ChatController.instance.deleteChatForMe(chat.id);
  if (!context.mounted) return ok;
  if (ok) {
    SynkFeedback.showToast(context, title: context.l10n.chatDeleted);
  } else {
    SynkFeedback.showError(
      context,
      context.l10n.somethingWentWrongPleaseTryAgain,
    );
  }
  return ok;
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
  final FocusNode _inputFocus = FocusNode();

  ChatModel get _model => _chats.model;

  List<ChatMessage> _messages = [];
  Map<String, FriendUser> _members = {};
  RealtimeChannel? _channel;
  RealtimeChannel? _readsChannel;

  // How far each member has read, for "Seen".
  Map<String, ChatReadState> _reads = {};
  bool _isLoading = true;
  bool _failed = false;
  bool _isSending = false;

  // The server said the activity chat is closed.
  bool _closed = false;

  // The server said you're no longer friends.
  bool _unfriended = false;

  // The message the next one replies to, shown above the input.
  ChatMessage? _replyingTo;

  // Temporary links for photo messages, keyed by storage path.
  Map<String, String> _photoLinks = {};

  // Friend chats: interests you both have, shown before the first message.
  List<String> _sharedInterests = const [];

  // Poll votes and who has listened to each voice message.
  ChatMessageExtras _extras = const ChatMessageExtras();
  RealtimeChannel? _extrasChannel;
  Timer? _extrasReload;

  // The sticker grid or the + options, open where the keyboard would be.
  _ComposerPanel _panel = _ComposerPanel.none;
  bool get _showStickers => _panel == _ComposerPanel.stickers;
  bool get _showAttachments => _panel == _ComposerPanel.attachments;

  // Voice messages: hold the mic to record, slide toward the start to
  // cancel, let go to send.
  static const double _cancelDistance = 110;

  // Slide up this far to lock, so you can let go and keep recording.
  static const double _lockDistance = 90;
  bool _locked = false;
  double _lift = 0;

  // The locked recording's ① toggle.
  bool _voiceViewOnce = false;

  // View-once messages opened this visit: a voice one stays playable until
  // you leave the chat. [_openingViewOnce] is the one being opened now.
  final Set<String> _openedNow = {};
  String? _openingViewOnce;
  final VoiceRecorder _recorder = VoiceRecorder();
  bool _micHeld = false;
  bool _recording = false;
  double _slide = 0;
  Duration _recorded = Duration.zero;
  Timer? _recordTicker;

  String? get _me => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _channel = _model.listenForMessages(widget.chat.id, _onMessage);
    _readsChannel = _model.listenForReadStates(widget.chat.id, (state) {
      if (mounted) setState(() => _reads = {..._reads, state.userId: state});
    });
    _extrasChannel = _model.listenForExtras(widget.chat.id, _scheduleExtras);
    // Tapping the message box swaps the stickers or options for the
    // keyboard.
    _inputFocus.addListener(() {
      if (_inputFocus.hasFocus && _panel != _ComposerPanel.none) {
        setState(() => _panel = _ComposerPanel.none);
      }
    });
    _load();
    unawaited(_loadReads());
    unawaited(_loadExtras());
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) unawaited(_model.removeChannel(channel));
    final readsChannel = _readsChannel;
    if (readsChannel != null) unawaited(_model.removeChannel(readsChannel));
    final extrasChannel = _extrasChannel;
    if (extrasChannel != null) unawaited(_model.removeChannel(extrasChannel));
    _extrasReload?.cancel();
    _recordTicker?.cancel();
    unawaited(_recorder.dispose());
    unawaited(VoicePlayback.instance.stop());
    unawaited(_chats.markRead(widget.chat.id));
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadExtras() async {
    try {
      final extras = await _model.fetchExtras(widget.chat.id);
      if (mounted) setState(() => _extras = extras);
    } catch (error) {
      debugPrint('SYNK: poll votes and listens failed to load: $error');
    }
  }

  // Several votes often land together; reload once for all of them.
  void _scheduleExtras() {
    _extrasReload?.cancel();
    _extrasReload = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_loadExtras()),
    );
  }

  // Everyone else who was in the chat when [message] was sent.
  Iterable<ChatReadState> _othersAt(ChatMessage message) => _reads.values.where(
    (r) => r.userId != _me && !r.joinedAt.isAfter(message.createdAt),
  );

  // Mine: everyone else has listened. Theirs: I have.
  bool _heard(ChatMessage message) {
    final plays = _extras.plays[message.id] ?? const <String>{};
    if (message.senderId != _me) return plays.contains(_me);
    final others = _othersAt(message);
    return others.isNotEmpty && others.every((r) => plays.contains(r.userId));
  }

  // Shows it as heard straight away, then tells the sender.
  void _markPlayed(ChatMessage message) {
    final me = _me;
    if (me == null || message.senderId == me) return;
    final plays = _extras.plays[message.id] ?? const <String>{};
    if (plays.contains(me)) return;
    setState(
      () => _extras = _extras.copyWith(
        plays: {
          ..._extras.plays,
          message.id: {...plays, me},
        },
      ),
    );
    unawaited(
      _model.markVoicePlayed(message.id).catchError((Object error) {
        debugPrint('SYNK: marking voice message played failed: $error');
      }),
    );
  }

  // Shows your vote straight away; reloads if the server says no.
  Future<void> _vote(ChatMessage message, List<int> picks) async {
    final me = _me;
    if (me == null) return;
    final forMessage = {...?_extras.votes[message.id]};
    if (picks.isEmpty) {
      forMessage.remove(me);
    } else {
      forMessage[me] = picks;
    }
    setState(
      () => _extras = _extras.copyWith(
        votes: {..._extras.votes, message.id: forMessage},
      ),
    );
    var ok = false;
    try {
      ok = await _model.votePoll(message.id, picks);
    } catch (error) {
      debugPrint('SYNK: voting failed: $error');
    }
    if (!mounted || ok) return;
    await _loadExtras();
    if (mounted) {
      SynkFeedback.showError(
        context,
        context.l10n.somethingWentWrongPleaseTryAgain,
      );
    }
  }

  void _showVotes(ChatMessage message) {
    showPollVotesSheet(
      context,
      poll: message.poll!,
      votes: _extras.votes[message.id] ?? const {},
      me: _me,
      userFor: (id) => _members[id],
    );
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
    if (!mounted) return;
    // An update, e.g. the message was deleted.
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      setState(() => _messages = [..._messages]..[index] = message);
      return;
    }
    // Each one is loaded separately, so they can arrive out of order.
    setState(
      () =>
          _messages = [..._messages, message]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
    );
    unawaited(_chats.markRead(widget.chat.id));
    unawaited(_loadPhotoLinks([message]));
    // Someone who joined after the chat opened.
    final sender = message.senderId;
    if (sender != null && !_members.containsKey(sender)) {
      unawaited(_reloadMembers());
    }
  }

  Future<void> _loadReads() async {
    try {
      final reads = await _model.fetchReadStates(widget.chat.id);
      if (!mounted) return;
      setState(() => _reads = {for (final r in reads) r.userId: r});
    } catch (error) {
      debugPrint('SYNK: read states failed to load: $error');
    }
  }

  // Everyone else who was in the chat when [message] was sent, and which
  // of them have read it.
  ({List<String> seen, int total}) _seenBy(ChatMessage message) {
    final others = _reads.values.where(
      (r) => r.userId != _me && !r.joinedAt.isAfter(message.createdAt),
    );
    return (
      seen: [
        for (final r in others)
          if (!r.lastReadAt.isBefore(message.createdAt)) r.userId,
      ],
      total: others.length,
    );
  }

  Widget _buildSeenLabel(ChatMessage message) {
    final (:seen, :total) = _seenBy(message);
    // A voice message someone listened to says "Played", like WhatsApp's
    // blue mic, rather than just "Seen".
    final plays = message.isVoice
        ? (_extras.plays[message.id] ?? const <String>{})
        : const <String>{};
    final played = [
      for (final r in _othersAt(message))
        if (plays.contains(r.userId)) r.userId,
    ];
    if (played.isNotEmpty) {
      final label = !widget.chat.isActivity
          ? context.l10n.played
          : played.length >= total
          ? context.l10n.playedByEveryone
          : context.l10n.playedByCount(played.length);
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 4, 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.headphones_rounded,
                size: 14,
                color: SynkColors.tealText,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.tealText,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final String label;
    if (seen.isEmpty) {
      label = context.l10n.sent;
    } else if (!widget.chat.isActivity) {
      label = context.l10n.seen;
    } else if (seen.length >= total) {
      label = context.l10n.seenByEveryone;
    } else {
      label = context.l10n.seenByCount(seen.length);
    }
    final canOpen = widget.chat.isActivity && seen.isNotEmpty;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onTap: canOpen ? () => _showSeenBy(seen) : null,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(8, 3, 4, 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (seen.isNotEmpty) ...[
                const Icon(
                  Icons.done_all_rounded,
                  size: 14,
                  color: SynkColors.tealText,
                ),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: seen.isEmpty
                      ? SynkColors.textSecondary
                      : SynkColors.tealText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Group chats: who has seen your latest message.
  Future<void> _showSeenBy(List<String> userIds) {
    final users = [
      for (final id in userIds)
        if (_members[id] != null) _members[id]!,
    ];
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: SynkColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.seenByCount(userIds.length),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final user in users)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            _MemberAvatar(user: user, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: SynkColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadPhotoLinks(List<ChatMessage> messages) async {
    final paths = [
      for (final m in messages)
        // View-once photos load only when opened.
        if (m.hasPhoto && !m.viewOnce && !_photoLinks.containsKey(m.imagePath))
          m.imagePath!,
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

  void _dismissPanels() {
    _inputFocus.unfocus();
    if (_panel != _ComposerPanel.none) {
      setState(() => _panel = _ComposerPanel.none);
    }
  }

  // The + button opens the options where the keyboard is, like WhatsApp;
  // pressing it again (now an ×) brings the keyboard back.
  void _toggleAttachments() {
    if (_showAttachments) {
      setState(() => _panel = _ComposerPanel.none);
      _inputFocus.requestFocus();
    } else {
      _inputFocus.unfocus();
      setState(() => _panel = _ComposerPanel.attachments);
    }
  }

  // One of the + options: a photo, a location, an activity, a friend or a
  // poll.
  Future<void> _sendAttachment(ChatAttachment choice) async {
    if (_isSending) return;
    setState(() => _panel = _ComposerPanel.none);
    switch (choice) {
      case ChatAttachment.photo:
        await _sendPhoto();
      case ChatAttachment.camera:
        await _sendPhoto(fromCamera: true);
      case ChatAttachment.location:
        await _sendLocation();
      case ChatAttachment.activity:
        await _sendActivity();
      case ChatAttachment.contact:
        await _sendContact();
      case ChatAttachment.poll:
        await _sendPoll();
    }
  }

  Future<void> _sendContact() async {
    final friend = await showFriendPickerSheet(
      context,
      // No point sharing someone with themselves.
      exclude: {?widget.chat.otherUser?.id},
    );
    if (!mounted || friend == null) return;
    await _sendVia(
      (replyToId) => _model.sendExtra(
        widget.chat.id,
        sharedUserId: friend.id,
        replyToId: replyToId,
      ),
      notVisibleToAll: context.l10n.friendNotVisibleToAll,
    );
  }

  Future<void> _sendPoll() async {
    final poll = await showCreatePollSheet(context);
    if (!mounted || poll == null) return;
    await _sendVia(
      (replyToId) =>
          _model.sendExtra(widget.chat.id, poll: poll, replyToId: replyToId),
    );
  }

  Future<void> _sendSticker(ChatSticker sticker) async {
    if (_isSending) return;
    await _sendVia(
      (replyToId) => _model.sendExtra(
        widget.chat.id,
        stickerId: sticker.id,
        replyToId: replyToId,
      ),
    );
  }

  void _toggleStickers() {
    if (_showStickers) {
      setState(() => _panel = _ComposerPanel.none);
      _inputFocus.requestFocus();
    } else {
      _inputFocus.unfocus();
      setState(() => _panel = _ComposerPanel.stickers);
    }
  }

  // ---- Voice messages ----

  void _showHoldHint() {
    SynkFeedback.showToast(
      context,
      title: context.l10n.holdToRecord,
      success: false,
    );
  }

  Future<void> _onMicDown(PointerDownEvent _) async {
    if (_isSending || _recording || _micHeld) return;
    _micHeld = true;
    _slide = 0;
    unawaited(HapticFeedback.mediumImpact());
    await VoicePlayback.instance.stop();

    var start = VoiceStart.denied;
    try {
      start = await _recorder.start();
    } catch (error) {
      debugPrint('SYNK: recording failed to start: $error');
    }
    if (!mounted) return;
    if (start != VoiceStart.started) {
      _micHeld = false;
      if (start == VoiceStart.askedPermission) {
        _showHoldHint();
      } else {
        SynkFeedback.showToast(
          context,
          title: context.l10n.microphoneAccessNeeded,
          success: false,
        );
      }
      return;
    }
    // Let go before it started: a tap, not a hold.
    if (!_micHeld) {
      await _recorder.cancel();
      if (mounted) _showHoldHint();
      return;
    }
    setState(() {
      _recording = true;
      _locked = false;
      _lift = 0;
      _voiceViewOnce = false;
      _recorded = Duration.zero;
    });
    // Often enough for the live waveform when locked.
    _recordTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final elapsed = _recorder.elapsed;
      // Two minutes at most: it sends itself.
      if (elapsed >= ChatModel.maxVoiceLength) {
        unawaited(_finishRecording(send: true));
        return;
      }
      setState(() => _recorded = elapsed);
    });
  }

  // Sliding toward the start of the line cancels (left in English, right
  // in Arabic); sliding up locks. One at a time, whichever the finger is
  // further along.
  void _onMicMove(PointerMoveEvent event) {
    if (!_recording || _locked) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final toward = rtl ? event.delta.dx : -event.delta.dx;
    var slide = (_slide + toward).clamp(0.0, _cancelDistance);
    var lift = (_lift - event.delta.dy).clamp(0.0, _lockDistance);
    if (slide / _cancelDistance > lift / _lockDistance) {
      lift = 0;
    } else {
      slide = 0;
    }
    if (slide >= _cancelDistance) {
      unawaited(_finishRecording(send: false));
      return;
    }
    if (lift >= _lockDistance) {
      unawaited(HapticFeedback.mediumImpact());
      // The mic is swapped for send, so its "let go" never arrives.
      _micHeld = false;
      setState(() {
        _locked = true;
        _slide = 0;
        _lift = 0;
      });
      return;
    }
    setState(() {
      _slide = slide;
      _lift = lift;
    });
  }

  void _onMicUp() {
    _micHeld = false;
    // Locked: keeps recording until 🗑 or send.
    if (_recording && !_locked) unawaited(_finishRecording(send: true));
  }

  Future<void> _finishRecording({required bool send}) async {
    if (!_recording) return;
    _recordTicker?.cancel();
    _recordTicker = null;
    final viewOnce = _voiceViewOnce;
    setState(() {
      _recording = false;
      _locked = false;
      _slide = 0;
      _lift = 0;
      _voiceViewOnce = false;
    });
    if (!send) {
      unawaited(HapticFeedback.heavyImpact());
      await _recorder.cancel();
      return;
    }

    final recording = await _recorder.stop();
    if (!mounted || recording == null) return;
    final file = File(recording.path);
    if (recording.duration < const Duration(seconds: 1)) {
      unawaited(file.delete().then((_) {}, onError: (_) {}));
      _showHoldHint();
      return;
    }
    unawaited(HapticFeedback.lightImpact());
    final duration = recording.duration > ChatModel.maxVoiceLength
        ? ChatModel.maxVoiceLength
        : recording.duration;
    await _sendVia((replyToId) async {
      try {
        final path = await _model.uploadVoice(widget.chat.id, recording.path);
        return viewOnce
            ? await _model.sendViewOnce(
                widget.chat.id,
                audioPath: path,
                audioDuration: duration,
                waveform: recording.waveform,
                replyToId: replyToId,
              )
            : await _model.sendExtra(
                widget.chat.id,
                audioPath: path,
                audioDuration: duration,
                waveform: recording.waveform,
                replyToId: replyToId,
              );
      } finally {
        unawaited(file.delete().then((_) {}, onError: (_) {}));
      }
    });
  }

  Future<void> _sendLocation() async {
    final place = await showModalBottomSheet<PlaceSuggestion?>(
      context: context,
      isScrollControlled: true,
      // Keeps the sheet's title below the status bar.
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          LocationSearchSheet(confirmLabel: context.l10n.sendThisLocation),
    );
    if (!mounted || place == null || !place.hasCoordinates) return;
    await _deliver(place: place);
  }

  Future<void> _sendActivity() async {
    final activity = await showActivityPickerSheet(
      context,
      store: widget.activityStore,
    );
    if (!mounted || activity == null) return;
    await _deliver(activityId: activity.id);
  }

  Future<void> _sendPhoto({bool fromCamera = false}) async {
    final XFile? file;
    try {
      file = await _model.pickPhoto(fromCamera: fromCamera);
    } catch (error) {
      debugPrint('SYNK: photo picker failed: $error');
      return;
    }
    if (file == null || !mounted) return;
    // A preview first, like WhatsApp: a caption, or ① for view once.
    final choice = await showPhotoSendPreview(context, file);
    if (choice == null || !mounted) return;
    if (!choice.viewOnce) {
      await _deliver(photo: file, text: choice.caption);
      return;
    }
    await _sendVia((replyToId) async {
      final path = await _model.uploadPhoto(widget.chat.id, file!);
      return _model.sendViewOnce(
        widget.chat.id,
        imagePath: path,
        replyToId: replyToId,
      );
    });
  }

  // ---- View once ----

  // Theirs: I opened it. Mine: anyone else did.
  bool _viewOnceOpened(ChatMessage message) {
    final opens = _extras.opens[message.id] ?? const <String>{};
    return message.senderId == _me
        ? opens.any((id) => id != _me)
        : opens.contains(_me);
  }

  // Opens one of theirs: a photo full screen (gone when closed), a voice
  // message right there in the chat (until you leave it).
  Future<void> _openViewOnce(ChatMessage message) async {
    if (_openingViewOnce != null) return;
    setState(() => _openingViewOnce = message.id);
    var result = '';
    try {
      result = await _model.openViewOnce(message.id);
    } catch (error) {
      debugPrint('SYNK: opening view-once message failed: $error');
    }
    if (!mounted) return;

    final me = _me;
    if (me != null && (result == 'opened' || result == 'already_opened')) {
      final opens = _extras.opens[message.id] ?? const <String>{};
      _extras = _extras.copyWith(
        opens: {
          ..._extras.opens,
          message.id: {...opens, me},
        },
      );
    }
    if (result != 'opened') {
      setState(() => _openingViewOnce = null);
      SynkFeedback.showToast(
        context,
        title: result == 'already_opened'
            ? context.l10n.alreadyOpened
            : context.l10n.somethingWentWrongPleaseTryAgain,
        success: false,
      );
      return;
    }

    if (message.isVoice) {
      setState(() {
        _openingViewOnce = null;
        _openedNow.add(message.id);
      });
      final ok = await VoicePlayback.instance.toggle(
        _model,
        message,
        onStarted: () => _markPlayed(message),
      );
      if (!ok && mounted) {
        SynkFeedback.showToast(
          context,
          title: context.l10n.voiceNotAvailable,
          success: false,
        );
      }
      return;
    }

    String? link;
    try {
      link = (await _model.photoLinks([message.imagePath!]))[message.imagePath];
    } catch (error) {
      debugPrint('SYNK: view-once photo failed to load: $error');
    }
    if (!mounted) return;
    setState(() => _openingViewOnce = null);
    if (link == null) {
      SynkFeedback.showToast(
        context,
        title: context.l10n.somethingWentWrongPleaseTryAgain,
        success: false,
      );
      return;
    }
    await _showPhoto(context, link);
    if (mounted) setState(() {});
  }

  // Sends one of: text, a photo, an activity or a place. True when sent.
  Future<bool> _deliver({
    String text = '',
    XFile? photo,
    String? activityId,
    PlaceSuggestion? place,
  }) {
    return _sendVia((replyToId) async {
      final imagePath = photo == null
          ? null
          : await _model.uploadPhoto(widget.chat.id, photo);
      return _model.send(
        widget.chat.id,
        text,
        imagePath: imagePath,
        activityId: activityId,
        place: place,
        replyToId: replyToId,
      );
    });
  }

  // Runs [send] (quoting the message being replied to, if any) and handles
  // what the server said. [notVisibleToAll] is the toast for
  // 'not_visible_to_all'. True when sent.
  Future<bool> _sendVia(
    Future<({String result, ChatMessage? message})> Function(String? replyToId)
    send, {
    String? notVisibleToAll,
  }) async {
    setState(() => _isSending = true);
    var result = '';
    ChatMessage? sent;
    try {
      (:result, message: sent) = await send(_replyingTo?.id);
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
      setState(() => _closed = true);
      unawaited(_chats.refresh());
      return false;
    }
    if (result == 'not_friends' && !widget.chat.isActivity) {
      setState(() => _unfriended = true);
      unawaited(_chats.refresh());
      return false;
    }
    if (result == 'not_visible_to_all') {
      SynkFeedback.showToast(
        context,
        title: notVisibleToAll ?? context.l10n.activityNotVisibleToAll,
        success: false,
      );
      return false;
    }
    if (sent == null) {
      SynkFeedback.showToast(
        context,
        title: context.l10n.messageNotSent,
        // Only when the server actually said so; a failed upload or a
        // network error isn't about friendship ('not_friends' is handled
        // above).
        message: result == 'not_member' && !widget.chat.isActivity
            ? context.l10n.canOnlyMessageFriends
            : null,
        success: false,
      );
      return false;
    }
    setState(() => _replyingTo = null);
    _onMessage(sent);
    unawaited(_chats.refresh());
    return true;
  }

  // Shows an activity over the chat, this chat's or a shared one; closing it
  // comes back here. A null id is a shared activity that was deleted.
  Future<void> _openActivity(String? activityId) async {
    if (activityId == null || activityId.isEmpty) {
      SynkFeedback.showToast(
        context,
        title: context.l10n.thisActivityIsNoLongerAvailable,
        success: false,
      );
      return;
    }
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

  // A small menu just under the long-pressed message.
  Future<void> _showMessageMenu(ChatMessage message, Rect bubble) async {
    unawaited(HapticFeedback.mediumImpact());
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final canDeleteForEveryone = message.senderId == _me && !message.isDeleted;
    final canCopy = !message.isDeleted && message.text.trim().isNotEmpty;

    final action = await showMenu<_MessageAction>(
      context: context,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Lines up with the bubble's outer edge, below it.
      position: RelativeRect.fromRect(
        Rect.fromLTRB(
          bubble.left,
          bubble.bottom + 4,
          bubble.right,
          bubble.bottom + 4,
        ),
        Offset.zero & overlay.size,
      ),
      items: [
        if (!message.isDeleted)
          _menuItem(
            _MessageAction.reply,
            Icons.reply_rounded,
            context.l10n.reply,
          ),
        if (canCopy)
          _menuItem(_MessageAction.copy, Icons.copy_rounded, context.l10n.copy),
        if (canDeleteForEveryone)
          _menuItem(
            _MessageAction.deleteForEveryone,
            Icons.delete_outline_rounded,
            context.l10n.deleteForEveryone,
            color: SynkColors.badge,
          ),
        _menuItem(
          _MessageAction.deleteForMe,
          Icons.remove_circle_outline_rounded,
          context.l10n.deleteForMe,
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case _MessageAction.reply:
        _startReply(message);
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.text));
        if (mounted) {
          SynkFeedback.showToast(context, title: context.l10n.messageCopied);
        }
      case _MessageAction.deleteForEveryone:
        await _deleteForEveryone(message);
      case _MessageAction.deleteForMe:
        await _deleteForMe(message);
      case null:
        break;
    }
  }

  void _startReply(ChatMessage message) {
    if (message.isDeleted) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _replyingTo = message);
    _inputFocus.requestFocus();
  }

  // Who wrote a message, as reply quotes show it.
  String _authorOf(ChatMessage message) {
    if (message.senderId == _me) return context.l10n.you;
    final name = _members[message.senderId]?.name ?? '';
    return name.isNotEmpty ? name : context.l10n.communityMember;
  }

  // One line describing a message, for reply quotes.
  String _previewOf(ChatMessage message) {
    if (message.isDeleted) return context.l10n.messageWasDeleted;
    // Never a peek at what's inside.
    if (message.viewOnce) {
      return '① ${message.hasPhoto ? context.l10n.photo : context.l10n.voiceMessage}';
    }
    if (message.isSticker) return context.l10n.sticker;
    if (message.isVoice) {
      final length = message.audioDuration;
      return '🎤 ${context.l10n.voiceMessage}'
          '${length == null ? '' : ' (${formatVoiceLength(length)})'}';
    }
    if (message.isContact) return '👤 ${message.sharedUser!.name}';
    if (message.isPoll) return '📊 ${message.poll!.question}';
    if (message.text.trim().isNotEmpty) return message.text.trim();
    if (message.isActivityShare) return message.sharedActivity!.title;
    if (message.isLocation) {
      final name = message.locationName?.trim() ?? '';
      return name.isNotEmpty ? name : context.l10n.location;
    }
    if (message.hasPhoto) return context.l10n.photo;
    return '';
  }

  PopupMenuItem<_MessageAction> _menuItem(
    _MessageAction value,
    IconData icon,
    String label, {
    Color color = SynkColors.textPrimary,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Everyone sees "This message was deleted".
  Future<void> _deleteForEveryone(ChatMessage message) async {
    var ok = false;
    try {
      ok = await _model.deleteMessage(message.id);
    } catch (error) {
      debugPrint('SYNK: deleting message failed: $error');
    }
    if (!mounted) return;
    if (!ok) return _showDeleteError();
    if (VoicePlayback.instance.isActive(message.id)) {
      unawaited(VoicePlayback.instance.stop());
    }
    // Realtime brings the same change; this shows it without waiting.
    _onMessage(
      ChatMessage(
        id: message.id,
        chatId: message.chatId,
        senderId: message.senderId,
        body: '',
        createdAt: message.createdAt,
        deletedAt: DateTime.now(),
      ),
    );
    unawaited(_chats.refresh());
  }

  // Gone for you only, with no placeholder; put back if it fails.
  Future<void> _deleteForMe(ChatMessage message) async {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;
    setState(() => _messages = [..._messages]..removeAt(index));

    var ok = false;
    try {
      ok = await _model.hideMessage(message.id);
    } catch (error) {
      debugPrint('SYNK: hiding message failed: $error');
    }
    if (!mounted) return;
    if (!ok) {
      setState(
        () =>
            _messages = [..._messages, message]
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );
      return _showDeleteError();
    }
    unawaited(_chats.refresh());
  }

  void _showDeleteError() {
    SynkFeedback.showError(
      context,
      context.l10n.somethingWentWrongPleaseTryAgain,
    );
  }

  Future<void> _deleteChat() async {
    final deleted = await confirmDeleteChat(context, widget.chat);
    if (deleted && mounted) Navigator.pop(context);
  }

  void _openProfile(FriendUser user) {
    // Nothing to open for someone in a block with you, either way.
    if (user.id == _me || user.isRestricted) return;
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
        // "Synk user" stays whole.
        .map((u) => u.isHidden ? u.name : u.name.split(' ').first)
        .where((name) => name.isNotEmpty);
    return [
      ...others.map(bidiIsolate),
      if (_members.containsKey(_me)) context.l10n.you,
    ].join(context.l10n.listSeparator);
  }

  @override
  Widget build(BuildContext context) {
    // Back closes the stickers or options first, like the keyboard.
    return PopScope(
      canPop: _panel == _ComposerPanel.none,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _panel = _ComposerPanel.none);
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      // Darker beige with a hairline and soft shadow, to lift it off the
      // messages.
      appBar: AppBar(
        backgroundColor: SynkColors.backgroundDark,
        elevation: 3,
        scrolledUnderElevation: 3,
        shadowColor: Colors.black26,
        surfaceTintColor: Colors.transparent,
        shape: Border(
          bottom: BorderSide(
            color: SynkColors.textSecondary.withValues(alpha: 0.14),
          ),
        ),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SynkColors.textPrimary,
          ),
        ),
        title: _buildTitle(),
        actions: [
          PopupMenuButton<VoidCallback>(
            tooltip: context.l10n.moreOptions,
            onSelected: (action) => action(),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: const Icon(
              Icons.more_vert_rounded,
              color: SynkColors.textPrimary,
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _deleteChat,
                child: Text(
                  context.l10n.deleteChat,
                  style: const TextStyle(color: SynkColors.badge),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Tapping the messages puts away the keyboard, the stickers or
          // the + options, like WhatsApp. Taps on a bubble's own buttons
          // still go to the bubble.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _dismissPanels,
              child: Stack(
                children: [
                  const Positioned.fill(child: ChatWallpaper()),
                  _buildMessages(),
                ],
              ),
            ),
          ),
          // Rebuilt when the chats list refreshes, so removing a friend
          // locks a chat that's already open.
          ListenableBuilder(
            listenable: _chats,
            builder: (context, _) => _buildComposer(),
          ),
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
        onTap: activity != null
            ? () => _openActivity(activity.id)
            : () => _openProfile(friend!),
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
    final byId = {for (final m in _messages) m.id: m};
    // "Seen" goes under your latest message only.
    final myLatest = messages
        .where((m) => m.senderId == _me && !m.isDeleted)
        .firstOrNull;
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

        final replyId = message.isDeleted ? null : message.replyToId;
        final repliedTo = replyId == null ? null : byId[replyId];
        return Column(
          children: [
            if (newDay) _DayDivider(date: message.createdAt),
            _MessageBubble(
              quote: replyId == null
                  ? null
                  : (
                      author: repliedTo == null ? '' : _authorOf(repliedTo),
                      text: repliedTo == null
                          ? context.l10n.originalMessageUnavailable
                          : _previewOf(repliedTo),
                    ),
              onReply: message.isDeleted ? null : () => _startReply(message),
              message: message,
              sender: _members[message.senderId],
              isMine: message.senderId == _me,
              showSender: widget.chat.isActivity && firstInGroup,
              showAvatar: widget.chat.isActivity && lastInGroup,
              isGroupChat: widget.chat.isActivity,
              photoLink: _photoLinks[message.imagePath],
              onSenderTap: _openProfile,
              onOpenActivity: _openActivity,
              onLongPress: (bubble) => _showMessageMenu(message, bubble),
              model: _model,
              me: _me,
              heard: message.isVoice && _heard(message),
              onVoiceStarted: () => _markPlayed(message),
              votes: _extras.votes[message.id] ?? const {},
              onVote: _canSend ? (picks) => _vote(message, picks) : null,
              onViewVotes: () => _showVotes(message),
              onOpenContact: _openProfile,
              viewOnceOpened: message.viewOnce && _viewOnceOpened(message),
              viewOnceOpenNow: _openedNow.contains(message.id),
              viewOnceLoading: _openingViewOnce == message.id,
              onOpenViewOnce: () => _openViewOnce(message),
            ),
            if (message.id == myLatest?.id) _buildSeenLabel(message),
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

  Widget _buildReplyBar(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: SynkColors.orangeDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.replyingTo(bidiIsolate(_authorOf(message))),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: SynkColors.orangeDark,
                  ),
                ),
                Text(
                  _previewOf(message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: SynkColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.cancel,
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _replyingTo = null),
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: SynkColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  bool get _isUnfriended =>
      _unfriended || (_chats.byId(widget.chat.id) ?? widget.chat).isUnfriended;

  // Messages, and votes, can still be sent here.
  bool get _canSend => !_closed && !widget.chat.isClosed && !_isUnfriended;

  Widget _buildComposer() {
    final unfriended = _isUnfriended;
    if (!_canSend) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Text(
            unfriended
                ? context.l10n.noLongerFriendsWith(widget.chat.title)
                : context.l10n.chatClosed,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SynkColors.textSecondary,
            ),
          ),
        ),
      );
    }
    final replyingTo = _replyingTo;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isLoading && !_failed && _messages.isEmpty) _buildStarters(),
          if (replyingTo != null) _buildReplyBar(replyingTo),
          _buildComposerRow(),
          if (_panel != _ComposerPanel.none) _buildPanel(),
        ],
      ),
    );
  }

  // The stickers or + options, where the keyboard was. While the keyboard
  // is still sliding down, the panel only takes the space it has left, so
  // the two never overflow the screen together.
  Widget _buildPanel() {
    const height = 290.0;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final visible = (height - keyboard).clamp(0.0, height);
    return SizedBox(
      height: visible,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: height,
          maxHeight: height,
          child: _showStickers
              ? StickerPickerPanel(height: height, onPick: _sendSticker)
              : AttachmentPanel(height: height, onPick: _sendAttachment),
        ),
      ),
    );
  }

  // Ready messages for a chat with nothing in it yet; one tap sends it.
  Widget _buildStarters() {
    final l = context.l10n;
    final starters = widget.chat.isActivity
        ? [
            l.chatStarterHiEveryone,
            l.chatStarterExcited,
            l.chatStarterWhereMeet,
            l.chatStarterGoTogether,
          ]
        : [
            l.chatStarterHey,
            l.chatStarterHowsItGoing,
            l.chatStarterPlanSomething,
            if (_sharedInterests.isNotEmpty) l.chatStarterSameThings,
          ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        itemCount: starters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final text = starters[i];
          return Material(
            color: Colors.white,
            shape: StadiumBorder(
              side: BorderSide(
                color: SynkColors.textSecondary.withValues(alpha: 0.14),
              ),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _isSending ? null : () => _deliver(text: text),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SynkColors.ink,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Laid out like WhatsApp: + on the outside, the message box with the
  // sticker button inside it, then the camera and a round mic that turns
  // into send once there's text. Holding the mic swaps the box for the
  // recording bar.
  Widget _buildComposerRow() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(23),
      borderSide: BorderSide(
        color: SynkColors.textSecondary.withValues(alpha: 0.14),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 6, 8, 8),
      child: ListenableBuilder(
        listenable: _input,
        builder: (context, _) {
          final hasText = _input.text.trim().isNotEmpty;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _recording && _locked
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4),
                        child: LockedRecordingBar(
                          elapsed: _recorded,
                          levels: _recorder.recentLevels(80),
                          onDelete: () =>
                              unawaited(_finishRecording(send: false)),
                          viewOnceToggle: ViewOnceToggle(
                            on: _voiceViewOnce,
                            size: 34,
                            onChanged: (on) {
                              setState(() => _voiceViewOnce = on);
                              if (on) {
                                SynkFeedback.showToast(
                                  context,
                                  title: context.l10n.viewOnceHint,
                                );
                              }
                            },
                          ),
                        ),
                      )
                    : _recording
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4),
                        child: VoiceRecordingBar(
                          elapsed: _recorded,
                          slide: _slide,
                          cancelDistance: _cancelDistance,
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Turns into an × while the options are open.
                          AnimatedRotation(
                            turns: _showAttachments ? 0.125 : 0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: _ComposerIcon(
                              icon: Icons.add_rounded,
                              size: 28,
                              tooltip: _showAttachments
                                  ? context.l10n.keyboard
                                  : context.l10n.sendSomething,
                              onPressed: _isSending ? null : _toggleAttachments,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _input,
                              focusNode: _inputFocus,
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
                                contentPadding:
                                    const EdgeInsetsDirectional.fromSTEB(
                                      16,
                                      13,
                                      4,
                                      13,
                                    ),
                                suffixIcon: IconButton(
                                  tooltip: _showStickers
                                      ? context.l10n.keyboard
                                      : context.l10n.stickers,
                                  onPressed: _toggleStickers,
                                  icon: Icon(
                                    _showStickers
                                        ? Icons.keyboard_alt_outlined
                                        : Icons.sticky_note_2_outlined,
                                    size: 23,
                                    color: _showStickers
                                        ? SynkColors.orangeDark
                                        : SynkColors.textSecondary,
                                  ),
                                ),
                                border: border,
                                enabledBorder: border,
                                focusedBorder: border.copyWith(
                                  borderSide: const BorderSide(
                                    color: SynkColors.orange,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // The camera hides while typing, like WhatsApp.
                          if (!hasText)
                            _ComposerIcon(
                              icon: Icons.photo_camera_outlined,
                              tooltip: context.l10n.camera,
                              onPressed: _isSending
                                  ? null
                                  : () => _sendPhoto(fromCamera: true),
                            ),
                        ],
                      ),
              ),
              const SizedBox(width: 4),
              if (_recording && _locked)
                _buildSendButton(
                  onPressed: () => unawaited(_finishRecording(send: true)),
                )
              else if (hasText)
                _buildSendButton()
              else
                _buildMicButton(),
            ],
          );
        },
      ),
    );
  }

  // Sends the typed text, or [onPressed] (a locked recording).
  Widget _buildSendButton({VoidCallback? onPressed}) {
    return IconButton.filled(
      tooltip: context.l10n.send,
      onPressed: _isSending ? null : (onPressed ?? _send),
      style: IconButton.styleFrom(
        backgroundColor: SynkColors.orangeDark,
        disabledBackgroundColor: SynkColors.orangeDark.withValues(alpha: 0.35),
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
  }

  // Hold to record. Raw pointer events, so it starts the moment it's
  // pressed and keeps following the finger as it slides to cancel.
  Widget _buildMicButton() {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      label: context.l10n.voiceMessage,
      hint: context.l10n.holdToRecord,
      child: Listener(
        onPointerDown: _onMicDown,
        onPointerMove: _onMicMove,
        onPointerUp: (_) => _onMicUp(),
        onPointerCancel: (_) => _onMicUp(),
        // While recording, a lock floats above: slide up to it to lock.
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            if (_recording)
              Positioned(
                bottom: 66 + _lift * 0.4,
                child: VoiceLockHint(progress: _lift / _lockDistance),
              ),
            _buildMicCircle(rtl),
          ],
        ),
      ),
    );
  }

  Widget _buildMicCircle(bool rtl) {
    return Transform.translate(
      // Follows the finger: sideways toward cancel, or up toward lock.
      offset: Offset(rtl ? _slide : -_slide, -_lift),
      child: AnimatedScale(
        scale: _recording ? 1.3 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _isSending
                ? SynkColors.orangeDark.withValues(alpha: 0.35)
                : SynkColors.orangeDark,
            shape: BoxShape.circle,
          ),
          child: _isSending
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.mic_rounded, size: 24, color: Colors.white),
        ),
      ),
    );
  }
}

// A plain icon button beside the message box.
class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 25,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 46,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        color: SynkColors.textPrimary,
        disabledColor: SynkColors.textSecondary.withValues(alpha: 0.4),
        icon: Icon(icon, size: size),
      ),
    );
  }
}

enum _MessageAction { reply, copy, deleteForEveryone, deleteForMe }

enum _ComposerPanel { none, stickers, attachments }

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
    this.onLongPress,
    this.onOpenActivity,
    this.quote,
    this.onReply,
    required this.model,
    required this.me,
    this.heard = false,
    this.onVoiceStarted,
    this.votes = const {},
    this.onVote,
    this.onViewVotes,
    this.onOpenContact,
    this.viewOnceOpened = false,
    this.viewOnceOpenNow = false,
    this.viewOnceLoading = false,
    this.onOpenViewOnce,
  });

  final ChatModel model;
  final String? me;

  // View once. Opened: theirs by me, mine by anyone. OpenNow: a voice one I
  // opened this visit, so it plays right here.
  final bool viewOnceOpened;
  final bool viewOnceOpenNow;
  final bool viewOnceLoading;
  final VoidCallback? onOpenViewOnce;

  // A view-once message shows as "① Photo" / "Opened" instead of itself.
  bool get _showsViewOnce =>
      message.viewOnce &&
      !message.isDeleted &&
      !(message.isVoice && viewOnceOpenNow);

  // The photo itself: never for a view-once one.
  bool get _showsPhoto => message.hasPhoto && !message.viewOnce;

  // Voice messages. Mine: everyone else listened. Theirs: I did.
  final bool heard;
  final VoidCallback? onVoiceStarted;

  // Polls: voter id -> options, and what tapping does. Null [onVote] when
  // the chat no longer takes votes.
  final Map<String, List<int>> votes;
  final ValueChanged<List<int>>? onVote;
  final VoidCallback? onViewVotes;

  // Opens a shared friend's profile.
  final ValueChanged<FriendUser>? onOpenContact;

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

  // Opens the message menu; gets where the bubble is on screen.
  final ValueChanged<Rect>? onLongPress;

  // Opens a shared activity; null id when it was deleted.
  final ValueChanged<String?>? onOpenActivity;

  // The message this one replies to; an empty author when it isn't loaded.
  final ({String author, String text})? quote;

  // Swiping the bubble sideways replies to it.
  final VoidCallback? onReply;

  static const double _avatarSize = 28;
  static const double _photoSize = 220;

  bool get _hasCard =>
      !message.isDeleted &&
      (message.isActivityShare ||
          message.isLocation ||
          message.isContact ||
          message.isPoll);

  // Emoji-only text: how many (up to 3), else 0.
  int get _emojiCount => message.kind == 'text' && !message.isDeleted
      ? emojiOnlyCount(message.text)
      : 0;

  // Stickers and a few emoji go straight on the wallpaper, no bubble.
  bool get _isBare => message.isSticker || _emojiCount > 0;

  Widget _buildContactCard(BuildContext context) {
    final user = message.sharedUser!;
    final username = user.username;
    return _card(
      leading: UserAvatar(
        avatarUrl: user.avatarUrl,
        gender: user.gender,
        size: 52,
      ),
      title: user.name,
      subtitle: (username?.isNotEmpty ?? false) ? '@$username' : null,
      action: context.l10n.viewProfile,
      onTap: () => onOpenContact?.call(
        // The account may be gone; the snapshot still has the name.
        FriendUser(
          id: message.sharedUserId ?? user.id,
          name: user.name,
          username: user.username,
          avatarUrl: user.avatarUrl,
          gender: user.gender,
        ),
      ),
    );
  }

  Widget _buildTime({bool onWallpaper = false}) {
    final time = Text(
      formatTime(message.createdAt.hour, message.createdAt.minute),
      style: TextStyle(
        fontSize: 10.5,
        color: onWallpaper
            ? SynkColors.textSecondary
            : isMine
            ? Colors.white.withValues(alpha: 0.8)
            : SynkColors.textSecondary,
      ),
    );
    if (!onWallpaper) return time;
    // A small pill, so it reads over the wallpaper.
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: time,
    );
  }

  // A sticker or emoji with no bubble; a reply quote sits above it in a
  // small one.
  Widget _buildBare(BuildContext context) {
    final count = _emojiCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quote != null)
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.6,
            ),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isMine ? SynkColors.orangeDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _buildQuote(),
          ),
        if (message.isSticker)
          StickerImage(stickerId: message.stickerId!)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              message.text.trim(),
              style: TextStyle(
                fontSize: emojiOnlyFontSize(count),
                height: 1.15,
              ),
            ),
          ),
        _buildTime(onWallpaper: true),
      ],
    );
  }

  // A white card inside the bubble, for a shared activity or place.
  Widget _card({
    required Widget leading,
    required String title,
    required String? subtitle,
    required String action,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: _photoSize,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: textDirectionOf(title),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: SynkColors.textPrimary,
                            ),
                          ),
                          if (subtitle != null && subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: SynkColors.orangeDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: SynkColors.orangeLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    action,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SynkColors.orangeDeep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context) {
    final activity = message.sharedActivity!;
    return _card(
      leading: ActivityThumbnail(activity: activity, size: 52, radius: 12),
      title: activity.title,
      subtitle: [
        DiscoveryActivityCard.formatWhen(activity.dateTime),
        if (activity.location.trim().isNotEmpty) activity.location.trim(),
      ].join(' · '),
      action: context.l10n.viewActivity,
      onTap: () => onOpenActivity?.call(message.sharedActivityId),
    );
  }

  Widget _buildLocationCard(BuildContext context) {
    final name = message.locationName?.trim() ?? '';
    final address = message.locationAddress?.trim();
    return _card(
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: SynkColors.teal.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.location_on_rounded,
          size: 28,
          color: SynkColors.tealText,
        ),
      ),
      title: name.isNotEmpty ? name : context.l10n.sendLocation,
      subtitle: address == name ? null : address,
      action: context.l10n.openInGoogleMaps,
      onTap: () =>
          MapsLauncher.openCoordinates(message.latitude!, message.longitude!),
    );
  }

  Widget _buildQuote() {
    final q = quote!;
    final lineColor = isMine ? Colors.white : SynkColors.orangeDark;
    return Container(
      margin: _showsPhoto || _hasCard
          ? const EdgeInsets.fromLTRB(0, 0, 0, 6)
          : const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.18)
            : SynkColors.orangeLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: lineColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (q.author.isNotEmpty)
                    Text(
                      q.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isMine ? Colors.white : SynkColors.orangeDeep,
                      ),
                    ),
                  Text(
                    q.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: textDirectionOf(q.text),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.9)
                          : SynkColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleted(BuildContext context) {
    final color = isMine
        ? Colors.white.withValues(alpha: 0.85)
        : SynkColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.block_rounded, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.l10n.messageWasDeleted,
            style: TextStyle(
              fontSize: 14.5,
              fontStyle: FontStyle.italic,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

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
    final content = _isBare ? _buildBare(context) : _buildBubble(context);

    final bubble = Builder(
      builder: (bubbleContext) => GestureDetector(
        onLongPress: onLongPress == null
            ? null
            : () {
                final box = bubbleContext.findRenderObject() as RenderBox;
                onLongPress!(box.localToGlobal(Offset.zero) & box.size);
              },
        child: content,
      ),
    );

    final Widget row;
    if (isMine) {
      row = Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Align(alignment: AlignmentDirectional.centerEnd, child: bubble),
      );
    } else {
      row = _buildTheirRow(context, bubble);
    }
    if (onReply == null) return row;
    return _SwipeToReply(onReply: onReply!, child: row);
  }

  Widget _buildBubble(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: _showsPhoto || _hasCard
          ? const EdgeInsets.fromLTRB(4, 4, 4, 6)
          : message.isVoice
          ? const EdgeInsetsDirectional.fromSTEB(4, 6, 12, 6)
          : const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: isMine ? SynkColors.orangeDark : Colors.white,
        // The corner nearest the sender is pulled in, like a tail.
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(18),
          topEnd: const Radius.circular(18),
          bottomStart: Radius.circular(isMine ? 18 : 4),
          bottomEnd: Radius.circular(isMine ? 4 : 18),
        ),
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
          if (quote != null) _buildQuote(),
          if (message.isDeleted) _buildDeleted(context),
          if (_showsPhoto) _buildPhoto(context),
          if (_showsViewOnce)
            ViewOnceMessageContent(
              isPhoto: message.hasPhoto,
              isMine: isMine,
              opened: viewOnceOpened,
              loading: viewOnceLoading,
              onOpen: !isMine && !viewOnceOpened ? onOpenViewOnce : null,
            ),
          if (!message.isDeleted && message.isActivityShare)
            _buildActivityCard(context),
          if (!message.isDeleted && message.isLocation)
            _buildLocationCard(context),
          if (message.isContact) _buildContactCard(context),
          if (message.isPoll)
            PollMessageContent(
              poll: message.poll!,
              votes: votes,
              me: me,
              isMine: isMine,
              onVote: onVote,
              onViewVotes: onViewVotes ?? () {},
            ),
          if (message.isVoice && !_showsViewOnce)
            VoiceMessageContent(
              model: model,
              message: message,
              isMine: isMine,
              heard: heard,
              onStarted: isMine ? null : onVoiceStarted,
            ),
          if (message.text.isNotEmpty)
            Padding(
              padding: _showsPhoto
                  ? const EdgeInsets.fromLTRB(8, 6, 8, 0)
                  : EdgeInsets.zero,
              child: Text(
                message.text,
                textDirection: textDirectionOf(message.text),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  color: isMine ? Colors.white : SynkColors.textPrimary,
                ),
              ),
            ),
          const SizedBox(height: 2),
          Padding(
            padding: _showsPhoto || _hasCard
                ? const EdgeInsetsDirectional.only(end: 8)
                : EdgeInsets.zero,
            child: _buildTime(),
          ),
        ],
      ),
    );
  }

  Widget _buildTheirRow(BuildContext context, Widget bubble) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isGroupChat) ...[
            showAvatar
                ? GestureDetector(
                    onTap:
                        sender == null ||
                            onSenderTap == null ||
                            sender!.isRestricted
                        ? null
                        : () => onSenderTap!(sender!),
                    child: sender == null
                        ? const UserAvatar(
                            avatarUrl: null,
                            gender: null,
                            size: _avatarSize,
                          )
                        : _MemberAvatar(user: sender!, size: _avatarSize),
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            sender!.name,
                            textDirection: textDirectionOf(sender!.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: sender!.isRestricted
                                  ? SynkColors.textSecondary
                                  : SynkColors.tealText,
                            ),
                          ),
                        ),
                        if (sender!.blockedByMe) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 12,
                            color: SynkColors.labelGrey,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            context.l10n.blockedTag,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: SynkColors.labelGrey,
                            ),
                          ),
                        ],
                      ],
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

// Drag a message toward the middle of the screen to reply to it. A reply
// arrow fades in behind it and it springs back on release.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.onReply, required this.child});

  final VoidCallback onReply;
  final Widget child;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _trigger = 64;
  static const double _max = 84;

  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..addListener(() => setState(() => _offset = _from * (1 - _back.value)));

  double _offset = 0;
  double _from = 0;
  bool _armed = false;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    // Toward the reading start: right in English, left in Arabic.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final delta = rtl ? -details.delta.dx : details.delta.dx;
    setState(() => _offset = (_offset + delta).clamp(0.0, _max));
    if (!_armed && _offset >= _trigger) {
      _armed = true;
      HapticFeedback.lightImpact();
    } else if (_armed && _offset < _trigger) {
      _armed = false;
    }
  }

  void _onEnd(DragEndDetails _) {
    if (_armed) widget.onReply();
    _armed = false;
    _from = _offset;
    _back.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final progress = (_offset / _trigger).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [
          PositionedDirectional(
            start: 4,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + 0.4 * progress,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: SynkColors.textSecondary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.reply_rounded,
                    size: 18,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(rtl ? -_offset : _offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// A chat member's photo. Anyone in a block with the viewer, either way,
// gets the default avatar for their gender instead of their real photo.
class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.user, required this.size});

  final FriendUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (user.isRestricted) {
      return DefaultAvatar(gender: user.gender, size: size);
    }
    return UserAvatar(
      avatarUrl: user.avatarUrl,
      gender: user.gender,
      size: size,
    );
  }
}
