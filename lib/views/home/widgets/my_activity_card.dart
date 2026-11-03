import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_model.dart';
import '../../../models/avatar_uploader.dart';
import '../../widgets/anonymous_avatar.dart';
import '../../widgets/crown_icon.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';
import 'activity_thumbnail.dart';
import 'chat_share_sheets.dart';
import 'discovery_activity_card.dart';

enum MyActivityRole {
  hosting(Icons.star_rounded, SynkColors.orangeDark),
  joined(Icons.check_circle_rounded, SynkColors.teal),
  pending(Icons.schedule_rounded, Color(0xFFD9822B)),
  waitlisted(Icons.hourglass_top_rounded, Color(0xFF8A6D3B));

  const MyActivityRole(this.icon, this.color);
  final IconData icon;
  final Color color;

  String get label => switch (this) {
    hosting => appL10n.hosting,
    joined => appL10n.joined,
    pending => appL10n.requested,
    waitlisted => appL10n.waitlisted,
  };

  static MyActivityRole of(Activity activity, String? userId) {
    if (activity.isHostedBy(userId)) return hosting;
    if (activity.isPending) return pending;
    if (activity.isWaitlisted) return waitlisted;
    return joined;
  }
}

class MyActivityCard extends StatelessWidget {
  const MyActivityCard({
    super.key,
    required this.activity,
    required this.role,
    required this.participants,
    required this.onTap,
    this.onChat,
    this.unreadCount = 0,
    this.showCode = false,
    this.canShare = false,
    this.anonymous = false,
  });

  final bool anonymous;

  final Activity activity;
  final MyActivityRole role;
  // null while loading
  final List<Map<String, dynamic>>? participants;
  final VoidCallback onTap;
  // null hides the Chat button.
  final VoidCallback? onChat;
  final int unreadCount;
  final bool showCode;
  final bool canShare;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));
    final hasLocation = activity.location.trim().isNotEmpty;
    final title = activity.title.trim().isEmpty
        ? context.l10n.untitledActivity
        : activity.title;

    final code = showCode && activity.hasActivityCode
        ? activity.activityCode!
        : null;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: SynkColors.orangeDark.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ActivityThumbnail(activity: activity, size: 72, radius: 14),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: _BidiText(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: SynkColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (!activity.isPublic) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.lock_rounded,
                                  size: 14,
                                  color: SynkColors.textSecondary,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          _MetaLine(
                            icon: Icons.schedule_rounded,
                            text: DiscoveryActivityCard.formatWhen(
                              activity.dateTime,
                            ),
                            color: activity.isPast
                                ? SynkColors.textSecondary
                                : SynkColors.orangeDark,
                          ),
                          if (hasLocation) ...[
                            const SizedBox(height: 4),
                            _MetaLine(
                              icon: Icons.place_outlined,
                              text: activity.location,
                              color: SynkColors.textSecondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: role),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildPeople()),
                    if (onChat != null) ...[
                      const SizedBox(width: 8),
                      _ChatPill(unreadCount: unreadCount, onTap: onChat!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (code == null && !canShare) return card;

    // The code and share sit on a strip that peeks out from under the card.
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _CardStrip.height + 20,
          child: _CardStrip(activity: activity, code: code, canShare: canShare),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: _CardStrip.height),
          child: card,
        ),
      ],
    );
  }

  Widget _buildPeople() {
    final people = participants;
    // Host counts as one. Pending users only get the count.
    final going = anonymous
        ? activity.joinedCount
        : people == null
        ? activity.joinedCount
        : 1 + people.length;
    final faces = anonymous
        ? List.filled((going - 1).clamp(0, 4), const <String, dynamic>{})
        : people?.take(4).toList() ?? const [];
    final full = going >= activity.maxParticipants;

    return Row(
      children: [
        if (faces.isNotEmpty) ...[
          SizedBox(
            // Each face is 26 wide, overlapping the previous one by 10.
            width: 26.0 + (faces.length - 1) * 16,
            height: 26,
            child: Stack(
              children: [
                for (final (i, p) in faces.indexed)
                  PositionedDirectional(
                    start: i * 16.0,
                    child: _Face(
                      avatarUrl: p['avatar_url'] as String?,
                      gender: p['gender'] as String?,
                      anonymous: anonymous,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ] else ...[
          const Icon(
            Icons.people_outline_rounded,
            size: 16,
            color: SynkColors.textSecondary,
          ),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            full
                ? appL10n.full
                : appL10n.joinedOfMaxGoing(going, activity.maxParticipants),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: full ? SynkColors.textSecondary : SynkColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardStrip extends StatelessWidget {
  const _CardStrip({
    required this.activity,
    required this.code,
    required this.canShare,
  });

  // The part that shows under the card.
  static const double height = 40;

  final Activity activity;
  final String? code;
  final bool canShare;

  @override
  Widget build(BuildContext context) {
    const color = SynkColors.tealText;
    final code = this.code;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: const Color(0xFFDDEDE9),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          // The top 20 is under the card.
          padding: const EdgeInsets.only(top: 20),
          child: Row(
            children: [
              if (code != null)
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    SynkFeedback.showToast(
                      context,
                      title: context.l10n.activityCodeCopied,
                    );
                  },
                  child: Semantics(
                    label: context.l10n.copyCode,
                    button: true,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        14,
                        0,
                        12,
                        0,
                      ),
                      child: Row(
                        children: [
                          Text(
                            context.l10n.code,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            code,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.copy_rounded,
                            size: 15,
                            color: color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              if (canShare)
                Builder(
                  builder: (buttonContext) => InkWell(
                    onTap: () => showShareToChatSheet(buttonContext, activity),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12,
                        0,
                        14,
                        0,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.ios_share_rounded,
                            size: 16,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.l10n.share,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatPill extends StatelessWidget {
  const _ChatPill({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Unread shows as the orange count, not a different pill.
    final unread = unreadCount > 0;
    const foreground = SynkColors.orangeDeep;

    return Material(
      color: SynkColors.orangeLight,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 16, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: foreground,
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.chat,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: SynkColors.orangeDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
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
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.avatarUrl,
    required this.gender,
    this.anonymous = false,
  });

  final String? avatarUrl;
  final String? gender;
  final bool anonymous;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl?.trim();
    final fallback = AvatarUploader.defaultImageForGender(gender);

    return Container(
      width: 26,
      height: 26,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: anonymous
          ? const AnonymousAvatar(size: 22)
          : ClipOval(
              child: Image(
                image: url != null && url.startsWith('http')
                    ? NetworkImage(url)
                    : fallback,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Image(image: fallback, fit: BoxFit.cover),
              ),
            ),
    );
  }
}

// Hosting as a crown; Joined and Requested in muted gray.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final MyActivityRole role;

  @override
  Widget build(BuildContext context) {
    final hosting = role == MyActivityRole.hosting;
    final color = hosting ? SynkColors.orangeDeep : SynkColors.textSecondary;

    // Hosting is just the crown.
    if (hosting) {
      return Semantics(label: role.label, child: const HostCrownBadge());
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: hosting
            ? SynkColors.orangeDark.withValues(alpha: 0.12)
            : SynkColors.textSecondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// One line that ends in "…", laid out in the text's own direction, so
// Arabic and English mixed together reads right.
class _BidiText extends StatelessWidget {
  const _BidiText(this.text, {required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final rtl = Bidi.detectRtlDirectionality(text);
    final uiRtl = Directionality.of(context) == TextDirection.rtl;

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      // Still lined up with the rest of the card.
      textAlign: uiRtl ? TextAlign.right : TextAlign.left,
      style: style,
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: _BidiText(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
