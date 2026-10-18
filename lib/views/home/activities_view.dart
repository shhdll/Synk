import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../controllers/activity_delete_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../utils/custom_widgets/synk_dialog.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../widgets/synk_blob_background.dart';
import 'activity_code_join_sheet.dart';
import 'activity_join_requests_view.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/code_bubble.dart';
import 'widgets/empty_state.dart';
import 'widgets/my_activity_card.dart';
import 'widgets/synk_filter_chip.dart';

// Which of the user's activities to list: everything, or by their role.
enum _RoleFilter {
  all('All'),
  hosting('Hosting'),
  joined('Joined'),
  requested('Requested');

  const _RoleFilter(this.label);
  final String label;

  bool matches(MyActivityRole role) => switch (this) {
    all => true,
    hosting => role == MyActivityRole.hosting,
    joined => role == MyActivityRole.joined,
    requested =>
      role == MyActivityRole.pending || role == MyActivityRole.waitlisted,
  };
}

class ActivitiesView extends StatefulWidget {
  const ActivitiesView({super.key, required this.activityStore});

  final ActivityStore activityStore;

  @override
  State<ActivitiesView> createState() => _ActivitiesViewState();
}

class _ActivitiesViewState extends State<ActivitiesView> {
  final ActivitiesModel _activitiesModel = ActivitiesModel();
  late final ActivityDeleteController _deleteController;
  late final Listenable _changes;

  bool _showPast = false;
  _RoleFilter _filter = _RoleFilter.all;
  bool _codeBubbleExpanded = true;

  // Joined members per activity id, for the faces on each card. Loaded
  // once per activity; cleared on pull-to-refresh.
  final Map<String, List<Map<String, dynamic>>> _people = {};
  final Set<String> _loadingPeople = {};

  ActivityStore get _store => widget.activityStore;

  @override
  void initState() {
    super.initState();
    _deleteController = ActivityDeleteController();
    _changes = Listenable.merge([_store, _deleteController]);
    _store.addListener(_loadMissingPeople);
    _loadMissingPeople();
  }

  @override
  void dispose() {
    _store.removeListener(_loadMissingPeople);
    _deleteController.dispose();
    super.dispose();
  }

  void _loadMissingPeople() {
    for (final activity in _store.all) {
      final id = activity.id;
      if (_people.containsKey(id) || !_loadingPeople.add(id)) continue;
      _activitiesModel
          .fetchParticipantsList(id)
          .then((list) {
            if (!mounted) return;
            setState(() {
              _people[id] = [
                for (final p in list)
                  if (p['user_id'] != activity.hostId) p,
              ];
            });
          })
          .whenComplete(() => _loadingPeople.remove(id));
    }
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        _activitiesModel.fetchMine(),
        _activitiesModel.fetchParticipating(),
      ]);
      if (!mounted) return;
      _people.clear();
      _store
        ..setMine(results[0])
        ..setParticipating(results[1]);
    } catch (_) {
      // Keep the current lists when refreshing fails.
    }
  }

  void _openJoinRequests() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityJoinRequestsView(activityStore: _store),
      ),
    );
  }

  void _openActivity(Activity activity) {
    final canDelete =
        activity.isHostedBy(_store.currentUserId) && !activity.isPast;
    showActivityDetailsSheet(
      context: context,
      activity: activity,
      activityStore: _store,
      onDelete: canDelete ? () => _confirmDelete(activity) : null,
    );
  }

  // Same as Home: shrink the code bubble to its key while scrolling down,
  // and bring the label back on scrolling up or at the top.
  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    final atTop = notification.metrics.pixels <= 0;
    final expand = atTop || notification.direction == ScrollDirection.forward;
    final collapse = notification.direction == ScrollDirection.reverse;
    if (expand && !_codeBubbleExpanded) {
      setState(() => _codeBubbleExpanded = true);
    } else if (collapse && !atTop && _codeBubbleExpanded) {
      setState(() => _codeBubbleExpanded = false);
    }
    return false;
  }

  Future<void> _confirmDelete(Activity activity) async {
    final action = await SynkDialog.destructive(
      icon: Icons.delete_outline_rounded,
      title: 'Delete activity?',
      message: 'This action cannot be undone. The activity will be removed for everyone.',
      primaryLabel: 'Keep Activity',
      secondaryLabel: 'Delete Activity',
    ).show(context, barrierDismissible: false);

    // The destructive action is the secondary button.
    if (action != SynkDialogAction.secondary || !mounted) return;

    final wasDeleted = await _deleteController.deleteActivity(activity.id);

    if (!mounted) return;

    if (!wasDeleted) {
      SynkFeedback.showError(
        context,
        _deleteController.errorMessage ??
            'Unable to delete the activity. Please try again.',
      );
      return;
    }

    // Remove the deleted activity immediately from Home and Activities.
    _store.removeById(activity.id);

    await SynkFeedback.showSuccessDialog(
      context,
      title: 'Activity Deleted',
      message: 'The activity has been deleted successfully.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: SynkBlobBackground()),
          SafeArea(
            bottom: false,
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onUserScroll,
              child: RefreshIndicator(
                color: SynkColors.orangeDark,
                backgroundColor: Colors.white,
                onRefresh: _refresh,
                child: ListenableBuilder(
                  listenable: _changes,
                  builder: (context, _) => _buildList(bottomInset),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            // Clears the raised + button, which sits ~30px above the bar.
            bottom: bottomInset + 44,
            child: CodeBubble(
              expanded: _codeBubbleExpanded,
              onTap: () => joinActivityWithCode(context, activityStore: _store),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(double bottomInset) {
    final userId = _store.currentUserId;
    final inTab = _showPast ? _store.past : _store.upcoming;
    final roles = {for (final a in inTab) a.id: MyActivityRole.of(a, userId)};

    int countOf(_RoleFilter f) =>
        inTab.where((a) => f.matches(roles[a.id]!)).length;

    // Only offer roles the user actually has in this tab; fall back to
    // All if the chosen one has emptied out.
    final filters = [
      for (final f in _RoleFilter.values)
        if (f == _RoleFilter.all || countOf(f) > 0) f,
    ];
    final filter = filters.contains(_filter) ? _filter : _RoleFilter.all;
    final shown = inTab.where((a) => filter.matches(roles[a.id]!)).toList();

    final hostsPrivate = _store.mine.any((a) => !a.isPublic);
    final showRequests = hostsPrivate || _store.pendingRequestCount > 0;

    return ListView(
      // Room for the code bubble and the bottom bar.
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 120),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
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
        const SizedBox(height: 16),
        if (showRequests) ...[
          _JoinRequestsRow(
            count: _store.pendingRequestCount,
            onTap: _openJoinRequests,
          ),
          const SizedBox(height: 14),
        ],
        _Segmented(
          showPast: _showPast,
          onChanged: (past) => setState(() {
            _showPast = past;
            _filter = _RoleFilter.all;
          }),
        ),
        if (filters.length > 2) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in filters) ...[
                  SynkFilterChip(
                    label: '${f.label}  ${countOf(f)}',
                    selected: f == filter,
                    onTap: () => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: _showPast
                ? const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No past activities',
                    message:
                        "Activities you've been part of will show up here.",
                  )
                : const EmptyState(
                    icon: Icons.event_available_rounded,
                    title: 'No upcoming activities',
                    message: 'Join one from Home, or tap + to plan your own.',
                  ),
          )
        else
          for (final activity in shown) ...[
            MyActivityCard(
              activity: activity,
              role: roles[activity.id]!,
              participants: _people[activity.id],
              // Pending requesters see members as anonymous faces.
              anonymous: roles[activity.id] == MyActivityRole.pending,
              onTap: () => _openActivity(activity),
              // Anyone taking part can share the code; it's no use once
              // the activity has started.
              showCode: !activity.isPast,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

// Upcoming / Past switch.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.showPast, required this.onChanged});

  final bool showPast;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, bool past) {
      final selected = showPast == past;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(past),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? SynkColors.orangeDark : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : SynkColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [segment('Upcoming', false), segment('Past', true)]),
    );
  }
}

class _JoinRequestsRow extends StatelessWidget {
  const _JoinRequestsRow({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: SynkColors.orangeDark.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  color: SynkColors.orangeDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Join Requests',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: SynkColors.badge,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
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
    );
  }
}
