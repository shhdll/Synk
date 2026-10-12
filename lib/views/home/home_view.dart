import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/constants/interest_emojis.dart';
import '../../core/constants/synk_colors.dart';
import '../../controllers/home_discovery_controller.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/user_profile_model.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../widgets/synk_blob_background.dart';
import 'activity_code_join_sheet.dart';
import 'widgets/activity_card_skeleton.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/code_bubble.dart';
import 'widgets/discovery_activity_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/filter_bottom_sheet.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.activityStore,
    this.isNewUser = false,
    this.activitiesModel,
    this.profileModel,
  });

  final ActivityStore activityStore;
  final bool isNewUser;

  // Injectable for tests; default to the Supabase-backed models.
  final ActivitiesModel? activitiesModel;
  final UserProfileModel? profileModel;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final UserProfileModel _profileModel =
      widget.profileModel ?? UserProfileModel();
  late final ActivitiesModel _activitiesModel =
      widget.activitiesModel ?? ActivitiesModel();
  late final HomeDiscoveryController _discoveryController;

  String _firstName = 'there';
  bool _codeBubbleExpanded = true;

  // Known categories, in onboarding order. Only those matching at least
  // one loaded activity get a chip.
  static final List<String> _presetCategories = kInterestEmojis.keys.toList();

  static const double _gutter = 16;

  @override
  void initState() {
    super.initState();
    _discoveryController = HomeDiscoveryController(
      activitiesModel: _activitiesModel,
      profileModel: _profileModel,
    );
    _discoveryController.init();
    _loadFirstName();
  }

  @override
  void dispose() {
    _discoveryController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstName() async {
    final profile = await _profileModel.fetchProfile();
    final fullName = (profile['full_name'] as String?)?.trim();

    if (mounted && (fullName?.isNotEmpty ?? false)) {
      setState(() {
        _firstName = fullName!.split(' ').first;
      });
    }
  }

  Future<void> _openActivityCodeSheet() async {
    final result = await showActivityCodeJoinSheet(context);

    // The user closed the sheet without completing a join.
    if (!mounted || result == null) return;

    try {
      // Refresh joined, pending, and waitlisted activities
      final participating = await _activitiesModel.fetchParticipating();

      if (!mounted) return;
      widget.activityStore.setParticipating(participating);

      // Also silently reload discovery feed to update participation markers
      _discoveryController.loadFeed(isSilent: true);
    } catch (_) {
      // The join succeeded in Supabase, so the confirmation
      // still appears if refreshing temporarily fails.
    }

    if (!mounted) return;

    final title = switch (result.result) {
      'joined' => 'Joined!',
      'already_joined' => 'Already Joined',
      'pending' => 'Request Sent!',
      'already_pending' => 'Request Already Sent',
      'waitlisted' => 'Added to Waitlist!',
      'already_waitlisted' => 'Already Waitlisted',
      _ => 'Done!',
    };

    await SynkFeedback.showSuccessDialog(
      context,
      title: title,
      message: result.message,
    );
  }

  void _openFilterSheet() {
    showHomeFilterBottomSheet(
      context: context,
      controller: _discoveryController,
    );
  }

  void _onActivityTap(Activity activity) {
    showActivityDetailsSheet(
      context: context,
      activity: activity,
      activityStore: widget.activityStore,
      // Refresh the feed so the card shows the new participant count.
      onParticipationChanged: () =>
          _discoveryController.loadFeed(isSilent: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Height of MainShell's bottom bar, which Home extends behind.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: SynkColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: SynkBlobBackground()),
          SafeArea(
            child: NotificationListener<UserScrollNotification>(
              onNotification: _onUserScroll,
              child: RefreshIndicator(
                color: SynkColors.orangeDark,
                backgroundColor: Colors.white,
                onRefresh: () => _discoveryController.loadFeed(isSilent: true),
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    widget.activityStore,
                    _discoveryController,
                  ]),
                  builder: (context, _) => _buildScrollView(),
                ),
              ),
            ),
          ),
          Positioned(
            right: _gutter,
            // Clears the raised + button, which sits ~30px above the bar.
            bottom: bottomInset + 44,
            child: CodeBubble(
              expanded: _codeBubbleExpanded,
              onTap: _openActivityCodeSheet,
            ),
          ),
        ],
      ),
    );
  }

  // Shrink the code bubble while reading down the feed; bring the label
  // back when the user scrolls up or returns to the top.
  bool _onUserScroll(UserScrollNotification notification) {
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

  Widget _buildScrollView() {
    final hasExtraFilters = _discoveryController.activeFilterCount > 0;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(_gutter, 20, _gutter, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 22),
                _buildSearchAndFilterRow(),
              ],
            ),
          ),
        ),
        if (_discoveryController.categoriesInFeed(_presetCategories).isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _buildCategoryChipsBar(),
            ),
          ),
        if (hasExtraFilters)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 0),
            sliver: SliverToBoxAdapter(child: _buildActiveFiltersRow()),
          ),
        _buildFeedContent(),
      ],
    );
  }

  Widget _buildHeader() {
    final hasName = _firstName != 'there';
    final greeting = widget.isNewUser
        ? (hasName ? 'Welcome, $_firstName' : 'Welcome to Synk')
        : (hasName ? 'Hey $_firstName' : 'Hey there');
    final headline = widget.isNewUser
        ? "Let's find your people"
        : 'Find your people';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.8,
                  color: SynkColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: SynkColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/synk_logo_transparent.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterRow() {
    final activeCount = _discoveryController.activeFilterCount;
    final hasFilters = activeCount > 0;
    final border = BorderSide(
      color: SynkColors.textSecondary.withValues(alpha: 0.14),
    );

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: TextField(
              controller: _discoveryController.searchController,
              onChanged: _discoveryController.onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: SynkColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search activities or locations...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: SynkColors.textSecondary.withValues(alpha: 0.8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: SynkColors.textSecondary,
                ),
                suffixIcon: _discoveryController.searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _discoveryController.clearSearch,
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: border,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: SynkColors.orange),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: hasFilters,
          label: Text('$activeCount'),
          backgroundColor: SynkColors.orangeDark,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: hasFilters
                  ? const BorderSide(color: SynkColors.orangeDark)
                  : border,
            ),
            child: InkWell(
              onTap: _openFilterSheet,
              customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: SizedBox.square(
                dimension: 48,
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: hasFilters
                      ? SynkColors.orangeDark
                      : SynkColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChipsBar() {
    final labels = _discoveryController.categoriesInFeed(_presetCategories);
    final selected = _discoveryController.selectedCategory;

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _gutter),
        physics: const BouncingScrollPhysics(),
        itemCount: labels.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildCategoryChip(
              label: 'All',
              isSelected: selected == null,
              onTap: () {
                if (selected != null) {
                  _discoveryController.setCategoryFilter(null);
                }
              },
            );
          }
          final label = labels[index - 1];
          return _buildCategoryChip(
            label: label,
            isSelected: selected == label,
            onTap: () => _discoveryController.setCategoryFilter(label),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? SynkColors.textPrimary
          : Colors.white.withValues(alpha: 0.7),
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected
              ? SynkColors.textPrimary
              : SynkColors.textSecondary.withValues(alpha: 0.22),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : SynkColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Time and location filters from the filter sheet. Search and category
  // already show in their own controls.
  Widget _buildActiveFiltersRow() {
    final chips = <Widget>[];

    final timeFilter = _discoveryController.selectedTimeFilter;
    if (timeFilter != TimeFilterOption.all) {
      var timeLabel = timeFilter.label;
      final custom = _discoveryController.customSelectedDate;
      if (timeFilter == TimeFilterOption.customDate && custom != null) {
        timeLabel = DiscoveryActivityCard.formatWhen(custom).split(' · ').first;
      }
      chips.add(
        _buildActiveFilterChip(
          label: timeLabel,
          onRemove: () =>
              _discoveryController.setTimeFilter(TimeFilterOption.all),
        ),
      );
    }

    final location = _discoveryController.selectedLocation;
    if (location != null) {
      chips.add(
        _buildActiveFilterChip(
          label: location,
          onRemove: () => _discoveryController.setLocationFilter(null),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...chips,
        TextButton(
          onPressed: _discoveryController.clearAllFilters,
          style: TextButton.styleFrom(
            foregroundColor: SynkColors.orangeDark,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Clear'),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close_rounded, size: 14),
      deleteIconColor: SynkColors.orangeDark,
      labelStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: SynkColors.orangeDark,
      ),
      backgroundColor: SynkColors.orange.withValues(alpha: 0.12),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 2),
    );
  }

  Widget _buildFeedContent() {
    // Bottom room so the code bubble never covers the last card.
    const padding = EdgeInsets.fromLTRB(_gutter, 22, _gutter, 120);

    if (_discoveryController.isLoading) {
      return SliverPadding(
        padding: padding,
        sliver: SliverList.separated(
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, _) => const ActivityCardSkeleton(),
        ),
      );
    }

    final activities = _discoveryController.filteredActivities;

    if (activities.isEmpty) {
      final failed = _discoveryController.errorMessage != null;
      final filtered = !failed && _discoveryController.hasActiveFilters;

      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: EmptyState(
            icon: failed
                ? Icons.cloud_off_rounded
                : filtered
                ? Icons.search_off_rounded
                : Icons.event_available_rounded,
            title: failed
                ? "We couldn't reach Synk"
                : filtered
                ? 'Nothing matches yet'
                : "It's quiet here for now",
            message: failed
                ? 'Check your connection and try again.'
                : filtered
                ? 'Try another search or clear your filters.'
                : 'New plans pop up all the time. Tap + to start one.',
            actionLabel: filtered ? 'Clear filters' : 'Refresh',
            onAction: filtered
                ? _discoveryController.clearAllFilters
                : () => _discoveryController.loadFeed(),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: padding,
      sliver: SliverList.separated(
        itemCount: activities.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return DiscoveryActivityCard(
            activity: activity,
            onTap: () => _onActivityTap(activity),
          );
        },
      ),
    );
  }
}
