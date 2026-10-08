import 'package:flutter/material.dart';

import '../../../models/activity_model.dart';
import 'activity_card.dart';
import 'empty_state.dart';

// Displays activity cards and shows an empty state when no activities exist.
class ActivityList extends StatelessWidget {
  const ActivityList({
    super.key,
    required this.activities,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.currentUserId,
  });

  final List<Activity> activities;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      itemCount: activities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final activity = activities[index];

        // Only the host can view the code of an upcoming activity.
        final canViewCode =
            !activity.isPast &&
            activity.isHostedBy(currentUserId);

        return ActivityCard(
          activity: activity,
          showActivityCode: canViewCode,
        );
      },
    );
  }
}