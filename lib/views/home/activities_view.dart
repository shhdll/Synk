import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../models/activity_model.dart';
import 'activity_join_requests_view.dart';
import 'widgets/activity_list.dart';

class ActivitiesView extends StatelessWidget {
  const ActivitiesView({super.key, required this.activityStore});

  final ActivityStore activityStore;

  void _openJoinRequests(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return const ActivityJoinRequestsView();
        },
      ),
    );
  }

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

              // Opens requests for private activities hosted by this user.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _openJoinRequests(context);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: SynkColors.textSecondary.withValues(
                            alpha: 0.10,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: SynkColors.orangeDark.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.pending_actions_rounded,
                              color: SynkColors.orangeDark,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Join Requests',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: SynkColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Review requests for your private activities.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: SynkColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: SynkColors.textSecondary,
                          ),
                        ],
                      ),
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
                          currentUserId: activityStore.currentUserId,
                          emptyIcon: Icons.event_available_rounded,
                          emptyTitle: 'No upcoming activities',
                          emptyMessage: 'Tap the + button to plan one.',
                        ),
                        ActivityList(
                          activities: activityStore.past,
                          currentUserId: activityStore.currentUserId,
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
