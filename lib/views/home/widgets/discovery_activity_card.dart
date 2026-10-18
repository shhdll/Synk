import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../models/activity_model.dart';
import '../../../models/avatar_uploader.dart';
import 'activity_status_chip.dart';
import 'activity_thumbnail.dart';

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

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String formatWhen(DateTime date, {DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final day = DateUtils.dateOnly(date);
    final dayDiff = day.difference(today).inDays;

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $period';

    if (dayDiff == 0) return 'Today, $time';
    if (dayDiff == 1) return 'Tomorrow, $time';
    return '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} '
        '${date.day} · $time';
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
                _buildFooter(),
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
          activity.title.trim().isEmpty ? 'Untitled activity' : activity.title,
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

  Widget _buildFooter() {
    final handle = activity.hostUsername?.trim();
    final hostLabel = handle != null && handle.isNotEmpty
        ? '@$handle'
        : (activity.hostName?.trim().isNotEmpty ?? false)
        ? activity.hostName!.trim()
        : 'Synk member';
    final avatarUrl = activity.hostAvatarUrl?.trim();

    return Row(
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
        const Icon(
          Icons.people_outline_rounded,
          size: 15,
          color: SynkColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          '${activity.joinedCount}/${activity.maxParticipants} going',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SynkColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        ActivityStatusChip(availability: activity.availability),
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
