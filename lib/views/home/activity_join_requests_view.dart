import 'package:flutter/material.dart';

import '../../controllers/activity_join_requests_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/activities_model.dart';
import '../../models/activity_filters.dart';
import '../../models/activity_model.dart';
import '../../models/activity_participation_model.dart';
import '../../models/avatar_uploader.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/activity_thumbnail.dart';
import 'widgets/user_profile_sheet.dart';

class ActivityJoinRequestsView extends StatefulWidget {
  const ActivityJoinRequestsView({super.key, required this.activityStore});

  // Opens activity details, and keeps the Join Requests badge in sync.
  final ActivityStore activityStore;

  @override
  State<ActivityJoinRequestsView> createState() {
    return _ActivityJoinRequestsViewState();
  }
}

class _ActivityJoinRequestsViewState extends State<ActivityJoinRequestsView> {
  late final ActivityJoinRequestsController _controller;

  @override
  void initState() {
    super.initState();

    _controller = ActivityJoinRequestsController();
    _controller.addListener(_refresh);
    _controller.loadRequests();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    // The list is the source of truth once loaded; the badge follows it.
    if (!_controller.isLoading && _controller.errorMessage == null) {
      widget.activityStore.pendingRequestCount = _controller.requests.length;
    }
  }

  void _openRequester(PendingActivityRequest request) {
    showUserProfileSheet(
      context: context,
      userId: request.requesterId,
      name: request.requesterName,
      username: request.requesterUsername,
      avatarUrl: request.requesterAvatarUrl,
      gender: request.requesterGender,
    );
  }

  // The host's own activity is usually already loaded; otherwise fetch it.
  Future<void> _openActivity(PendingActivityRequest request) async {
    var activity = _storeActivity(request.activityId);
    try {
      activity ??= await ActivitiesModel().fetchById(request.activityId);
    } catch (_) {}
    if (!mounted) return;

    if (activity == null) {
      SynkFeedback.showError(context, 'Unable to open this activity.');
      return;
    }
    await showActivityDetailsSheet(
      context: context,
      activity: activity,
      activityStore: widget.activityStore,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  // "Just now", "5m ago", "3h ago", "2d ago", then the date.
  String _formatRequestedAt(DateTime dateTime) {
    final localDate = dateTime.toLocal();
    final ago = DateTime.now().difference(localDate);

    if (ago.inMinutes < 1) return 'Just now';
    if (ago.inHours < 1) return '${ago.inMinutes}m ago';
    if (ago.inDays < 1) return '${ago.inHours}h ago';
    if (ago.inDays < 7) return '${ago.inDays}d ago';
    return formatShortDate(localDate);
  }

  Activity? _storeActivity(String activityId) {
    for (final a in widget.activityStore.mine) {
      if (a.id == activityId) return a;
    }
    return null;
  }

  // Requests bucketed by activity, soonest activity first (unknown dates
  // last), each bucket oldest request first.
  List<List<PendingActivityRequest>> _groupedRequests() {
    final groups = <String, List<PendingActivityRequest>>{};
    for (final request in _controller.requests) {
      groups.putIfAbsent(request.activityId, () => []).add(request);
    }
    for (final group in groups.values) {
      group.sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
    }
    DateTime? startOf(List<PendingActivityRequest> g) =>
        _storeActivity(g.first.activityId)?.dateTime;

    return groups.values.toList()..sort((a, b) {
      final da = startOf(a);
      final db = startOf(b);
      if (da != null && db != null) return da.compareTo(db);
      if (da == null && db == null) return 0;
      return da == null ? 1 : -1;
    });
  }

  // Reviews the request and shows feedback using the shared Synk style.
  Future<void> _reviewRequest({
    required PendingActivityRequest request,
    required bool accept,
  }) async {
    await _controller.reviewRequest(request: request, accept: accept);

    if (!mounted) return;

    final successMessage = _controller.successMessage;
    final errorMessage = _controller.errorMessage;

    if (successMessage != null) {
      await SynkFeedback.showSuccessDialog(
        context,
        title: accept ? 'Request Approved!' : 'Request Rejected',
        message: successMessage,
      );

      _controller.clearMessage();
      return;
    }

    SynkFeedback.showError(
      context,
      errorMessage ?? 'Unable to review the request. Please try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynkColors.background,
      appBar: AppBar(
        backgroundColor: SynkColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SynkColors.textPrimary,
          ),
        ),
        title: const Text(
          'Join Requests',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_controller.isLoading && _controller.requests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: SynkColors.orangeDark),
      );
    }

    if (_controller.errorMessage != null && _controller.requests.isEmpty) {
      return _buildErrorState();
    }

    if (_controller.requests.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: SynkColors.orangeDark,
      onRefresh: _controller.loadRequests,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          for (final group in _groupedRequests())
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildActivityGroup(group),
            ),
        ],
      ),
    );
  }

  // One card per activity: the activity on top (tap for details), then
  // everyone waiting to join it.
  Widget _buildActivityGroup(List<PendingActivityRequest> requests) {
    final first = requests.first;
    final activity = _storeActivity(first.activityId);
    final count = requests.length;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warm tinted band sets the activity apart from the people.
            Ink(
              color: SynkColors.orangeDark.withValues(alpha: 0.12),
              child: InkWell(
                onTap: () => _openActivity(first),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                  child: Row(
                    children: [
                      if (activity != null)
                        ActivityThumbnail(
                          activity: activity,
                          size: 48,
                          radius: 12,
                        )
                      else
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.event_rounded,
                            color: SynkColors.orangeDark,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              first.activityTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: SynkColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (activity != null)
                                  '${formatShortDate(activity.dateTime)} · '
                                      '${formatMinute(activity.dateTime.hour * 60 + activity.dateTime.minute)}',
                                '$count ${count == 1 ? 'request' : 'requests'}',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
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
            for (final (i, request) in requests.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 14,
                  endIndent: 14,
                  color: SynkColors.textSecondary.withValues(alpha: 0.10),
                ),
              _buildRequestRow(request),
            ],
          ],
        ),
      ),
    );
  }

  // The requester (tap for their profile) with reject / accept buttons.
  Widget _buildRequestRow(PendingActivityRequest request) {
    final isReviewing = _controller.isReviewing(request.participationId);
    final username = request.requesterUsername;
    final avatarUrl = request.requesterAvatarUrl?.trim();
    final fallbackAvatar = AvatarUploader.defaultImageForGender(
      request.requesterGender,
    );
    final subtitle = [
      if (username != null && username.isNotEmpty) '@$username',
      _formatRequestedAt(request.requestedAt),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _openRequester(request),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    ClipOval(
                      child: Image(
                        image: avatarUrl != null && avatarUrl.startsWith('http')
                            ? NetworkImage(avatarUrl)
                            : fallbackAvatar,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Image(
                          image: fallbackAvatar,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.requesterName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: SynkColors.textPrimary,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: SynkColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (isReviewing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 30),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.3,
                  color: SynkColors.orangeDark,
                ),
              ),
            )
          else ...[
            IconButton.filled(
              tooltip: 'Reject',
              onPressed: () => _reviewRequest(request: request, accept: false),
              style: IconButton.styleFrom(
                backgroundColor: SynkColors.badge,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: 'Accept',
              onPressed: () => _reviewRequest(request: request, accept: true),
              style: IconButton.styleFrom(
                backgroundColor: SynkColors.teal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 54,
              color: SynkColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              _controller.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SynkColors.textSecondary),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _controller.loadRequests,
              style: FilledButton.styleFrom(
                backgroundColor: SynkColors.orangeDark,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: SynkColors.orangeDark,
      onRefresh: _controller.loadRequests,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 150),
          Icon(
            Icons.mark_email_read_outlined,
            size: 62,
            color: SynkColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            'No pending requests',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: SynkColors.textPrimary,
            ),
          ),
          SizedBox(height: 7),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Requests for your private activities will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: SynkColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
