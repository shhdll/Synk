import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activities_model.dart';
import '../../../models/activity_model.dart';
import '../../../models/activity_participation_model.dart';
import '../../../models/activity_swipes_model.dart';
import '../../../models/top_picks.dart';
import '../../../utils/custom_widgets/synk_feedback.dart';
import 'activity_thumbnail.dart';
import 'friends_going.dart';

// "For you": the user's top picks as a deck of cards. Swipe left for the
// next one, right to go back. Join can be undone for a few seconds, and the join is
// only saved once that time is up.
class ForYouDeck extends StatefulWidget {
  const ForYouDeck({
    super.key,
    required this.picks,
    required this.session,
    required this.activityStore,
    required this.onOpen,
    required this.onJoined,
    this.onCreate,
    this.swipes,
    this.participation,
    this.activitiesModel,
  });

  // Null while loading.
  final List<TopPick>? picks;

  // A new value deals a fresh deck, e.g. after pull to refresh.
  final int session;

  final ActivityStore activityStore;
  final ValueChanged<Activity> onOpen;

  // After a join is saved, so Home can reload the feed.
  final VoidCallback onJoined;

  // "Couldn't find your thing?" after the last card.
  final VoidCallback? onCreate;

  // Injectable for tests.
  final ActivitySwipesModel? swipes;
  final ActivityParticipationModel? participation;
  final ActivitiesModel? activitiesModel;

  static const double cardHeight = 280;

  @override
  State<ForYouDeck> createState() => _ForYouDeckState();
}

class _ForYouDeckState extends State<ForYouDeck>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _peek = 14;
  static const double _threshold = 0.35;
  static const double _flingSpeed = 900;
  static const double _maxTilt = 12 * math.pi / 180;

  late final ActivitySwipesModel _swipes =
      widget.swipes ?? ActivitySwipesModel();
  late final ActivityParticipationModel _participation =
      widget.participation ?? ActivityParticipationModel();
  late final ActivitiesModel _activitiesModel =
      widget.activitiesModel ?? ActivitiesModel();

  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addListener(() => setState(() => _offset = _tween?.value ?? _offset));
  Animation<Offset>? _tween;

  List<TopPick>? _deck;
  int _index = 0;
  Offset _offset = Offset.zero;
  Offset _dragStart = Offset.zero;
  double _width = 1;
  bool _crossed = false;
  bool _busy = false;

  // Built cards by activity id; see [_cardFor].
  final Map<String, Widget> _cards = {};

  // The nudge plays once per app run.
  static bool _nudged = false;

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _undoBar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ForYouDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session != oldWidget.session) {
      _undoBar?.close();
      _deck = null;
      _cards.clear();
      _index = 0;
      _offset = Offset.zero;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the app saves what's waiting on the Undo bar.
    if (state == AppLifecycleState.paused) _undoBar?.close();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _undoBar?.close();
    _motion.dispose();
    super.dispose();
  }

  TopPick? get _current {
    final deck = _deck;
    if (deck == null || _index >= deck.length) return null;
    return deck[_index];
  }

  void _animateTo(Offset target, {Curve curve = Curves.easeOutCubic}) {
    _tween = Tween(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _motion, curve: curve));
  }

  void _onDragStart(DragStartDetails details) {
    if (_busy) return;
    _motion.stop();
    _dragStart = details.globalPosition - _offset;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_busy) return;
    final offset = details.globalPosition - _dragStart;
    final crossed = offset.dx.abs() > _width * _threshold;
    if (crossed && !_crossed) HapticFeedback.lightImpact();
    _crossed = crossed;
    setState(() => _offset = offset);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_busy) return;
    final speed = details.primaryVelocity ?? 0;
    final dx = _offset.dx;
    _crossed = false;
    final right = dx.abs() > _width * _threshold
        ? dx > 0
        : speed.abs() > _flingSpeed
        ? speed > 0
        : null;
    if (right == false) {
      _next(right: false);
    } else if (right == true && _index > 0) {
      _previous();
    } else {
      _animateTo(Offset.zero, curve: Curves.easeOutBack);
      _motion.forward(from: 0);
    }
  }

  // Sends the front card off to the side and shows the next one.
  void _next({required bool right, bool join = false}) {
    final pick = _current;
    if (pick == null || _busy) return;
    _busy = true;
    if (join) HapticFeedback.lightImpact();
    _animateTo(Offset((right ? 1 : -1) * _width * 1.5, _offset.dy + 40));
    _motion.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _index++;
        _offset = Offset.zero;
        _busy = false;
      });
      if (join) _showUndo(pick);
    });
  }

  // The card before slides back in from the left, over this one.
  void _previous() {
    if (_busy || _index == 0) return;
    _motion.stop();
    setState(() {
      _index--;
      _offset = Offset(-_width * 1.5, 40);
    });
    _animateTo(Offset.zero);
    _motion.forward(from: 0);
  }

  // Back to the first card after the last one.
  void _seeAgain() {
    _motion.stop();
    setState(() {
      _index = 0;
      _offset = Offset(0, ForYouDeck.cardHeight / 3);
    });
    _animateTo(Offset.zero);
    _motion.forward(from: 0);
  }

  void _showUndo(TopPick pick) {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    // Closing the last bar saves what it was waiting on.
    messenger.hideCurrentSnackBar();
    final bar = messenger.showSnackBar(
      SnackBar(
        content: Text(l.youJoinedTitle(_title(pick.activity))),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: SynkColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: SnackBarAction(
          label: l.undo,
          textColor: SynkColors.orange,
          onPressed: () {},
        ),
      ),
    );
    _undoBar = bar;
    bar.closed.then((reason) {
      if (_undoBar == bar) _undoBar = null;
      if (reason == SnackBarClosedReason.action) {
        _bringBack();
      } else {
        _swipes.record(pick.activity.id, SwipeAction.join);
        _join(pick.activity);
      }
    });
  }

  // Undo: the card slides back in from the side it left.
  void _bringBack() {
    if (!mounted || _index == 0) return;
    _motion.stop();
    setState(() {
      _index--;
      _offset = Offset(_width * 1.5, 40);
    });
    _animateTo(Offset.zero);
    _motion.forward(from: 0);
  }

  Future<void> _join(Activity activity) async {
    const saved = {
      'joined',
      'already_joined',
      'waitlisted',
      'already_waitlisted',
      'pending',
      'already_pending',
    };
    try {
      final result = await _participation.joinPublicActivity(activity.id);
      if (!saved.contains(result.result)) {
        // Full, a time clash, or it started: the deck has moved on already.
        if (mounted) {
          SynkFeedback.showToast(
            context,
            title: context.l10n.unableToJoin,
            message: result.message,
            success: false,
          );
        }
        return;
      }
      if (result.result.contains('waitlisted') && mounted) {
        SynkFeedback.showToast(context, title: context.l10n.addedToWaitlist);
      }
      try {
        final participating = await _activitiesModel.fetchParticipating();
        widget.activityStore.setParticipating(participating);
      } catch (_) {
        // The join went through; the lists catch up on the next load.
      }
      widget.onJoined();
    } catch (_) {
      if (mounted) {
        SynkFeedback.showToast(
          context,
          title: context.l10n.unableToJoinTheActivityPlease,
          success: false,
        );
      }
    }
  }

  void _open(Activity activity) {
    _swipes.record(activity.id, SwipeAction.openDetails);
    widget.onOpen(activity);
  }

  static String _title(Activity activity) {
    final title = activity.title.trim();
    return title.isEmpty ? appL10n.untitledActivity : title;
  }

  @override
  Widget build(BuildContext context) {
    final picks = widget.picks;
    if (_deck == null && picks != null) _deck = List.of(picks);
    final deck = _deck;

    // Nothing to recommend at all: no section.
    if (deck != null && deck.isEmpty) return const SizedBox.shrink();

    final l = context.l10n;
    final done = deck != null && _index >= deck.length;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  l.forYou,
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: SynkColors.ink,
                  ),
                ),
              ),
              if (deck != null && !done)
                Text(
                  l.deckCounter(_index + 1, deck.length),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SynkColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (deck == null)
            const _DeckSkeleton()
          else
            // Eases down to the end card after the last one, and back up on
            // See again, so Explore slides instead of jumping.
            AnimatedSize(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              // Dragged and flying cards go past its edges.
              clipBehavior: Clip.none,
              child: done
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: _CaughtUp(
                          onSeeAgain: _seeAgain,
                          onCreate: widget.onCreate,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            _width = constraints.maxWidth;
                            return _buildDeck(deck);
                          },
                        ),
                        const SizedBox(height: 12),
                        _DeckProgress(count: deck.length, index: _index),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  // One card per activity, built once, so moving it (or a card moving up
  // the stack) doesn't rebuild it or reload its photo.
  Widget _cardFor(TopPick pick) => _cards.putIfAbsent(
    pick.activity.id,
    () => RepaintBoundary(
      child: _DeckCard(
        pick: pick,
        onJoin: () => _next(right: true, join: true),
      ),
    ),
  );

  // A small slide to the side and back, the first time the deck shows, so
  // it's clear the card moves.
  void _nudge() {
    if (_nudged || (_deck?.length ?? 0) < 2) return;
    _nudged = true;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted || _busy || _offset != Offset.zero) return;
      _animateTo(Offset(-_width * 0.14, 0));
      _motion.forward(from: 0).then((_) {
        if (!mounted || _busy) return;
        _animateTo(Offset.zero, curve: Curves.easeOutBack);
        _motion.forward(from: 0);
      });
    });
  }

  Widget _buildDeck(List<TopPick> deck) {
    // 0 at rest, 1 once the front card is past the threshold.
    final progress = (_offset.dx.abs() / (_width * _threshold)).clamp(0.0, 1.0);
    final angle = (_offset.dx / _width).clamp(-1.0, 1.0) * _maxTilt;

    // Back to front, each keyed by its activity, so a card keeps its state
    // as it moves up the stack.
    Widget layer(int depth) {
      final pick = deck[_index + depth];
      final front = depth == 0;
      // Where it sits: 0 in front, 1 and 2 behind, moving up as the front
      // card is dragged away.
      final place = front ? 0.0 : math.max(depth - progress, depth - 1.0);
      final tint = ActivityVisual.of(pick.activity).tint;
      // The light tint fades out as a card comes to the front.
      final cover = switch (depth) {
        0 => 0.0,
        1 => (1 - progress) * 0.85,
        _ => 0.85,
      };

      return Positioned(
        key: ValueKey(pick.activity.id),
        top: _peek * 2,
        left: 0,
        right: 0,
        height: ForYouDeck.cardHeight,
        child: IgnorePointer(
          ignoring: !front,
          child: Transform.translate(
            offset: front ? _offset : Offset(0, -_peek * place),
            child: Transform.rotate(
              angle: front ? angle : 0,
              child: Transform.scale(
                scale: 1 - 0.06 * place,
                alignment: Alignment.topCenter,
                child: Semantics(
                  customSemanticsActions: front
                      ? {
                          CustomSemanticsAction(
                            label: context.l10n.nextActivity,
                          ): () =>
                              _next(right: false),
                          if (_index > 0)
                            CustomSemanticsAction(
                              label: context.l10n.previousActivity,
                            ): _previous,
                        }
                      : null,
                  child: GestureDetector(
                    onTap: front ? () => _open(pick.activity) : null,
                    onHorizontalDragStart: front ? _onDragStart : null,
                    onHorizontalDragUpdate: front ? _onDragUpdate : null,
                    onHorizontalDragEnd: front ? _onDragEnd : null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _cardFor(pick),
                        if (cover > 0)
                          IgnorePointer(
                            child: Opacity(
                              opacity: cover,
                              child: _TintCard(tint: tint),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    _nudge();

    return SizedBox(
      height: ForYouDeck.cardHeight + _peek * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final depth in [2, 1, 0])
            if (_index + depth < deck.length) layer(depth),
        ],
      ),
    );
  }
}

String topPickReasonText(TopPickReason reason) => switch (reason) {
  FriendsGoing(:final friends) => friendsGoingText(friends),
  SharedInterest(:final interest) => appL10n.topPickYouLike(
    valueLabel(interest),
  ),
  PreferredSetting(setting: ActivitySetting.indoor) =>
    appL10n.topPickLikesIndoor,
  PreferredSetting(setting: ActivitySetting.outdoor) =>
    appL10n.topPickLikesOutdoor,
  PopularNearYou() => appL10n.topPickPopularNearYou,
};

// "Thu · 8:30 PM · 3.2 km"
String deckMeta(Activity activity, double? km) {
  final date = activity.dateTime;
  return [
    weekdayShort(date),
    formatTime(date.hour, date.minute),
    if (km != null) appL10n.topPickDistanceKm(km.toStringAsFixed(1)),
  ].join(' · ');
}

const _cardRadius = BorderRadius.all(Radius.circular(24));

final _cardShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.10),
    blurRadius: 20,
    offset: const Offset(0, 8),
  ),
];

class _TintCard extends StatelessWidget {
  const _TintCard({required this.tint});

  final Color tint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: 0.28), Colors.white),
        borderRadius: _cardRadius,
        boxShadow: _cardShadow,
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.pick, this.onJoin});

  final TopPick pick;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final activity = pick.activity;
    final l = context.l10n;
    final fallback = ActivityVisualTile(activity: activity, iconSize: 88);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _cardRadius,
        boxShadow: _cardShadow,
      ),
      child: ClipRRect(
        borderRadius: _cardRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (activity.hasPhoto)
              Image.network(
                activity.photoUrl!,
                fit: BoxFit.cover,
                cacheWidth:
                    (MediaQuery.sizeOf(context).width *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              )
            else
              fallback,
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xC7000000),
                  ],
                  stops: [0, 0.35, 1],
                ),
              ),
            ),
            PositionedDirectional(
              top: 12,
              start: 12,
              end: 12,
              // The reason gets all the room the spots pill leaves.
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _ReasonPill(reason: pick.reason),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SpotsPill(activity: activity),
                ],
              ),
            ),
            PositionedDirectional(
              start: 16,
              end: 12,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _ForYouDeckState._title(activity),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.nunito(
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          deckMeta(activity, pick.distanceKm),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onJoin != null) ...[
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: onJoin,
                      style: FilledButton.styleFrom(
                        backgroundColor: SynkColors.pink,
                        foregroundColor: SynkColors.ink,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        l.joinShort,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonPill extends StatelessWidget {
  const _ReasonPill({required this.reason});

  final TopPickReason reason;

  @override
  Widget build(BuildContext context) {
    final reason = this.reason;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        reason is FriendsGoing ? 4 : 10,
        5,
        12,
        5,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reason is FriendsGoing)
            FriendAvatarStack(
              friends: reason.friends.take(1).toList(),
              size: 20,
            )
          else
            const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: SynkColors.orangeDeep,
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              topPickReasonText(reason),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SynkColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// A people icon and how many spots are left: "2 left", or "Full".
class SpotsPill extends StatelessWidget {
  const SpotsPill({super.key, required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final left = activity.spotsOpen;

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_alt_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            left == 0 ? l.full : l.spotsLeftShort(left),
            maxLines: 1,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// One segment per card: seen in charcoal, the current one in the brand
// gradient, the rest light.
class _DeckProgress extends StatelessWidget {
  const _DeckProgress({required this.count, required this.index});

  final int count;
  final int index;

  static const _brand = LinearGradient(
    colors: [SynkColors.pink, SynkColors.orange, SynkColors.teal],
  );

  Widget _segments(bool Function(int i) lit) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(999)),
                color: lit(i) ? Colors.white : Colors.transparent,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0xFFE4DED2),
            BlendMode.srcIn,
          ),
          child: _segments((_) => true),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: rtl ? _brand.colors.reversed.toList() : _brand.colors,
          ).createShader(bounds),
          child: _segments((i) => i <= index),
        ),
      ],
    );
  }
}

// After the last card: a button to see them again, then a nudge to make
// your own.
class _CaughtUp extends StatelessWidget {
  const _CaughtUp({required this.onSeeAgain, this.onCreate});

  final VoidCallback onSeeAgain;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 1,
          shadowColor: Colors.black12,
          child: IconButton(
            tooltip: l.seeAgain,
            onPressed: onSeeAgain,
            style: IconButton.styleFrom(fixedSize: const Size(56, 56)),
            icon: const Icon(
              Icons.refresh_rounded,
              size: 26,
              color: SynkColors.ink,
            ),
          ),
        ),
        if (onCreate != null) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l.couldntFindYourThing,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.textSecondary,
                ),
              ),
              TextButton(
                onPressed: onCreate,
                style: TextButton.styleFrom(
                  foregroundColor: SynkColors.orangeDeep,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: Text(
                  l.createOne,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DeckSkeleton extends StatelessWidget {
  const _DeckSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ForYouDeck.cardHeight + _ForYouDeckState._peek * 2,
      child: Stack(
        children: [
          for (final depth in [2, 1, 0])
            Positioned(
              top: _ForYouDeckState._peek * (2 - depth),
              left: 0,
              right: 0,
              height: ForYouDeck.cardHeight,
              child: Transform.scale(
                scale: 1 - 0.05 * depth,
                alignment: Alignment.topCenter,
                child: const SkeletonBlock(radius: 24),
              ),
            ),
        ],
      ),
    );
  }
}

// A soft pulsing placeholder, same colors as the other skeletons.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({super.key, this.radius = 16});

  final double radius;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFFEFE8DB),
            Colors.white,
            _shimmer.value * 0.65,
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
