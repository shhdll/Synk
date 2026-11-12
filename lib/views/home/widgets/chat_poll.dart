import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/chat_model.dart';
import '../../../models/friends_model.dart';
import '../../../utils/text_direction.dart';
import 'user_avatar.dart';

// Polls in chats: making one, voting in the chat, and who voted for what.

const _maxOptions = 12;

// The question and options; null when cancelled.
Future<ChatPoll?> showCreatePollSheet(BuildContext context) {
  return showModalBottomSheet<ChatPoll>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SynkColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _CreatePollSheet(),
  );
}

class _CreatePollSheet extends StatefulWidget {
  const _CreatePollSheet();

  @override
  State<_CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<_CreatePollSheet> {
  final TextEditingController _question = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _multiple = false;

  @override
  void dispose() {
    _question.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  List<String> get _filled => [
    for (final o in _options)
      if (o.text.trim().isNotEmpty) o.text.trim(),
  ];

  bool get _canSend => _question.text.trim().isNotEmpty && _filled.length >= 2;

  // Typing in the last option adds an empty one under it, like WhatsApp.
  void _onOptionChanged(int index) {
    if (index == _options.length - 1 &&
        _options[index].text.isNotEmpty &&
        _options.length < _maxOptions) {
      _options.add(TextEditingController());
    }
    setState(() {});
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    setState(() => _options.removeAt(index).dispose());
  }

  InputDecoration _decoration(String hint) => InputDecoration(
    hintText: hint,
    counterText: '',
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: SynkColors.textSecondary.withValues(alpha: 0.14),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: SynkColors.textSecondary.withValues(alpha: 0.14),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: SynkColors.orange),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const label = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: SynkColors.textSecondary,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l.cancel,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
              Expanded(
                child: Text(
                  l.createPoll,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Text(l.pollQuestion, style: label),
          const SizedBox(height: 6),
          TextField(
            controller: _question,
            autofocus: true,
            maxLength: 300,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: _decoration(l.pollQuestionHint),
          ),
          const SizedBox(height: 16),
          Text(l.pollOptions, style: label),
          const SizedBox(height: 6),
          for (var i = 0; i < _options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: ObjectKey(_options[i]),
                controller: _options[i],
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => _onOptionChanged(i),
                decoration: _decoration(l.pollOptionHint(i + 1)).copyWith(
                  suffixIcon: _options.length > 2
                      ? IconButton(
                          tooltip: l.deleteLabel,
                          onPressed: () => _removeOption(i),
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 20,
                            color: SynkColors.textSecondary,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          const SizedBox(height: 4),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _multiple,
            activeTrackColor: SynkColors.orangeDark,
            onChanged: (v) => setState(() => _multiple = v),
            title: Text(
              l.allowMultipleAnswers,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: SynkColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _canSend
                ? () => Navigator.pop(
                    context,
                    ChatPoll(
                      question: _question.text.trim(),
                      options: _filled,
                      multiple: _multiple,
                    ),
                  )
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: SynkColors.orangeDark,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              l.send,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// A poll inside its bubble: the question, each option with how many voted
// for it, and "View votes".
class PollMessageContent extends StatelessWidget {
  const PollMessageContent({
    super.key,
    required this.poll,
    required this.votes,
    required this.me,
    required this.isMine,
    required this.onVote,
    required this.onViewVotes,
  });

  final ChatPoll poll;

  // Voter id -> the options they picked.
  final Map<String, List<int>> votes;
  final String? me;
  final bool isMine;

  // Your new picks; empty takes your vote back. Null while it can't change,
  // e.g. in a closed chat.
  final ValueChanged<List<int>>? onVote;
  final VoidCallback onViewVotes;

  static const double width = 252;

  void _tap(int index) {
    final vote = onVote;
    if (vote == null) return;
    HapticFeedback.selectionClick();
    final mine = votes[me] ?? const <int>[];
    if (poll.multiple) {
      vote(
        mine.contains(index)
            ? [...mine.where((i) => i != index)]
            : ([...mine, index]..sort()),
      );
    } else {
      vote(mine.contains(index) ? const [] : [index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fg = isMine ? Colors.white : SynkColors.textPrimary;
    final muted = isMine
        ? Colors.white.withValues(alpha: 0.8)
        : SynkColors.textSecondary;
    final accent = isMine ? Colors.white : SynkColors.orangeDark;

    final counts = List<int>.filled(poll.options.length, 0);
    for (final picked in votes.values) {
      for (final i in picked) {
        if (i >= 0 && i < counts.length) counts[i]++;
      }
    }
    final voters = votes.length;
    final top = counts.fold(0, (a, b) => a > b ? a : b);
    final mine = votes[me] ?? const <int>[];

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              poll.question,
              textDirection: textDirectionOf(poll.question),
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                height: 1.3,
                color: fg,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  poll.multiple
                      ? Icons.checklist_rounded
                      : Icons.radio_button_checked_rounded,
                  size: 14,
                  color: muted,
                ),
                const SizedBox(width: 4),
                // Wraps rather than running past the bubble on a narrow
                // phone or with large text.
                Flexible(
                  child: Text(
                    poll.multiple ? l.selectOneOrMore : l.selectOne,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < poll.options.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: onVote == null ? null : () => _tap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        mine.contains(i)
                            ? (poll.multiple
                                  ? Icons.check_box_rounded
                                  : Icons.check_circle_rounded)
                            : (poll.multiple
                                  ? Icons.check_box_outline_blank_rounded
                                  : Icons.radio_button_unchecked_rounded),
                        size: 22,
                        color: mine.contains(i) ? accent : muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    poll.options[i],
                                    textDirection: textDirectionOf(
                                      poll.options[i],
                                    ),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      height: 1.25,
                                      color: fg,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${counts[i]}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(
                                  end: top == 0 ? 0 : counts[i] / voters,
                                ),
                                duration: const Duration(milliseconds: 250),
                                builder: (context, value, _) =>
                                    LinearProgressIndicator(
                                      value: value,
                                      minHeight: 5,
                                      color: accent,
                                      backgroundColor: isMine
                                          ? Colors.white.withValues(alpha: 0.25)
                                          : SynkColors.textSecondary.withValues(
                                              alpha: 0.15,
                                            ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Divider(
              height: 1,
              color: isMine
                  ? Colors.white.withValues(alpha: 0.25)
                  : SynkColors.textSecondary.withValues(alpha: 0.15),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onViewVotes,
                style: TextButton.styleFrom(foregroundColor: accent),
                child: Text(
                  voters == 0
                      ? l.noVotesYet
                      : '${l.viewVotes} · ${l.votesCount(voters)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Who voted for each option. [userFor] finds a voter among the chat's
// members; [me] shows as "You".
Future<void> showPollVotesSheet(
  BuildContext context, {
  required ChatPoll poll,
  required Map<String, List<int>> votes,
  required String? me,
  required FriendUser? Function(String id) userFor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SynkColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final l = sheetContext.l10n;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Text(
              poll.question,
              textDirection: textDirectionOf(poll.question),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SynkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < poll.options.length; i++) ...[
              () {
                final voterIds = [
                  for (final e in votes.entries)
                    if (e.value.contains(i)) e.key,
                ];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              poll.options[i],
                              textDirection: textDirectionOf(poll.options[i]),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: SynkColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            l.votesCount(voterIds.length),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: SynkColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      for (final id in voterIds)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              () {
                                final user = userFor(id);
                                return user == null || user.isRestricted
                                    ? UserAvatar(
                                        avatarUrl: null,
                                        gender: user?.gender,
                                        size: 30,
                                      )
                                    : UserAvatar(
                                        avatarUrl: user.avatarUrl,
                                        gender: user.gender,
                                        size: 30,
                                      );
                              }(),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  id == me
                                      ? l.you
                                      : (userFor(id)?.name ??
                                            l.communityMember),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: SynkColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }(),
            ],
          ],
        ),
      );
    },
  );
}
