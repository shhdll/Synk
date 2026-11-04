import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/activity_delete_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/activity_rating_model.dart';
import '../../utils/custom_widgets/synk_dialog.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../widgets/synk_blob_background.dart';
import 'activity_code_join_sheet.dart';
import 'activity_join_requests_view.dart';
import 'chat_room_view.dart';
import 'schedule_conflict_resolution_view.dart';
import 'widgets/activities_filter_sheet.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/activity_rating_sheet.dart';
import 'widgets/code_bubble.dart';
import 'widgets/empty_state.dart';
import 'widgets/my_activity_card.dart';
import '../create_activity/create_activity_view.dart';
import 'main_shell.dart';

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
  ActivityRoleFilter _filter = ActivityRoleFilter.all;
  ActivityVisibility _visibility = ActivityVisibility.all;
  bool _codeBubbleExpanded = true;
  List<Map<String, dynamic>> _scheduleConflicts = const [];
  bool _loadingScheduleConflicts = false;

  // Participants per activity, for the faces on the cards.
  final Map<String, List<Map<String, dynamic>>> _people = {};
  final Set<String> _loadingPeople = {};

  // Ended activities the user can still rate, by activity id.
  final ActivityRatingModel _ratingModel = ActivityRatingModel();
  Map<String, PendingActivityRating> _pendingRatings = const {};

  ActivityStore get _store => widget.activityStore;

  @override
  void initState() {
    super.initState();
    _deleteController = ActivityDeleteController();
    _changes = Listenable.merge([
      _store,
      _deleteController,
      ChatController.instance,
    ]);
    _store.addListener(_loadMissingPeople);
    _store.addListener(_takeDetailsFocus);
    _loadMissingPeople();
    unawaited(_loadScheduleConflicts());
    unawaited(_loadPendingRatings());
  }

  Future<void> _loadPendingRatings() async {
    try {
      final pending = await _ratingModel.fetchPending();
      if (!mounted) return;
      setState(() {
        _pendingRatings = {for (final p in pending) p.activity.id: p};
      });
    } catch (_) {
      // Rating is optional; the button just doesn't show.
    }
  }

  // Everyone in the past activity, with the stars the user gave before.
  Future<void> _rate(Activity activity) async {
    PendingActivityRating? rating;
    try {
      rating = await _ratingModel.fetchForActivity(activity.id);
    } catch (_) {}
    if (!mounted) return;
    if (rating == null || rating.participants.isEmpty) {
      SynkFeedback.showToast(
        context,
        title: context.l10n.ratingActivityUnavailable,
        success: false,
      );
      return;
    }
    await showActivityRatingSheet(
      context: context,
      pending: rating,
      fromPast: true,
    );
    await _loadPendingRatings();
  }

  @override
  void dispose() {
    _store.removeListener(_loadMissingPeople);
    _store.removeListener(_takeDetailsFocus);
    _deleteController.dispose();
    super.dispose();
  }

  // Opens an activity the shell asked for, e.g. one just created.
  void _takeDetailsFocus() {
    final focus = _store.takeDetailsFocus();
    if (focus == null) return;
    setState(() {
      _showPast = false;
      _filter = ActivityRoleFilter.all;
      _visibility = ActivityVisibility.all;
    });
    // After the tab switch has been drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openActivity(_store.byId(focus.id) ?? focus);
    });
  }

  void _loadMissingPeople() {
    unawaited(_loadScheduleConflicts());
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
    unawaited(MainShell.checkAccount());
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
      await _loadScheduleConflicts();
    } catch (_) {}
  }

  Future<void> _loadScheduleConflicts() async {
    if (_loadingScheduleConflicts) return;
    _loadingScheduleConflicts = true;
    try {
      final conflicts = await _activitiesModel.fetchScheduleConflicts();
      if (mounted) setState(() => _scheduleConflicts = conflicts);
    } catch (_) {
      // Keep the last known warning visible if refresh fails.
    } finally {
      _loadingScheduleConflicts = false;
    }
  }

  Future<void> _openScheduleConflicts() async {
    await showScheduleConflictResolutionDialog(context);
    await _loadScheduleConflicts();
    await _refresh();
  }

  void _openJoinRequests() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActivityJoinRequestsView(activityStore: _store),
      ),
    );
  }

  // The activity's group chat; loads the chats first if it isn't there yet.
  Future<void> _openChat(Activity activity) async {
    final chats = ChatController.instance;
    var chat = chats.activityChatFor(activity.id);
    if (chat == null) {
      await chats.refresh();
      chat = chats.activityChatFor(activity.id);
    }
    if (!mounted) return;
    if (chat == null) {
      SynkFeedback.showToast(
        context,
        title: context.l10n.couldntOpenChat,
        success: false,
      );
      return;
    }
    await openChatRoom(context, chat, activityStore: widget.activityStore);
  }

  void _openActivity(Activity activity) {
    final canDelete =
        activity.isHostedBy(_store.currentUserId) && !activity.isPast;
    showActivityDetailsSheet(
      context: context,
      activity: activity,
      activityStore: _store,
      onDelete: canDelete ? () => _confirmDelete(activity) : null,
      onEdit: canDelete ? () => _editActivity(activity) : null,
    );
  }

  Future<void> _editActivity(Activity activity) async {
    final outcome = await Navigator.of(context).push<CreateActivityOutcome>(
      MaterialPageRoute(
        builder: (_) => CreateActivityView(store: _store, activity: activity),
      ),
    );
    if (!mounted || outcome == null) return;
    _store.upsert(outcome.activity);
    SynkFeedback.showSuccessDialog(
      context,
      title: context.l10n.changesSavedBanner,
      message: context.l10n.yourActivityDetailsHaveBeenUpdated,
    );
  }

  // Minimise the code bubble as soon as the list scrolls down; show the
  // label again only back at the top.
  bool _onUserScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final expand = notification.metrics.pixels <= 0;
    if (expand != _codeBubbleExpanded) {
      setState(() => _codeBubbleExpanded = expand);
    }
    return false;
  }

  Future<void> _confirmDelete(Activity activity) async {
    final delete = await SynkDialog.confirm(
      context,
      icon: Icons.delete_outline_rounded,
      title: context.l10n.deleteActivityTitle,
      message: context.l10n.thisActionCannotBeUndoneThe,
      action: context.l10n.deleteLabel,
    );
    if (!delete || !mounted) return;

    final wasDeleted = await _deleteController.deleteActivity(activity.id);

    if (!mounted) return;

    if (!wasDeleted) {
      SynkFeedback.showError(
        context,
        _deleteController.errorMessage ??
            context.l10n.unableToDeleteTheActivityPlease,
      );
      return;
    }

    // Remove the deleted activity immediately from Home and Activities.
    _store.removeById(activity.id);

    await SynkFeedback.showSuccessDialog(
      context,
      title: context.l10n.activityDeleted,
      message: context.l10n.theActivityHasBeenDeletedSuccessfully,
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
            child: NotificationListener<ScrollNotification>(
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
          PositionedDirectional(
            end: 16,
            // Above the raised + button.
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
    final chats = ChatController.instance;

    int countFor(ActivityFilterChoice f) => inTab
        .where((a) => f.role.matches(roles[a.id]!) && f.visibility.matches(a))
        .length;

    final choice = (role: _filter, visibility: _visibility);
    final filtered =
        _filter != ActivityRoleFilter.all ||
        _visibility != ActivityVisibility.all;
    final shown = inTab
        .where((a) => _filter.matches(roles[a.id]!) && _visibility.matches(a))
        .toList();

    bool isMember(Activity a) {
      final role = roles[a.id];
      return role == MyActivityRole.hosting || role == MyActivityRole.joined;
    }

    final header = <Widget>[
      // Same height and place as the Chats title.
      Container(
        height: 48,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          context.l10n.activities,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: SynkColors.textPrimary,
          ),
        ),
      ),
      if (_scheduleConflicts.isNotEmpty) ...[
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFFFFE8D8),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _openScheduleConflicts,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: SynkColors.orangeDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_scheduleConflicts.length} unresolved schedule conflict${_scheduleConflicts.length == 1 ? '' : 's'} · Tap to review',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      if (_store.pendingRequestCount > 0) ...[
        _JoinRequestsRow(
          count: _store.pendingRequestCount,
          onTap: _openJoinRequests,
        ),
        const SizedBox(height: 14),
      ],
      Row(
        children: [
          Expanded(
            child: _Segmented(
              showPast: _showPast,
              onChanged: (past) => setState(() {
                if (past) unawaited(_loadPendingRatings());
                _showPast = past;
                _filter = ActivityRoleFilter.all;
                _visibility = ActivityVisibility.all;
              }),
            ),
          ),
          const SizedBox(width: 10),
          _FilterButton(
            active: filtered,
            onTap: () async {
              final picked = await showActivitiesFilterSheet(
                context: context,
                initial: choice,
                countFor: countFor,
              );
              if (picked == null || !mounted) return;
              setState(() {
                _filter = picked.role;
                _visibility = picked.visibility;
              });
            },
          ),
        ],
      ),
      if (filtered) ...[
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _FilterSummary(
            label: [
              if (_filter != ActivityRoleFilter.all) _filter.label,
              if (_visibility != ActivityVisibility.all) _visibility.label,
            ].join(' · '),
            onClear: _clearFilters,
          ),
        ),
      ],
      const SizedBox(height: 16),
    ];

    // Room for the bottom bar, the + button and the code bubble.
    final bottomPadding = bottomInset + 140;

    final now = DateTime.now();
    final items = <Widget>[];
    String? lastGroup;
    for (final activity in shown) {
      final group = _groupLabel(activity.dateTime, now);
      if (group != lastGroup) {
        items.add(_GroupHeader(label: group, first: lastGroup == null));
        lastGroup = group;
      }
      final role = roles[activity.id]!;
      final chat = chats.activityChatFor(activity.id);
      final member = isMember(activity);
      final limited = role == MyActivityRole.pending && !activity.isPublic;
      // Ended, and the user was in it.
      final canRate = member && activity.endsAt.isBefore(now);
      items
        ..add(
          MyActivityCard(
            activity: activity,
            role: role,
            participants: _people[activity.id],
            anonymous: role == MyActivityRole.pending,
            // A private activity they only asked to join stays closed.
            limited: limited,
            onTap: limited ? null : () => _openActivity(activity),
            // Past activities keep their chat if it's still there.
            onChat: member && (!activity.isPast || chat != null)
                ? () => _openChat(activity)
                : null,
            unreadCount: chat?.unreadCount ?? 0,
            showCode: member && !activity.isPast,
            canShare: member && !activity.isPast,
            onRate: canRate ? () => _rate(activity) : null,
            hasRated: !_pendingRatings.containsKey(activity.id),
          ),
        )
        ..add(const SizedBox(height: 12));
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          sliver: SliverList(delegate: SliverChildListDelegate(header)),
        ),
        if (shown.isEmpty)
          // Centered in the space left under the header.
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Center(
                child: filtered
                    ? EmptyState(
                        icon: Icons.tune_rounded,
                        title: context.l10n.noMatchesTryFewerFilters,
                        actionLabel: context.l10n.clearFilters,
                        onAction: _clearFilters,
                      )
                    : _showPast
                    ? EmptyState(
                        icon: Icons.history_rounded,
                        title: context.l10n.noPastActivities,
                        message: context.l10n.activitiesYouveBeenPartOfWill,
                      )
                    : EmptyState(
                        icon: Icons.event_available_rounded,
                        title: context.l10n.noUpcomingActivities,
                        message: context.l10n.joinOneFromHomeOrTap,
                      ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
            sliver: SliverList(delegate: SliverChildListDelegate(items)),
          ),
      ],
    );
  }

  void _clearFilters() => setState(() {
    _filter = ActivityRoleFilter.all;
    _visibility = ActivityVisibility.all;
  });

  // Today, Tomorrow / Yesterday, This week, then the month.
  static String _groupLabel(DateTime date, DateTime now) {
    final days = DateUtils.dateOnly(date)
        .difference(DateUtils.dateOnly(now))
        .inDays;
    if (days == 0) return appL10n.today;
    if (days == 1) return appL10n.tomorrow;
    if (days == -1) return appL10n.yesterday;
    if (days.abs() < 7) return appL10n.thisWeek;
    final month = monthName(date.month);
    return date.year == now.year ? month : '$month ${date.year}';
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label, required this.first});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(4, first ? 0 : 8, 4, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: SynkColors.textSecondary,
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Tooltip(
          message: context.l10n.filter,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.tune_rounded, size: 22, color: SynkColors.ink),
                if (active)
                  PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: SynkColors.orangeDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsetsDirectional.only(start: 14),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SynkColors.orangeDeep,
            ),
          ),
          IconButton(
            tooltip: context.l10n.clearFilters,
            onPressed: onClear,
            constraints: const BoxConstraints.tightFor(width: 36, height: 34),
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: SynkColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.showPast, required this.onChanged});

  final bool showPast;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 220);

    Widget segment(String label, bool past) {
      final selected = showPast == past;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(past),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: duration,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : SynkColors.textSecondary,
              ),
              child: Text(label),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: const ShapeDecoration(
        color: Colors.white,
        shape: StadiumBorder(),
      ),
      child: Stack(
        children: [
          // The orange oval slides under the selected label.
          AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: showPast
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: const FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: SynkColors.orangeDark,
                  shape: StadiumBorder(),
                ),
              ),
            ),
          ),
          Row(
            children: [
              segment(context.l10n.upcoming, false),
              segment(context.l10n.past, true),
            ],
          ),
        ],
      ),
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
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
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
              Expanded(
                child: Text(
                  context.l10n.joinRequests,
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
                    color: SynkColors.orangeDark,
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
