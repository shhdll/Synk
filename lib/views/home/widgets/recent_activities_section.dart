import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activities_model.dart';
import '../../../models/activity_model.dart';
import 'activity_thumbnail.dart';

// A friend's latest ended activities, three to a row, in a card that folds.
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
  static const int _previewCount = 12;

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

  @override
  Widget build(BuildContext context) {
    if (_activities.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: FoldCard(
        title: context.l10n.recentActivities,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final width = (constraints.maxWidth - gap * 2) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final activity in _activities)
                  RecentActivityTile(activity: activity, width: width),
              ],
            );
          },
        ),
      ),
    );
  }
}

// The profile's card style; tapping the title folds it away.
class FoldCard extends StatefulWidget {
  const FoldCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<FoldCard> createState() => _FoldCardState();
}

class _FoldCardState extends State<FoldCard> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textSecondary,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_open) ...[
              const SizedBox(height: 4),
              widget.child,
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

// Image, title and date of one ended activity.
class RecentActivityTile extends StatelessWidget {
  const RecentActivityTile({
    super.key,
    required this.activity,
    this.width = 104,
  });

  final Activity activity;
  final double width;

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
