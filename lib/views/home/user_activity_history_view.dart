import 'package:flutter/material.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import 'widgets/activity_thumbnail.dart';
import 'widgets/empty_state.dart';

// A user's full history of ended activities, loaded a page at a time.
class UserActivityHistoryView extends StatefulWidget {
  const UserActivityHistoryView({
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
  State<UserActivityHistoryView> createState() =>
      _UserActivityHistoryViewState();
}

class _UserActivityHistoryViewState extends State<UserActivityHistoryView> {
  static const int _pageSize = 20;

  late final ActivitiesModel _model =
      widget.activitiesModel ?? ActivitiesModel();
  final ScrollController _scroll = ScrollController();

  final List<Activity> _activities = [];
  bool _hasMore = true;
  bool _isLoading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMoreNearEnd);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    if (!_failed && _scroll.position.extentAfter < 300) _loadNextPage();
  }

  // Fills the screen when a page is too short to scroll.
  void _fillIfShort() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _loadMoreNearEnd();
    });
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _failed = false;
    });

    try {
      final page = await _model.fetchUserRecentActivities(
        userId: widget.userId,
        limit: _pageSize,
        offset: _activities.length,
      );
      if (!mounted) return;
      setState(() {
        if (page.allowed) _activities.addAll(page.activities);
        _hasMore = page.allowed && page.hasMore;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    if (mounted && _hasMore && !_failed) _fillIfShort();
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
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SynkColors.textPrimary,
          ),
        ),
        title: Text(
          context.l10n.userActivitiesTitle(widget.userName),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
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
    if (_activities.isEmpty) {
      if (_failed) {
        return EmptyState(
          icon: Icons.wifi_off_rounded,
          title: context.l10n.couldNotLoadActivities,
          actionLabel: context.l10n.retry,
          onAction: _loadNextPage,
        );
      }
      if (_isLoading || _hasMore) {
        return const Center(
          child: CircularProgressIndicator(color: SynkColors.orangeDark),
        );
      }
      return EmptyState(
        icon: Icons.event_available_rounded,
        title: context.l10n.noCompletedActivitiesYet,
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: _activities.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _activities.length) return _buildFooter();
        return _HistoryRow(activity: _activities[index]);
      },
    );
  }

  // Spinner while the next page loads, or Retry after a failed page.
  Widget _buildFooter() {
    if (_failed) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadNextPage,
          style: TextButton.styleFrom(foregroundColor: SynkColors.orangeDark),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(context.l10n.retry),
        ),
      );
    }
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(color: SynkColors.orangeDark),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.activity});

  final Activity activity;

  // History can span years, so the date includes the year.
  static String _formatDateWithYear(BuildContext context, DateTime date) {
    return context.l10n.longDate(
      weekdayShort(date),
      monthShort(date.month),
      date.day,
      date.year,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ActivityThumbnail(activity: activity, size: 60),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: SynkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateWithYear(context, activity.dateTime),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: SynkColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
