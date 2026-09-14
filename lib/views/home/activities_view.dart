import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../models/activity_model.dart';
import 'widgets/activity_list.dart';

class ActivitiesView extends StatelessWidget {
  const ActivitiesView({super.key, required this.activityStore});

  final ActivityStore activityStore;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: SynkColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Activities',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: SynkColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const TabBar(
                    tabs: [
                      Tab(text: 'Upcoming'),
                      Tab(text: 'Past'),
                    ],
                    labelColor: Colors.white,
                    unselectedLabelColor: SynkColors.textSecondary,
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    indicator: BoxDecoration(
                      color: SynkColors.orangeDark,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                  ),
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: activityStore,
                  builder: (context, _) {
                    return TabBarView(
                      children: [
                        ActivityList(
                          activities: activityStore.upcoming,
                          emptyIcon: Icons.event_available_rounded,
                          emptyTitle: 'No upcoming activities',
                          emptyMessage: 'Tap the + button to plan one.',
                        ),
                        ActivityList(
                          activities: activityStore.past,
                          emptyIcon: Icons.history_rounded,
                          emptyTitle: 'No past activities',
                          emptyMessage:
                              "Activities you've attended will show up here.",
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
