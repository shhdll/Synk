import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/friends_controller.dart';
import '../../../controllers/home_discovery_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_model.dart';
import '../../../models/friends_model.dart';
import '../../../models/top_picks.dart';
import '../../../models/user_profile_model.dart';
import 'top_pick_card.dart';

// "Top 5 picks for you" on Home: a swipeable row of the feed's best matches
// for the user's friends, interests, indoor/outdoor preference and location.
// Hidden when there is nothing to show or anything fails, so Home looks as it
// did without it.
class TopPicksSection extends StatefulWidget {
  const TopPicksSection({
    super.key,
    required this.controller,
    required this.activityStore,
    required this.onActivityTap,
    this.profileModel,
    this.friends,
  });

  final HomeDiscoveryController controller;
  final ActivityStore activityStore;
  final ValueChanged<Activity> onActivityTap;

  // Injectable for tests; default to the app-wide instances.
  final UserProfileModel? profileModel;
  final FriendsController? friends;

  @override
  State<TopPicksSection> createState() => _TopPicksSectionState();
}

class _TopPicksSectionState extends State<TopPicksSection> {
  // Matches Home's page padding, so the first card lines up with it.
  static const double _gutter = 16;
  static const double _gap = 12;
  // Room under the cards for their shadow.
  static const double _shadowRoom = 12;

  late final UserProfileModel _profileModel =
      widget.profileModel ?? UserProfileModel();
  FriendsController get _friends => widget.friends ?? FriendsController.instance;

  // Null until the profile loads.
  List<String>? _interests;
  String? _preferredSetting;
  bool _profileFailed = false;

  // The feed the profile was last loaded for; a new feed (e.g. after pull to
  // refresh) reloads it, in case interests or preferences were edited.
  List<Activity>? _feedForProfile;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onFeedChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onFeedChanged);
    super.dispose();
  }

  void _onFeedChanged() {
    final feed = widget.controller.allActivities;
    if (widget.controller.isLoading || identical(feed, _feedForProfile)) {
      return;
    }
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _feedForProfile = widget.controller.allActivities;
    try {
      final profile = await _profileModel.fetchProfile();
      if (!mounted) return;
      setState(() {
        _interests =
            (profile['interests'] as List?)?.whereType<String>().toList() ??
            const [];
        _preferredSetting = profile['activity_type'] as String?;
        _profileFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _profileFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.controller,
        widget.activityStore,
        _friends,
      ]),
      builder: (context, _) {
        final controller = widget.controller;
        if (controller.errorMessage != null || _profileFailed) {
          return const SizedBox.shrink();
        }

        final loading = controller.isLoading || _interests == null;
        final picks = loading ? const <TopPick>[] : _rank();
        if (!loading && picks.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.topPicksTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.leagueSpartan(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              _buildCarousel(context, loading ? null : picks),
            ],
          ),
        );
      },
    );
  }

  List<TopPick> _rank() {
    final store = widget.activityStore;
    final activities = widget.controller.allActivities;
    return rankTopPicks(
      activities: activities,
      interests: _interests!,
      preferredSetting: _preferredSetting,
      friendsGoing: <String, List<FriendUser>>{
        for (final a in activities)
          if (_friends.friendsGoingIn(a.id).isNotEmpty)
            a.id: _friends.friendsGoingIn(a.id),
      },
      currentUserId: store.currentUserId,
      participatingIds: {
        for (final a in store.participating) a.id,
        for (final a in activities)
          if (a.participationStatus != null) a.id,
      },
      userLocation: widget.controller.userLocation,
    );
  }

  // Null [picks] shows the loading skeletons.
  Widget _buildCarousel(BuildContext context, List<TopPick>? picks) {
    final cardHeight = TopPickCard.heightFor(MediaQuery.textScalerOf(context));
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Home pads its content by the gutter; widen to the screen so the row
    // runs edge to edge.
    return SizedBox(
      height: cardHeight + _shadowRoom,
      child: OverflowBox(
        minWidth: screenWidth,
        maxWidth: screenWidth,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, _shadowRoom),
            physics: picks == null
                ? const NeverScrollableScrollPhysics()
                : const _SnapToCardPhysics(
                    itemExtent: TopPickCard.width + _gap,
                    parent: BouncingScrollPhysics(),
                  ),
            itemCount: picks?.length ?? 3,
            separatorBuilder: (_, _) => const SizedBox(width: _gap),
            itemBuilder: (context, index) {
              if (picks == null) return const TopPickCardSkeleton();
              final pick = picks[index];
              return TopPickCard(
                pick: pick,
                onTap: () => widget.onActivityTap(pick.activity),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Settles on the nearest card start after a fling or drag, so a card always
// lines up with the page padding.
class _SnapToCardPhysics extends ScrollPhysics {
  const _SnapToCardPhysics({required this.itemExtent, super.parent});

  final double itemExtent;

  @override
  _SnapToCardPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapToCardPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Past either end: let the parent bounce back.
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    var card = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      card -= 0.5;
    } else if (velocity > tolerance.velocity) {
      card += 0.5;
    }
    final target = (card.roundToDouble() * itemExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tolerance.distance) return null;

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
