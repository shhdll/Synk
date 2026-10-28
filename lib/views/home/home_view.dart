import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/synk_colors.dart';
import '../../controllers/home_discovery_controller.dart';
import '../../controllers/notification_center_controller.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_filters.dart';
import '../../models/activity_model.dart';
import '../../models/user_profile_model.dart';
import '../widgets/synk_blob_background.dart';
import 'activity_code_join_sheet.dart';
import 'widgets/activity_card_skeleton.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/code_bubble.dart';
import 'widgets/day_strip.dart';
import 'widgets/discovery_activity_card.dart';
import 'widgets/empty_state.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'widgets/filter_button.dart';
import 'widgets/friends_button.dart';
import 'widgets/notification_bell.dart';
import 'widgets/synk_filter_chip.dart';

class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.activityStore,
    required this.discoveryController,
    this.isNewUser = false,
    this.onCreateActivity,
    this.notifications,
    this.activitiesModel,
    this.profileModel,
  });

  final ActivityStore activityStore;
  final bool isNewUser;

  final HomeDiscoveryController discoveryController;

  final VoidCallback? onCreateActivity;

  // Drives the bell in the header; no bell when null.
  final NotificationCenterController? notifications;

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
  HomeDiscoveryController get _discoveryController =>
      widget.discoveryController;

  String _firstName = 'there';
  // Arabic uses a feminine form of some phrases.
  bool _isFemale = false;
  bool _codeBubbleExpanded = true;

  // Tracks leave and host-transfer changes so the feed reloads once each.
  late int _seenParticipationVersion;
  bool _isSyncingParticipation = false;
  bool _participationSyncQueued = false;

  static const double _gutter = 16;

  @override
  void initState() {
    super.initState();
    _discoveryController.init();
    _loadFirstName();

    _seenParticipationVersion = widget.activityStore.participationVersion;
    widget.activityStore.addListener(_onActivityStoreChanged);
  }

  @override
  void dispose() {
    widget.activityStore.removeListener(_onActivityStoreChanged);
    super.dispose();
  }

  void _onActivityStoreChanged() {
    final version = widget.activityStore.participationVersion;
    if (version == _seenParticipationVersion) return;

    _seenParticipationVersion = version;
    _syncAfterParticipationChange();
  }

  // Reloads the feed Home and Map share; at most one request at a time.
  Future<void> _syncAfterParticipationChange() async {
    if (_isSyncingParticipation) {
      _participationSyncQueued = true;
      return;
    }

    _isSyncingParticipation = true;
    try {
      do {
        _participationSyncQueued = false;
        if (!mounted) return;
        await _discoveryController.loadFeed(isSilent: true);
      } while (_participationSyncQueued);
    } finally {
      _isSyncingParticipation = false;
    }
  }

  Future<void> _loadFirstName() async {
    final profile = await _profileModel.fetchProfile();
    final fullName = (profile['full_name'] as String?)?.trim();
    final gender = (profile['gender'] as String?)?.trim().toLowerCase();

    if (!mounted) return;
    setState(() {
      if (fullName?.isNotEmpty ?? false) {
        _firstName = fullName!.split(' ').first;
      }
      _isFemale = gender == 'female';
    });
  }

  Future<void> _openActivityCodeSheet() {
    return joinActivityWithCode(
      context,
      activityStore: widget.activityStore,
      activitiesModel: _activitiesModel,
      // Also silently reload discovery feed to update participation markers
      onJoined: () => _discoveryController.loadFeed(isSilent: true),
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
            child: NotificationListener<ScrollNotification>(
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
          PositionedDirectional(
            end: _gutter,
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

  Widget _buildScrollView() {
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
        if (_discoveryController.feedCategories.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _buildCategoryChipsBar(),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: DayStrip(
              filters: _discoveryController.filters,
              countsByDay: _discoveryController.activityCountsByDay,
              onDayTap: _discoveryController.selectDay,
              padding: const EdgeInsets.symmetric(horizontal: _gutter),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(_gutter, 18, _gutter, 0),
          sliver: SliverToBoxAdapter(child: _buildListTitle()),
        ),
        _buildFeedContent(),
      ],
    );
  }

  Widget _buildHeader() {
    final hasName = _firstName != 'there';
    final greeting = widget.isNewUser
        ? (hasName
              ? context.l10n.welcomeName(_firstName)
              : context.l10n.welcomeToSynk)
        : (hasName ? context.l10n.heyName(_firstName) : context.l10n.heyThere);
    final headline = widget.isNewUser
        ? context.l10n.letsFindYourPeople
        : _isFemale
        ? context.l10n.readyForSomethingNewFemale
        : context.l10n.readyForSomethingNew;

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
        const FriendsButton(),
        if (widget.notifications != null) ...[
          const SizedBox(width: 10),
          NotificationBell(
            controller: widget.notifications!,
            activityStore: widget.activityStore,
          ),
        ],
      ],
    );
  }

  Widget _buildSearchAndFilterRow() {
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
                hintText: context.l10n.searchActivitiesOrLocations,
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
                        tooltip: context.l10n.clearSearch,
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
        const SizedBox(width: 10),
        FilterButton(
          count: _discoveryController.activeFilterCount,
          onTap: _openFilterSheet,
        ),
      ],
    );
  }

  Widget _buildCategoryChipsBar() {
    final labels = _discoveryController.feedCategories;
    final selected = _discoveryController.filters.categories;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _gutter),
        physics: const BouncingScrollPhysics(),
        itemCount: labels.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return SynkFilterChip(
              label: context.l10n.all,
              selected: selected.isEmpty,
              onTap: () {
                if (selected.isNotEmpty) _discoveryController.clearCategories();
              },
            );
          }
          final label = labels[index - 1];
          return SynkFilterChip.category(
            category: label,
            selected: selected.contains(label),
            onTap: () => _discoveryController.toggleCategory(label),
          );
        },
      ),
    );
  }

  Widget _buildListTitle() {
    final filters = _discoveryController.filters;
    final parts = [
      ?_categorySummary(filters.categories),
      ?filters.dateLabel,
      ?filters.timeLabel,
    ];

    return Row(
      children: [
        Expanded(
          child: Text(
            parts.isEmpty ? context.l10n.upcomingPlans : parts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.leagueSpartan(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: SynkColors.ink,
            ),
          ),
        ),
        if (!filters.isDefault)
          TextButton(
            onPressed: _discoveryController.clearAllFilters,
            style: TextButton.styleFrom(
              foregroundColor: SynkColors.tealText,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              context.l10n.clearFilters,
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SynkColors.tealText,
              ),
            ),
          ),
      ],
    );
  }

  static String? _categorySummary(Set<String> categories) {
    final names = categories.toList();
    return switch (names.length) {
      0 => null,
      1 => names.first,
      2 => '${names.first} & ${names.last}',
      _ => '${names.first} +${names.length - 1}',
    };
  }

  String _noMatchesTitle() {
    final filters = _discoveryController.filters;
    final category = filters.categories.length == 1
        ? valueLabel(filters.categories.first)
        : '';
    final when = switch (filters.date) {
      DateOption.any => '',
      DateOption.custom => context.l10n.onDate(filters.dateLabel ?? ''),
      _ => filters.dateLabel!.toLowerCase(),
    };
    if (category.isEmpty && when.isEmpty) {
      return filters.isDefault
          ? context.l10n.noPlansMatchQuery(_discoveryController.searchQuery)
          : context.l10n.noPlansMatchYourFilters;
    }
    // Either part can be empty, so tidy the spaces it leaves behind.
    return context.l10n
        .noCategoryPlans(category, when)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

      if (filtered) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 120),
            child: _NoMatches(
              title: _noMatchesTitle(),
              onCreate: widget.onCreateActivity,
              onClear: _discoveryController.clearAllFilters,
            ),
          ),
        );
      }

      return SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: EmptyState(
            icon: failed
                ? Icons.cloud_off_rounded
                : Icons.event_available_rounded,
            title: failed
                ? context.l10n.weCouldntReachSynk
                : context.l10n.itsQuietHereForNow,
            message: failed
                ? context.l10n.checkYourConnectionAndTryAgain
                : context.l10n.newPlansPopUpAllThe,
            actionLabel: context.l10n.refresh,
            onAction: () => _discoveryController.loadFeed(),
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

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.title, required this.onClear, this.onCreate});

  final String title;
  final VoidCallback onClear;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
    );
    final labelStyle = GoogleFonts.roboto(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: SynkColors.orange.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                size: 44,
                color: SynkColors.orangeDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.leagueSpartan(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: SynkColors.ink,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                if (onCreate != null)
                  FilledButton(
                    onPressed: onCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: SynkColors.ink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: shape,
                      textStyle: labelStyle,
                    ),
                    child: Text(context.l10n.createOne),
                  ),
                OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SynkColors.ink,
                    side: const BorderSide(color: SynkColors.ink, width: 1.5),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: shape,
                    textStyle: labelStyle,
                  ),
                  child: Text(context.l10n.clearFilters),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
