import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/synk_colors.dart';
import '../../controllers/friends_controller.dart';
import '../../controllers/home_discovery_controller.dart';
import '../../controllers/notification_center_controller.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_filters.dart';
import '../../models/activity_model.dart';
import '../../models/activity_swipes_model.dart';
import '../../models/avatar_uploader.dart';
import '../../models/friends_model.dart';
import '../../models/recent_searches.dart';
import '../../models/top_picks.dart';
import '../../models/user_profile_model.dart';
import '../../utils/text_direction.dart';
import '../widgets/synk_blob_background.dart';
import 'activity_code_join_sheet.dart';
import 'profile_view.dart';
import 'widgets/activity_details_sheet.dart';
import 'widgets/code_bubble.dart';
import 'widgets/day_strip.dart';
import 'widgets/empty_state.dart';
import 'widgets/explore_grid.dart';
import 'widgets/filter_button.dart';
import 'widgets/filter_bottom_sheet.dart';
import 'widgets/for_you_deck.dart';
import 'widgets/friends_button.dart';
import 'widgets/home_search_view.dart';
import 'widgets/notification_bell.dart';
import 'widgets/streak_widgets.dart';
import 'widgets/synk_filter_chip.dart';

// Home: header, search, the For you deck and the Explore grid. While the
// search field is in use, search takes the place of the deck and the grid.
class HomeView extends StatefulWidget {
  const HomeView({
    super.key,
    required this.activityStore,
    required this.discoveryController,
    this.onCreateActivity,
    this.notifications,
    this.activitiesModel,
    this.profileModel,
    this.swipesModel,
  });

  final ActivityStore activityStore;

  final HomeDiscoveryController discoveryController;

  // Opens Create, with a starting title when given.
  final void Function([String? title])? onCreateActivity;

  // Drives the bell in the header; no bell when null.
  final NotificationCenterController? notifications;

  // Injectable for tests; default to the Supabase-backed models.
  final ActivitiesModel? activitiesModel;
  final UserProfileModel? profileModel;
  final ActivitySwipesModel? swipesModel;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final UserProfileModel _profileModel =
      widget.profileModel ?? UserProfileModel();
  late final ActivitiesModel _activitiesModel =
      widget.activitiesModel ?? ActivitiesModel();
  late final ActivitySwipesModel _swipes =
      widget.swipesModel ?? ActivitySwipesModel();
  final RecentSearches _recentSearches = const RecentSearches();
  HomeDiscoveryController get _discoveryController =>
      widget.discoveryController;
  FriendsController get _friends => FriendsController.instance;

  // The signed-in user's row, for the header and top picks.
  Map<String, dynamic> _profile = const {};
  bool _profileLoaded = false;

  // Learned from what the user hosted, joined, opened and skipped.
  Taste _taste = Taste.none;
  bool _tasteLoaded = false;

  // A new value deals a fresh For you deck.
  int _deckSession = 0;

  final FocusNode _searchFocus = FocusNode();
  bool _codeBubbleExpanded = true;
  bool _exploreOpen = true;
  Timer? _debounce;
  List<String> _recent = const [];

  // Tracks leave and host-transfer changes so the feed reloads once each.
  late int _seenParticipationVersion;
  bool _isSyncingParticipation = false;
  bool _participationSyncQueued = false;

  static const double _gutter = 16;

  @override
  void initState() {
    super.initState();
    _discoveryController.init();
    _loadProfile();
    _loadTaste();
    _loadRecent();
    _searchFocus.addListener(() {
      if (mounted) setState(() {});
    });

    _seenParticipationVersion = widget.activityStore.participationVersion;
    widget.activityStore.addListener(_onActivityStoreChanged);
  }

  @override
  void dispose() {
    widget.activityStore.removeListener(_onActivityStoreChanged);
    _debounce?.cancel();
    _searchFocus.dispose();
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

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileModel.fetchProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _profileLoaded = true;
        });
      }
    } catch (_) {
      // The default avatar stays until the next load; picks go without it.
      if (mounted) setState(() => _profileLoaded = true);
    }
  }

  Future<void> _loadTaste() async {
    final history = await _swipes.fetchHistory();
    if (mounted) {
      setState(() {
        _taste = Taste.fromHistory(history);
        _tasteLoaded = true;
      });
    }
  }

  Future<void> _loadRecent() async {
    final recent = await _recentSearches.load();
    if (mounted) setState(() => _recent = recent);
  }

  Future<void> _saveRecent(String query) async {
    final recent = await _recentSearches.add(query);
    if (mounted) setState(() => _recent = recent);
  }

  Future<void> _removeRecent(String query) async {
    final recent = await _recentSearches.remove(query);
    if (mounted) setState(() => _recent = recent);
  }

  // Pull to refresh: new feed and profile, then a fresh deck.
  Future<void> _refresh() async {
    await Future.wait([
      _discoveryController.loadFeed(isSilent: true),
      _loadProfile(),
      _loadTaste(),
    ]);
    if (mounted) setState(() => _deckSession++);
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileView(activityStore: widget.activityStore),
      ),
    );
    // Picks up a new photo chosen on the profile.
    await _loadProfile();
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

  // Minimise the code bubble as soon as the page scrolls down; show the
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

  bool get _searching =>
      _searchFocus.hasFocus || _discoveryController.searchQuery.isNotEmpty;

  void _onSearchChanged(String query) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _discoveryController.onSearchChanged(query),
    );
  }

  void _runSearch(String query) {
    final controller = _discoveryController.searchController;
    controller.text = query;
    controller.selection = TextSelection.collapsed(offset: query.length);
    _debounce?.cancel();
    _discoveryController.onSearchChanged(query);
    _saveRecent(query);
    setState(() {});
  }

  void _clearQuery() {
    _debounce?.cancel();
    _discoveryController.clearSearch();
  }

  void _cancelSearch() {
    _clearQuery();
    _searchFocus.unfocus();
    setState(() {});
  }

  double? _distanceOf(Activity activity) {
    final me = _discoveryController.userLocation;
    if (me == null || !activity.hasCoordinates) return null;
    return ActivityFilters.distanceKm(me, (
      latitude: activity.latitude!,
      longitude: activity.longitude!,
    ));
  }

  List<TopPick> _rank(List<Activity> activities, {int limit = 5}) {
    final store = widget.activityStore;
    return rankTopPicks(
      activities: activities,
      interests:
          (_profile['interests'] as List?)?.whereType<String>().toList() ??
          const [],
      preferredSetting: _profile['activity_type'] as String?,
      taste: _taste,
      friendsGoing: <String, List<FriendUser>>{
        for (final a in activities)
          if (_friends.friendsGoingIn(a.id).isNotEmpty)
            a.id: _friends.friendsGoingIn(a.id),
      },
      currentUserId: store.currentUserId,
      participatingIds: _participatingIds(activities),
      userLocation: _discoveryController.userLocation,
      limit: limit,
    );
  }

  // Activities the user already joined, asked to join or is waiting for.
  Set<String> _participatingIds(List<Activity> activities) => {
    for (final a in widget.activityStore.participating) a.id,
    for (final a in activities)
      if (a.participationStatus != null) a.id,
  };

  // Home leaves out the user's own activities.
  List<Activity> _notJoined(List<Activity> activities) {
    final ids = _participatingIds(activities);
    return [
      for (final a in activities)
        if (!ids.contains(a.id)) a,
    ];
  }

  Map<DateTime, int> _countsByDay() {
    final controller = _discoveryController;
    final matching = controller.filters
        .withDate(DateOption.any)
        .apply(
          _notJoined(controller.allActivities),
          userLocation: controller.userLocation,
          search: controller.searchQuery,
        );
    final counts = <DateTime, int>{};
    for (final a in matching) {
      final day = DateUtils.dateOnly(a.dateTime);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  // Null while loading; empty when there's nothing to show or it failed.
  List<TopPick>? _deckPicks() {
    final controller = _discoveryController;
    if (controller.errorMessage != null) return const [];
    if (controller.isLoading || !_profileLoaded || !_tasteLoaded) return null;
    return _rank(controller.allActivities);
  }

  // Search results, best matches for the user first.
  // Returns the results and the id of a top result that matches the user.
  (List<Activity>, String?) _searchResults() {
    final results = _notJoined(_discoveryController.filteredActivities);
    final scores = {
      for (final p in _rank(results, limit: results.length))
        p.activity.id: p.score,
    };
    final order = {for (final (i, a) in results.indexed) a.id: i};
    results.sort((a, b) {
      final byScore = (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0);
      return byScore != 0 ? byScore : order[a.id]!.compareTo(order[b.id]!);
    });
    final best = results.isNotEmpty && (scores[results.first.id] ?? 0) > 0
        ? results.first.id
        : null;
    return (results, best);
  }

  @override
  Widget build(BuildContext context) {
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
                onRefresh: _refresh,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    widget.activityStore,
                    _discoveryController,
                    _friends,
                  ]),
                  builder: (context, _) => _buildScrollView(),
                ),
              ),
            ),
          ),
          // "Have a code?", as on the Activities page; out of the way while
          // searching.
          if (!_searching)
            PositionedDirectional(
              end: _gutter,
              // Above the raised + button.
              bottom: MediaQuery.paddingOf(context).bottom + 44,
              child: CodeBubble(
                expanded: _codeBubbleExpanded,
                onTap: _openActivityCodeSheet,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScrollView() {
    final searching = _searching;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(_gutter, 20, _gutter, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 22),
                _buildSearchRow(searching),
                // Results sit right under the search bar.
                if (searching)
                  _buildSearch()
                else
                  ForYouDeck(
                    picks: _deckPicks(),
                    session: _deckSession,
                    activityStore: widget.activityStore,
                    onOpen: _onActivityTap,
                    onJoined: () =>
                        _discoveryController.loadFeed(isSilent: true),
                    onCreate: widget.onCreateActivity == null
                        ? null
                        : () => widget.onCreateActivity!(),
                    swipes: _swipes,
                  ),
              ],
            ),
          ),
        ),
        if (searching)
          const SliverToBoxAdapter(child: SizedBox(height: 120))
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_gutter, 24, _gutter, 0),
            sliver: SliverToBoxAdapter(
              child: ExploreHeader(
                open: _exploreOpen,
                onToggle: () => setState(() => _exploreOpen = !_exploreOpen),
              ),
            ),
          ),
          if (!_exploreOpen)
            const SliverToBoxAdapter(child: SizedBox(height: 120))
          else ...[
            if (_discoveryController.feedCategories.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildCategoryChipsBar(),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: DayStrip(
                  filters: _discoveryController.filters,
                  countsByDay: _countsByDay(),
                  onDayTap: _discoveryController.selectDay,
                  padding: const EdgeInsets.symmetric(horizontal: _gutter),
                ),
              ),
            ),
            ..._buildExplore(),
          ],
        ],
      ],
    );
  }

  Widget _buildHeader() {
    final gender = _profile['gender'] as String?;
    final image =
        AvatarUploader.imageFor(_profile) ??
        AvatarUploader.defaultImageForGender(gender);
    final fullName = (_profile['full_name'] as String?)?.trim() ?? '';
    final username = (_profile['username'] as String?)?.trim() ?? '';
    final name = fullName.isNotEmpty ? fullName.split(' ').first : username;

    return Row(
      children: [
        // The photo and name both open the profile.
        Expanded(
          child: Semantics(
            button: true,
            label: context.l10n.profile,
            child: GestureDetector(
              onTap: _openProfile,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image(
                        image: image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Image(
                          image: AvatarUploader.defaultImageForGender(gender),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  if (name.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        context.l10n.hiName(name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          // Spacing pulls joined Arabic letters apart.
                          letterSpacing: hasArabic(name) ? 0 : -0.3,
                          color: SynkColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StreakChip(activityStore: widget.activityStore),
                  ],
                ],
              ),
            ),
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

  Widget _buildSearchRow(bool searching) {
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
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              onSubmitted: _runSearch,
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
                        onPressed: _clearQuery,
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
                  borderRadius: BorderRadius.circular(24),
                  borderSide: border,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: SynkColors.orange),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (searching)
          TextButton(
            onPressed: _cancelSearch,
            style: TextButton.styleFrom(
              foregroundColor: SynkColors.ink,
              minimumSize: const Size(44, 48),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: Text(
              context.l10n.cancel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          )
        else
          FilterButton(
            count: _discoveryController.activeFilterCount,
            onTap: _openFilterSheet,
          ),
      ],
    );
  }

  Widget _buildSearch() {
    final query = _discoveryController.searchQuery;
    final (results, best) = _searchResults();
    final onCreate = widget.onCreateActivity;

    return HomeSearchView(
      query: query,
      results: results,
      bestMatchId: query.isEmpty ? null : best,
      distanceOf: _distanceOf,
      recent: _recent,
      onRecentTap: _runSearch,
      onRecentRemove: _removeRecent,
      onOpen: (activity) {
        if (query.isNotEmpty) _saveRecent(query);
        _onActivityTap(activity);
      },
      onCreate: onCreate == null ? null : (q) => onCreate(q),
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
      return context.l10n.noPlansMatchYourFilters;
    }
    // Either part can be empty, so tidy the spaces it leaves behind.
    return context.l10n
        .noCategoryPlans(category, when)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<Widget> _buildExplore() {
    const gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      mainAxisExtent: ExploreTile.height,
    );
    const padding = EdgeInsets.fromLTRB(_gutter, 14, _gutter, 0);
    // Room for the floating bottom bar.
    const bottomRoom = SliverToBoxAdapter(child: SizedBox(height: 120));

    if (_discoveryController.isLoading) {
      return [
        SliverPadding(
          padding: padding,
          sliver: SliverGrid.builder(
            gridDelegate: gridDelegate,
            itemCount: 6,
            itemBuilder: (_, _) => const ExploreTileSkeleton(),
          ),
        ),
        bottomRoom,
      ];
    }

    final activities = _notJoined(_discoveryController.filteredActivities);

    if (activities.isEmpty) {
      final failed = _discoveryController.errorMessage != null;
      final filtered = !failed && _discoveryController.hasActiveFilters;
      final onCreate = widget.onCreateActivity;

      return [
        SliverPadding(
          padding: EdgeInsets.only(top: filtered ? 60 : 28),
          sliver: SliverToBoxAdapter(
            child: filtered
                ? _NoMatches(
                    title: _noMatchesTitle(),
                    onCreate: onCreate == null ? null : () => onCreate(),
                    onClear: _discoveryController.clearAllFilters,
                  )
                : EmptyState(
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
        ),
        bottomRoom,
      ];
    }

    final onCreate = widget.onCreateActivity;
    return [
      SliverPadding(
        padding: padding,
        sliver: SliverGrid.builder(
          gridDelegate: gridDelegate,
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return ExploreTile(
              activity: activity,
              distanceKm: _distanceOf(activity),
              friends: _friends.friendsGoingIn(activity.id),
              onTap: () => _onActivityTap(activity),
            );
          },
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(_gutter, 18, _gutter, 0),
        sliver: SliverToBoxAdapter(
          child: _FeedFooter(
            onCreate: onCreate == null ? null : () => onCreate(),
          ),
        ),
      ),
      bottomRoom,
    ];
  }
}

// Under the last activity: a nudge to make your own.
class _FeedFooter extends StatelessWidget {
  const _FeedFooter({this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.leagueSpartan(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: SynkColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 36),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(context.l10n.couldntFindYourThing, style: style),
          if (onCreate != null)
            GestureDetector(
              onTap: onCreate,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.l10n.createOne,
                  style: style.copyWith(
                    color: SynkColors.orangeDark,
                    decoration: TextDecoration.underline,
                    decorationColor: SynkColors.orangeDark,
                  ),
                ),
              ),
            ),
        ],
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
                      backgroundColor: SynkColors.orange,
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
                    foregroundColor: SynkColors.textSecondary,
                    side: const BorderSide(
                      color: SynkColors.textSecondary,
                      width: 1.5,
                    ),
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
