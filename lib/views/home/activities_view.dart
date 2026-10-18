import 'package:flutter/material.dart';

import '../../controllers/activity_delete_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/activity_model.dart';
import '../../utils/custom_widgets/synk_dialog.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'activity_join_requests_view.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/activity_list.dart';

class ActivitiesView extends StatefulWidget {
  const ActivitiesView({super.key, required this.activityStore});

  final ActivityStore activityStore;

  @override
  State<ActivitiesView> createState() => _ActivitiesViewState();
}

class _ActivitiesViewState extends State<ActivitiesView> {
  late final ActivityDeleteController _deleteController;
  late final Listenable _activityChanges;

  @override
  void initState() {
    super.initState();

    _deleteController = ActivityDeleteController();

    // Rebuilds the activity lists when either the store changes
    // or a delete operation starts or finishes.
    _activityChanges = Listenable.merge([
      widget.activityStore,
      _deleteController,
    ]);
  }

  @override
  void dispose() {
    _deleteController.dispose();
    super.dispose();
  }

  void _openJoinRequests(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return const ActivityJoinRequestsView();
        },
      ),
    );
  }

  // Resolves to true only when the activity was deleted.
  // [showError] lets a caller display failures where the user can see them.
  Future<bool> _confirmDelete(
    Activity activity, {
    void Function(String message)? showError,
  }) async {
    if (_deleteController.isDeleting(activity.id)) {
      return false;
    }

    final action = await SynkDialog.destructive(
      icon: Icons.delete_outline_rounded,
      title: 'Delete activity?',
      message: 'This action cannot be undone. The activity will be removed for everyone.',
      primaryLabel: 'Keep Activity',
      secondaryLabel: 'Delete Activity',
    ).show(context, barrierDismissible: false);

    // The destructive action is the secondary button.
    if (action != SynkDialogAction.secondary || !mounted) {
      return false;
    }

    final wasDeleted = await _deleteController.deleteActivity(activity.id);

    if (!mounted) return wasDeleted;

    if (!wasDeleted) {
      final message =
          _deleteController.errorMessage ??
          'Unable to delete the activity. Please try again.';

      if (showError != null) {
        showError(message);
      } else {
        SynkFeedback.showError(context, message);
      }
      return false;
    }

    // Remove the deleted activity immediately from Home and Activities.
    widget.activityStore.removeById(activity.id);

    await SynkFeedback.showSuccessDialog(
      context,
      title: 'Activity Deleted',
      message: 'The activity has been deleted successfully.',
    );

    return true;
  }

  void _openDetails(Activity activity) {
    // An activity that is being deleted cannot be opened.
    if (_deleteController.isDeleting(activity.id)) {
      return;
    }

    showActivityDetailsSheet(
      context: context,
      activity: activity,
      activityStore: widget.activityStore,
      onDeleteActivity: (target, showError) =>
          _confirmDelete(target, showError: showError),
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
                  animation: _activityChanges,
                  builder: (context, _) {
                    return TabBarView(
                      children: [
                        ActivityList(
                          activities: widget.activityStore.upcoming,
                          currentUserId: widget.activityStore.currentUserId,
                          emptyIcon: Icons.event_available_rounded,
                          emptyTitle: 'No upcoming activities',
                          emptyMessage: 'Tap the + button to plan one.',
                          onDeleteActivity: _confirmDelete,
                          isDeletingActivity: _deleteController.isDeleting,
                          onActivityTap: _openDetails,
                        ),
                        ActivityList(
                          activities: widget.activityStore.past,
                          currentUserId: widget.activityStore.currentUserId,
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
