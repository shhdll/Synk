import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../models/activity_model.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.showActivityCode = false,
    this.onDelete,
    this.isDeleting = false,
  });

  final Activity activity;
  final bool showActivityCode;

  // Provided only when the current user is the activity host.
  final VoidCallback? onDelete;

  // Disables the button and shows loading while deletion is running.
  final bool isDeleting;

  static const double _coverHeight = 128;
  static const Alignment _photoAlignment = Alignment(0, -0.3);
  static const String _defaultCoverAsset = 'assets/synk_jumping.png';
  static const Color _dateColor = Color(0xFFC4531A);

  String get _dateLabel {
    final date = activity.dateTime;

    const months = [
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

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${months[date.month - 1]} ${date.day} · '
        '$hour:$minute $period';
  }

  Widget _buildCover() {
    final photoUrl = activity.photoUrl;

    if (photoUrl == null || photoUrl.isEmpty) {
      return _buildDefaultCover();
    }

    return Image.network(
      photoUrl,
      width: double.infinity,
      height: _coverHeight,
      fit: BoxFit.cover,
      alignment: _photoAlignment,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;

        return Container(
          width: double.infinity,
          height: _coverHeight,
          color: SynkColors.backgroundLight,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildDefaultCover();
      },
    );
  }

  Widget _buildDefaultCover() {
    return Image.asset(
      _defaultCoverAsset,
      width: double.infinity,
      height: _coverHeight,
      fit: BoxFit.cover,
      alignment: Alignment.centerLeft,
    );
  }

  // Displays the current user's participation state.
  Widget? _buildParticipationBadge() {
    final String label;
    final IconData icon;
    final Color color;

    if (activity.isPending) {
      label = 'Pending approval';
      icon = Icons.schedule_rounded;
      color = const Color(0xFFD9822B);
    } else if (activity.isWaitlisted) {
      label = 'Waitlisted';
      icon = Icons.hourglass_top_rounded;
      color = const Color(0xFF8A6D3B);
    } else if (activity.isJoined) {
      label = 'Joined';
      icon = Icons.check_circle_rounded;
      color = const Color(0xFF3D8B5A);
    } else {
      return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Shows the activity code only to the activity host.
  Widget _buildActivityCode(BuildContext context) {
    final code = activity.activityCode;

    if (!showActivityCode || code == null || code.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: SynkColors.orangeDark.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SynkColors.orangeDark.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.password_rounded,
            size: 19,
            color: SynkColors.orangeDark,
          ),
          const SizedBox(width: 9),
          const Text(
            'Activity code',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SynkColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            code,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: SynkColors.orangeDark,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy code',
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: code),
              );

              if (!context.mounted) return;

              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Activity code copied'),
                  ),
                );
            },
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: SynkColors.orangeDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final participationBadge = _buildParticipationBadge();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _coverHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCover(),
                // Only the host receives an onDelete callback,
// so other users never see this button.
if (onDelete != null)
  Positioned(
    top: 10,
    left: 10,
    child: Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: 'Delete activity',
        onPressed: isDeleting ? null : onDelete,
        icon: isDeleting
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFE85D5D),
                ),
              )
            : const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFE85D5D),
                size: 21,
              ),
      ),
    ),
  ),

                // Private badge.
                if (!activity.isPublic)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: SynkColors.textPrimary,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Private',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: SynkColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Activity title and participation status.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        activity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: SynkColors.textPrimary,
                        ),
                      ),
                    ),
                    if (participationBadge != null) ...[
                      const SizedBox(width: 8),
                      participationBadge,
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: _dateColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _dateLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _dateColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 15,
                      color: SynkColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        activity.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                _buildActivityCode(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}