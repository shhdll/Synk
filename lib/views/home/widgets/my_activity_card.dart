import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../models/activity_model.dart';
import '../../../models/avatar_uploader.dart';
import '../../widgets/anonymous_avatar.dart';
import 'activity_thumbnail.dart';
import 'discovery_activity_card.dart';

// The user's part in an activity, shown as a pill on the Activities tab.
enum MyActivityRole {
  hosting('Hosting', Icons.star_rounded, SynkColors.orangeDark),
  joined('Joined', Icons.check_circle_rounded, SynkColors.teal),
  pending('Requested', Icons.schedule_rounded, Color(0xFFD9822B)),
  waitlisted('Waitlisted', Icons.hourglass_top_rounded, Color(0xFF8A6D3B));

  const MyActivityRole(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  static MyActivityRole of(Activity activity, String? userId) {
    if (activity.isHostedBy(userId)) return hosting;
    if (activity.isPending) return pending;
    if (activity.isWaitlisted) return waitlisted;
    return joined;
  }
}

// Activities tab card, in the same style as the Home cards: what, when,
// where, then who's going (faces + count) and the user's role.
class MyActivityCard extends StatelessWidget {
  const MyActivityCard({
    super.key,
    required this.activity,
    required this.role,
    required this.participants,
    required this.onTap,
    this.showCode = false,
    this.anonymous = false,
  });

  // Members' faces are hidden behind anonymous avatars (the viewer's
  // request is still pending).
  final bool anonymous;

  final Activity activity;
  final MyActivityRole role;
  // Joined members (not the host); null while loading.
  final List<Map<String, dynamic>>? participants;
  final VoidCallback onTap;
  // Hosts and accepted members see the code as a thin strip under the
  // card (when the server sent one).
  final bool showCode;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));
    final hasLocation = activity.location.trim().isNotEmpty;

    return DecoratedBox(
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
            padding: const EdgeInsets.all(14),
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
                              Expanded(
                                child: Text(
                                  activity.title.trim().isEmpty
                                      ? 'Untitled activity'
                                      : activity.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                  size: 15,
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
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildPeople()),
                    const SizedBox(width: 8),
                    _RolePill(role: role),
                  ],
                ),
                if (showCode && activity.hasActivityCode) ...[
                  const SizedBox(height: 10),
                  _CodeStrip(code: activity.activityCode!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeople() {
    final people = participants;
    // The host counts as one of the people going, as on Home.
    // Pending requesters aren't sent the member list, so their anonymous
    // faces come from the count.
    final going = anonymous
        ? activity.joinedCount
        : people == null
        ? activity.joinedCount
        : 1 + people.length;
    final faces = anonymous
        ? List.filled((going - 1).clamp(0, 4), const <String, dynamic>{})
        : people?.take(4).toList() ?? const [];

    return Row(
      children: [
        if (faces.isNotEmpty) ...[
          SizedBox(
            width: 22.0 + (faces.length - 1) * 16,
            height: 26,
            child: Stack(
              children: [
                for (final (i, p) in faces.indexed)
                  Positioned(
                    left: i * 16.0,
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
            '$going/${activity.maxParticipants} going',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SynkColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// One-line "Code 482913 ⧉" strip; tapping it copies the code.
class _CodeStrip extends StatelessWidget {
  const _CodeStrip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SynkColors.orangeDark.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: code));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Activity code copied')),
            );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            children: [
              const Icon(
                Icons.password_rounded,
                size: 14,
                color: SynkColors.orangeDark,
              ),
              const SizedBox(width: 6),
              const Text(
                'Code',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                code,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: SynkColors.orangeDark,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.copy_rounded,
                size: 14,
                color: SynkColors.orangeDark,
              ),
            ],
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

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final MyActivityRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: role.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 13, color: role.color),
          const SizedBox(width: 5),
          Text(
            role.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: role.color,
            ),
          ),
        ],
      ),
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
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
