import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/chat_model.dart';
import '../../../utils/text_direction.dart';
import 'activity_thumbnail.dart';
import 'user_avatar.dart';

// "1:52 PM" today, "Yesterday", the weekday this week, otherwise the date.
String formatChatTime(DateTime time, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final dayDiff = today.difference(DateUtils.dateOnly(time)).inDays;
  if (dayDiff <= 0) return formatTime(time.hour, time.minute);
  if (dayDiff == 1) return appL10n.yesterday;
  if (dayDiff < 7) return weekdayShort(time);
  return formatMonthDay(time);
}

// A chat in the Chat tab: the activity or friend, the last message, when it
// was sent and how many are unread.
class ChatListTile extends StatelessWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  });

  final ChatSummary chat;
  final String? currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = chat.unreadCount > 0;
    final activity = chat.activity;
    final friend = chat.otherUser;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (activity != null)
              ActivityThumbnail(activity: activity, size: 52, radius: 14)
            else
              UserAvatar(
                avatarUrl: friend?.avatarUrl,
                gender: friend?.gender,
                size: 52,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                      ),
                      if (chat.isMuted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 15,
                          color: SynkColors.textSecondary,
                          semanticLabel: context.l10n.muted,
                        ),
                      ],
                      if (chat.lastMessageAt != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          formatChatTime(chat.lastMessageAt!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: unread
                                ? SynkColors.orangeDark
                                : SynkColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _preview(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: unread
                                ? SynkColors.textPrimary
                                : SynkColors.textSecondary,
                          ),
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(
                          count: chat.unreadCount,
                          muted: chat.isMuted,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _preview(BuildContext context) {
    final message = chat.lastMessageBody;
    if (message == null) return context.l10n.noMessagesYet;
    if (chat.lastMessageIsDeleted) return context.l10n.messageWasDeleted;
    final label = bidiIsolate(chat.lastMessageLabel ?? '');
    // Keeps an Arabic message's punctuation in place after "You: ".
    final body = switch (chat.lastMessageKind) {
      'activity' => '📅 ${context.l10n.sharedActivityLabel(label)}',
      'location' =>
        (chat.lastMessageLabel ?? '').trim().isEmpty
            ? '📍 ${context.l10n.sendLocation}'
            : '📍 ${context.l10n.sharedLocationLabel(label)}',
      'sticker' => '✨ ${context.l10n.sticker}',
      'voice' => '🎤 ${context.l10n.voiceMessage}',
      'contact' => '👤 ${context.l10n.contact}',
      // A poll's text is JSON; show its question.
      'poll' =>
        '📊 ${bidiIsolate(ChatPoll.tryParse(message)?.question ?? context.l10n.poll)}',
      _ when message.trim().isNotEmpty => bidiIsolate(message),
      _ => '📷 ${context.l10n.photo}',
    };
    if (chat.lastMessageSenderId == currentUserId) {
      return context.l10n.youSaid(body);
    }
    // Someone who blocked you: the server sent no name.
    if (chat.isActivity && chat.lastMessageSenderHidden) {
      return context.l10n.personSaid(context.l10n.synkUser, body);
    }
    final sender = chat.lastMessageSenderName;
    if (chat.isActivity && sender != null && sender.isNotEmpty) {
      return context.l10n.personSaid(
        bidiIsolate(sender.split(' ').first),
        body,
      );
    }
    return body;
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, this.muted = false});

  final int count;

  // Grey for muted chats, which don't count toward the Chat tab badge.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? SynkColors.textSecondary : SynkColors.orangeDark,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
