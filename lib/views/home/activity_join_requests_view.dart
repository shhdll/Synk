import 'package:flutter/material.dart';

import '../../controllers/activity_join_requests_controller.dart';
import '../../core/constants/synk_colors.dart';
import '../../models/activity_participation_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';

class ActivityJoinRequestsView extends StatefulWidget {
  const ActivityJoinRequestsView({super.key});

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
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  String _formatRequestedAt(DateTime dateTime) {
    final localDate = dateTime.toLocal();

    final hour = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;

    final minute = localDate.minute.toString().padLeft(2, '0');

    final period = localDate.hour >= 12 ? 'PM' : 'AM';

    return '${localDate.day}/${localDate.month}/${localDate.year}'
        ' · $hour:$minute $period';
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
          const Text(
            'Private activity requests',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: SynkColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Review users who want to join your private activities.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: SynkColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ..._controller.requests.map((request) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildRequestCard(request),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRequestCard(PendingActivityRequest request) {
    final isReviewing = _controller.isReviewing(request.participationId);

    final username = request.requesterUsername;
    final trimmedName = request.requesterName.trim();

    final firstLetter = trimmedName.isEmpty
        ? '?'
        : trimmedName.characters.first.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: SynkColors.orangeDark.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SynkColors.orangeDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requesterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    if (username != null && username.isNotEmpty)
                      Text(
                        '@$username',
                        style: const TextStyle(
                          fontSize: 13,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.lock_outline_rounded,
                size: 20,
                color: SynkColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(
                Icons.event_rounded,
                size: 18,
                color: SynkColors.orangeDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.activityTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 17,
                color: SynkColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                _formatRequestedAt(request.requestedAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: SynkColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isReviewing
                      ? null
                      : () {
                          _reviewRequest(request: request, accept: false);
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(
                      color: Colors.redAccent.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: isReviewing
                      ? null
                      : () {
                          _reviewRequest(request: request, accept: true);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: SynkColors.orangeDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: isReviewing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Accept',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
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
