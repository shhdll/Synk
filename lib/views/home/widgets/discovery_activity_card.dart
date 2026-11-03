import 'package:flutter/material.dart';

import '../../../controllers/friends_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_model.dart';
import '../../../models/avatar_uploader.dart';
import '../../../models/friends_model.dart';
import 'activity_status_chip.dart';
import 'activity_thumbnail.dart';
import 'friends_going.dart';

// Compact home feed card. Reading order: title, when and where, who is
// hosting, how many have joined. Tapping opens the details sheet.
class DiscoveryActivityCard extends StatelessWidget {
  const DiscoveryActivityCard({
    super.key,
    required this.activity,
    required this.onTap,
  });

  final Activity activity;
  final VoidCallback onTap;

  static String formatWhen(DateTime date, {DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final day = DateUtils.dateOnly(date);
    final dayDiff = day.difference(today).inDays;
    final time = formatTime(date.hour, date.minute);

    if (dayDiff == 0) return appL10n.todayAtTime(time);
    if (dayDiff == 1) return appL10n.tomorrowAtTime(time);
    return '${formatShortDate(date)} · $time';
  }

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));

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
                    ActivityThumbnail(activity: activity, size: 80, radius: 14),
                    const SizedBox(width: 14),
                    Expanded(child: _buildDetails()),
                  ],
                ),
                const SizedBox(height: 14),
                ListenableBuilder(
                  listenable: FriendsController.instance,
                  builder: (context, _) => _buildFooter(
                    FriendsController.instance.friendsGoingIn(activity.id),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    final hasLocation = activity.location.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.title.trim().isEmpty
              ? appL10n.untitledActivity
              : activity.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.25,
            letterSpacing: -0.2,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        _MetaLine(
          icon: Icons.schedule_rounded,
          text: formatWhen(activity.dateTime),
          color: SynkColors.orangeDark,
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
    );
  }

  // Host on the left and the count on the right; friends who are going get
  // a line underneath with their photos and who is going.
  Widget _buildFooter(List<FriendUser> going) {
    // The host already has their own row, so they aren't "going" too.
    final friendsGoing = [
      for (final f in going)
        if (f.id != activity.hostId) f,
    ];
    final handle = activity.hostUsername?.trim();
    final hostLabel = handle != null && handle.isNotEmpty
        ? '@$handle'
        : (activity.hostName?.trim().isNotEmpty ?? false)
        ? activity.hostName!.trim()
        : appL10n.synkMember;
    final avatarUrl = activity.hostAvatarUrl?.trim();

    final hostRow = Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: SynkColors.backgroundLight,
          backgroundImage: avatarUrl != null && avatarUrl.startsWith('http')
              ? NetworkImage(avatarUrl)
              : AvatarUploader.defaultImageForGender(activity.hostGender),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hostLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: SynkColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ActivityStatusChip.count(
          availability: activity.availability,
          label:
              '${activity.joinedCount}/${activity.maxParticipants} '
              '${activity.availability.label}',
        ),
      ],
    );

    if (friendsGoing.isEmpty) return hostRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hostRow,
        const SizedBox(height: 10),
        Row(
          children: [
            FriendAvatarStack(friends: friendsGoing, size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                friendsGoingText(friendsGoing),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
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
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
