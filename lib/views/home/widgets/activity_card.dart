import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../models/activity_model.dart';

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.activity});

  final Activity activity;

  String get _dateLabel {
    final d = activity.dateTime;
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
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day} · $hour:$minute $period';
  }

  // Height of the wide cover image. Kept compact so roughly two to two and
  // a half cards fit on the Home screen at once.
  static const double _coverHeight = 128;

  // Crop position for uploaded photos: horizontally centred, biased towards
  // the top so faces and the upper part of portrait photos stay in view.
  // (-1 = top edge, 0 = centre.) The default cover is not affected.
  static const Alignment _photoAlignment = Alignment(0, -0.3);

  // Shown when the activity has no photo, or its photo fails to load.
  static const String _defaultCoverAsset = 'assets/synk_jumping.png';

  // Date text colour from the approved card proposal (a darker orange that
  // stays readable on white at this size).
  static const Color _dateColor = Color(0xFFC4531A);

  // The activity photo as a full-width cover. While it loads, a soft neutral
  // fill is shown; if it fails to load, the Synk default cover is shown.
  Widget _buildCover() {
    final photoUrl = activity.photoUrl;
    if (photoUrl == null || photoUrl.isEmpty) return _buildDefaultCover();

    return Image.network(
      photoUrl,
      width: double.infinity,
      height: _coverHeight,
      fit: BoxFit.cover,
      alignment: _photoAlignment,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Container(
              width: double.infinity,
              height: _coverHeight,
              color: SynkColors.backgroundLight,
            ),
      errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
    );
  }

  // The Synk banner, cropped (never stretched) from the left so the logo and
  // name stay visible; the tagline on the far right may be cut off.
  Widget _buildDefaultCover() {
    return Image.asset(
      _defaultCoverAsset,
      width: double.infinity,
      height: _coverHeight,
      fit: BoxFit.cover,
      alignment: Alignment.centerLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: SynkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
