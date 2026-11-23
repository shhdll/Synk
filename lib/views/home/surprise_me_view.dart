import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/synk_colors.dart';
import '../../l10n/l10n.dart';
import '../../models/activities_model.dart';
import '../../models/activity_model.dart';
import '../../models/activity_participation_model.dart';
import '../../models/surprise_me.dart';
import '../../models/top_picks.dart';
import '../../utils/custom_widgets/synk_feedback.dart';
import '../widgets/synk_blob_background.dart';
import 'widgets/synk_filter_chip.dart';
import 'widgets/activity_thumbnail.dart';
import 'widgets/surprise_puzzle.dart';

// Surprise Me: shuffle the puzzle and get a random activity to join.
//
// [ranked] gives every activity the user could join, scored for them
// (rankTopPicks with no limit). It's read when needed, so activities that
// finish loading after the page opens still count. The filter starts empty
// every time.
class SurpriseMeView extends StatefulWidget {
  const SurpriseMeView({
    super.key,
    required this.ranked,
    required this.activityStore,
    required this.onOpen,
    required this.onJoined,
    this.distanceOf,
    this.participationModel,
    this.activitiesModel,
    this.feedChanges,
  });

  // Notifies when the feed behind [ranked] changes, so pieces that opened
  // before it finished loading fill in.
  final Listenable? feedChanges;

  final List<TopPick> Function() ranked;
  final ActivityStore activityStore;
  final void Function(Activity activity) onOpen;
  final VoidCallback onJoined;
  final double? Function(Activity activity)? distanceOf;

  // Injectable for tests.
  final ActivityParticipationModel? participationModel;
  final ActivitiesModel? activitiesModel;

  @override
  State<SurpriseMeView> createState() => _SurpriseMeViewState();
}

enum _Stage { ready, shuffling, revealed, nothing }

class _SurpriseMeViewState extends State<SurpriseMeView> {
  late final ActivityParticipationModel _participation =
      widget.participationModel ?? ActivityParticipationModel();
  late final ActivitiesModel _activitiesModel =
      widget.activitiesModel ?? ActivitiesModel();

  SurpriseFilter _filter = SurpriseFilter.none;
  _Stage _stage = _Stage.ready;
  int _playToken = 0;
  Activity? _picked;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    widget.feedChanges?.addListener(_onFeedChanged);
  }

  @override
  void dispose() {
    widget.feedChanges?.removeListener(_onFeedChanged);
    super.dispose();
  }

  // Only fills the waiting pieces; never changes them mid-shuffle.
  void _onFeedChanged() {
    if (mounted && _stage == _Stage.ready && _loose.length < 9) {
      setState(() => _loose = _looseActivities());
    }
  }

  // The activities on the loose pieces, before the puzzle comes together.
  List<Activity> _loose = const [];

  // Up to nine activities the user could join, in a random order.
  List<Activity> _looseActivities() {
    final all = [for (final pick in widget.ranked()) pick.activity]..shuffle();
    return all.take(9).toList();
  }

  bool _clashes(Activity activity) =>
      widget.activityStore.conflictingActivity(
        activity.dateTime,
        activity.endsAt,
        excludeId: activity.id,
      ) !=
      null;

  void _shuffle() {
    final picked = pickSurprise(
      ranked: widget.ranked(),
      filter: _filter,
      clashes: _clashes,
      avoidId: _picked?.id,
    );
    setState(() {
      if (picked == null) {
        _picked = null;
        _stage = _Stage.nothing;
        return;
      }
      // "Shuffle again" starts from a fresh set of loose pieces.
      if (_stage == _Stage.revealed || _loose.isEmpty) {
        _loose = _looseActivities();
      }
      _picked = picked;
      _stage = _Stage.shuffling;
      _playToken++;
    });
  }

  void _onPuzzleDone() {
    if (mounted && _stage == _Stage.shuffling) {
      setState(() => _stage = _Stage.revealed);
    }
  }

  Future<void> _join(Activity activity) async {
    if (_joining) return;
    setState(() => _joining = true);
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
      if (!mounted) return;
      if (!saved.contains(result.result)) {
        SynkFeedback.showToast(
          context,
          title: context.l10n.unableToJoin,
          message: result.message,
          success: false,
        );
        return;
      }
      try {
        widget.activityStore.setParticipating(
          await _activitiesModel.fetchParticipating(),
        );
      } catch (_) {
        // The join went through; the lists catch up on the next load.
      }
      widget.onJoined();
      if (!mounted) return;
      await SynkFeedback.showSuccessDialog(
        context,
        title: result.result.contains('waitlisted')
            ? context.l10n.addedToWaitlist
            : context.l10n.joinedTitle,
        message: result.message,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        SynkFeedback.showToast(
          context,
          title: context.l10n.unableToJoinTheActivityPlease,
          success: false,
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _openFilter() async {
    final chosen = await showModalBottomSheet<SurpriseFilter>(
      context: context,
      backgroundColor: SynkColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SurpriseFilterSheet(initial: _filter),
    );
    if (chosen != null && mounted) {
      setState(() {
        _filter = chosen;
        if (_stage == _Stage.nothing) _stage = _Stage.ready;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final puzzleSize = (width - 40).clamp(220.0, 360.0);
    if (_loose.isEmpty) _loose = _looseActivities();

    // The same page frame as the rest of the app: blob background, a
    // transparent bar with back and the title, and actions at the bottom.
    return SynkBlobPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: SynkColors.textPrimary,
            ),
          ),
          title: Text(
            l.surpriseMeTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: SynkColors.textPrimary,
            ),
          ),
          actions: [
            // The filter can't change mid-shuffle.
            IconButton(
              tooltip: l.filters,
              onPressed: _stage == _Stage.shuffling ? null : _openFilter,
              icon: Badge(
                isLabelVisible: _filter.isActive,
                smallSize: 8,
                backgroundColor: SynkColors.orangeDark,
                child: const Icon(
                  Icons.tune_rounded,
                  color: SynkColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                // Centred in the space, and scrolls if it doesn't fit.
                child: LayoutBuilder(
                  builder: (context, space) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, space.maxHeight - 20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l.surpriseMeSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: SynkColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 450),
                            switchInCurve: Curves.easeOutBack,
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(
                                  scale: animation,
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                ),
                            child: switch (_stage) {
                              _Stage.revealed => _SurpriseCard(
                                key: ValueKey(_picked!.id),
                                activity: _picked!,
                                distanceKm: widget.distanceOf?.call(_picked!),
                                onOpen: () => widget.onOpen(_picked!),
                              ),
                              _Stage.nothing => _NothingFits(
                                key: const ValueKey('nothing'),
                                filtered: _filter.isActive,
                              ),
                              _ => SurprisePuzzle(
                                key: const ValueKey('puzzle'),
                                pieces: _loose,
                                chosen: _picked,
                                playToken: _playToken,
                                size: puzzleSize,
                                onDone: _onPuzzleDone,
                              ),
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    final l = context.l10n;
    final picked = _picked;
    // As the Join button on activity details.
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    const label = TextStyle(fontSize: 15, fontWeight: FontWeight.w800);

    final Widget content;
    if (_stage == _Stage.revealed && picked != null) {
      content = Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _joining ? null : _shuffle,
              icon: const Icon(Icons.shuffle_rounded, size: 18),
              label: Text(l.shuffleAgain),
              style: OutlinedButton.styleFrom(
                foregroundColor: SynkColors.textPrimary,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: SynkColors.textSecondary.withValues(alpha: 0.2),
                ),
                minimumSize: const Size(0, 52),
                shape: shape,
                textStyle: label,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _joining ? null : () => _join(picked),
              style: FilledButton.styleFrom(
                backgroundColor: SynkColors.orangeDark,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: shape,
                textStyle: label,
              ),
              child: _joining
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l.joinShort),
            ),
          ),
        ],
      );
    } else if (_stage == _Stage.nothing) {
      content = FilledButton(
        onPressed: _filter.isActive
            ? _openFilter
            : () => Navigator.pop(context),
        style: FilledButton.styleFrom(
          backgroundColor: SynkColors.orangeDark,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: label,
        ),
        child: Text(_filter.isActive ? l.changeFilter : l.backToHome),
      );
    } else {
      final shuffling = _stage == _Stage.shuffling;
      content = FilledButton.icon(
        onPressed: shuffling ? null : _shuffle,
        icon: const Icon(Icons.extension_rounded, size: 20),
        label: Text(shuffling ? l.shuffling : l.surpriseMe),
        style: FilledButton.styleFrom(
          backgroundColor: SynkColors.orangeDark,
          disabledBackgroundColor: SynkColors.orangeDark.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: shape,
          textStyle: label,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: content,
    );
  }
}

// The chosen activity, with its photo, time, place and open spots.
class _SurpriseCard extends StatelessWidget {
  const _SurpriseCard({
    super.key,
    required this.activity,
    required this.onOpen,
    this.distanceKm,
  });

  final Activity activity;
  final VoidCallback onOpen;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final start = activity.dateTime.toLocal();
    final title = activity.title.trim().isEmpty
        ? l.untitledActivity
        : activity.title.trim();
    final details = <(IconData, String)>[
      (
        Icons.calendar_today_rounded,
        '${formatShortDate(start)} · ${formatTime(start.hour, start.minute)}',
      ),
      (
        Icons.place_rounded,
        distanceKm == null
            ? activity.location
            : '${activity.location} · '
                  '${l.topPickDistanceKm(distanceKm!.toStringAsFixed(1))}',
      ),
      (Icons.people_alt_rounded, l.spotsLeft(activity.spotsOpen)),
    ];

    // Styled like the cards on activity details.
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: SynkColors.textSecondary.withValues(alpha: 0.08),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.extension_rounded,
                    size: 18,
                    color: SynkColors.orangeDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.yourSurprise,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: SynkColors.orangeDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // A wide crop of the square thumbnail, so the card fits.
              LayoutBuilder(
                builder: (context, constraints) => ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: constraints.maxWidth * 0.6,
                    width: constraints.maxWidth,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: ActivityThumbnail(
                        activity: activity,
                        size: constraints.maxWidth,
                        radius: 0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.leagueSpartan(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              for (final (icon, text) in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: SynkColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: SynkColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l.tapForDetails,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SynkColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NothingFits extends StatelessWidget {
  const _NothingFits({super.key, required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          const Icon(
            Icons.extension_off_rounded,
            size: 56,
            color: SynkColors.beigeDark,
          ),
          const SizedBox(height: 14),
          Text(
            l.noSurpriseTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.leagueSpartan(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: SynkColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filtered ? l.noSurpriseFiltered : l.noSurpriseMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: SynkColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// When and where, both optional.
class _SurpriseFilterSheet extends StatefulWidget {
  const _SurpriseFilterSheet({required this.initial});

  final SurpriseFilter initial;

  @override
  State<_SurpriseFilterSheet> createState() => _SurpriseFilterSheetState();
}

class _SurpriseFilterSheetState extends State<_SurpriseFilterSheet> {
  late SurpriseFilter _filter = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget group<T>(
      String title,
      List<(T, String)> options,
      T selected,
      void Function(T) onSelect,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: SynkColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in options)
                // The same chips as Home's filters.
                SynkFilterChip(
                  label: label,
                  selected: value == selected,
                  onTap: () => setState(() => onSelect(value)),
                ),
            ],
          ),
        ],
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: SynkColors.textSecondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            group<SurpriseTime>(
              l.surpriseWhen,
              [
                (SurpriseTime.any, l.any),
                (SurpriseTime.today, l.today),
                (SurpriseTime.thisWeek, l.thisWeek),
              ],
              _filter.time,
              (v) => _filter = _filter.copyWith(time: v),
            ),
            const SizedBox(height: 18),
            group<SurpriseSetting>(
              l.surpriseWhere,
              [
                (SurpriseSetting.any, l.all),
                (SurpriseSetting.indoor, l.settingIndoor),
                (SurpriseSetting.outdoor, l.settingOutdoor),
              ],
              _filter.setting,
              (v) => _filter = _filter.copyWith(setting: v),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_filter),
              style: FilledButton.styleFrom(
                backgroundColor: SynkColors.orangeDark,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(l.done),
            ),
          ],
        ),
      ),
    );
  }
}
