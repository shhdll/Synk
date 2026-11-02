import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activities_model.dart';
import '../../../models/activity_model.dart';
import '../user_activity_history_view.dart';
import 'activity_thumbnail.dart';

// A friend's latest ended activities in a horizontal list, with See all.
// Hidden while loading, on errors, and when nothing is visible to the viewer.
class RecentActivitiesSection extends StatefulWidget {
  const RecentActivitiesSection({
    super.key,
    required this.userId,
    required this.userName,
    this.activitiesModel,
  });

  final String userId;
  final String userName;

  // Injectable for tests.
  final ActivitiesModel? activitiesModel;

  @override
  State<RecentActivitiesSection> createState() =>
      _RecentActivitiesSectionState();
}

class _RecentActivitiesSectionState extends State<RecentActivitiesSection> {
  static const int _previewCount = 10;

  List<Activity> _activities = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await (widget.activitiesModel ?? ActivitiesModel())
          .fetchUserRecentActivities(
            userId: widget.userId,
            limit: _previewCount,
          );
      if (!mounted || !page.allowed) return;
      setState(() => _activities = page.activities);
    } catch (_) {
      // The section stays hidden when the history cannot be loaded.
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserActivityHistoryView(
          userId: widget.userId,
          userName: widget.userName,
          activitiesModel: widget.activitiesModel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activities.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      // Same card style as the profile's About and Interests.
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 6, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: SynkColors.textSecondary.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.recentActivities,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SynkColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openHistory,
                  style: TextButton.styleFrom(
                    foregroundColor: SynkColors.orangeDark,
                    minimumSize: const Size(44, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.l10n.seeAll,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 160,
              // Starts from the reading direction, so Arabic scrolls from
              // the right.
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsetsDirectional.only(end: 8),
                itemCount: _activities.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return RecentActivityTile(activity: _activities[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Image, title and date of one ended activity.
class RecentActivityTile extends StatelessWidget {
  const RecentActivityTile({super.key, required this.activity});

  static const double width = 104;

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActivityThumbnail(activity: activity, size: width, radius: 14),
          const SizedBox(height: 6),
          Text(
            activity.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SynkColors.textPrimary,
            ),
          ),
          Text(
            formatShortDate(activity.dateTime),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: SynkColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
