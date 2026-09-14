import 'package:flutter/material.dart';

import '../../../models/activity_model.dart';
import 'activity_card.dart';
import 'empty_state.dart';

// A list of activity cards for one tab (upcoming/past) of the Activities
// screen, falling back to an empty state when there's nothing to show.
class ActivityList extends StatelessWidget {
  const ActivityList({
    super.key,
    required this.activities,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<Activity> activities;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

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
      itemBuilder: (context, index) =>
          ActivityCard(activity: activities[index]),
    );
  }
}
