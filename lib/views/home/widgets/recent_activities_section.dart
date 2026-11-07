import 'package:flutter/material.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activities_model.dart';
import '../../../models/activity_model.dart';
import '../../../utils/custom_widgets/synk_dialog.dart';
import 'activity_thumbnail.dart';

// A user's latest ended activities, three to a row, in a card that folds.
// Hidden while loading, on errors, and when nothing is visible to the viewer.
// On the user's own profile each one can be hidden.
class RecentActivitiesSection extends StatefulWidget {
  const RecentActivitiesSection({
    super.key,
    required this.userId,
    required this.userName,
    this.activitiesModel,
    this.frame,
  });

  final String userId;
  final String userName;

  // Wraps the tiles in another card, e.g. the profile's own sections.
  final Widget Function(String title, Widget child)? frame;

  // Bumped when the user hides one somewhere else, so open sections reload.
  static final ValueNotifier<int> changes = ValueNotifier(0);

  // Injectable for tests.
  final ActivitiesModel? activitiesModel;

  @override
  State<RecentActivitiesSection> createState() =>
      _RecentActivitiesSectionState();
}

class _RecentActivitiesSectionState extends State<RecentActivitiesSection> {
  static const int _previewCount = 12;

  @override
  void initState() {
    super.initState();
    RecentActivitiesSection.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    RecentActivitiesSection.changes.removeListener(_load);
    super.dispose();
  }

  List<Activity> _activities = const [];

  // Only on the user's own profile.
  List<Activity> _hidden = const [];

  ActivitiesModel get _model => widget.activitiesModel ?? ActivitiesModel();

  bool get _isMine => widget.userId == _model.currentUserId;

  Future<void> _load() async {
    try {
      final page = await _model.fetchUserRecentActivities(
        userId: widget.userId,
        limit: _previewCount,
      );
      final hidden = _isMine
          ? await _model.fetchHiddenRecentActivities()
          : const <Activity>[];
      if (!mounted || !page.allowed) return;
      setState(() {
        _activities = page.activities;
        _hidden = hidden;
      });
    } catch (_) {
      // The section stays hidden when the history cannot be loaded.
    }
  }

  Future<void> _hide(Activity activity) async {
    final hide = await SynkDialog.confirm(
      context,
      icon: Icons.visibility_off_outlined,
      title: context.l10n.hideFromRecentTitle,
      message: context.l10n.hideFromRecentMessage,
      action: context.l10n.hide,
    );
    if (!hide || !mounted) return;
    final before = _activities;
    setState(() {
      _activities = [
        for (final a in _activities)
          if (a.id != activity.id) a,
      ];
    });
    try {
      await _model.hideRecentActivity(activity.id);
      // Brings in the next one so the card stays full.
      await _load();
    } catch (_) {
      if (mounted) setState(() => _activities = before);
    }
  }

  static Widget _foldCard(String title, Widget child) =>
      FoldCard(title: title, child: child);

  Future<void> _openHidden() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SynkColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _HiddenSheet(
        activities: _hidden,
        onUnhide: (activity) async {
          await _model.unhideRecentActivity(activity.id);
          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_activities.isEmpty && _hidden.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: (widget.frame ?? _foldCard)(
        context.l10n.recentActivities,
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final width = (constraints.maxWidth - gap * 2) / 3;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final activity in _activities)
                      RecentActivityTile(
                        activity: activity,
                        width: width,
                        onHide: _isMine ? () => _hide(activity) : null,
                      ),
                  ],
                );
              },
            ),
            if (_hidden.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: _activities.isEmpty ? 0 : 8),
                child: InkWell(
                  onTap: _openHidden,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      '${context.l10n.hiddenActivities} (${_hidden.length})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: SynkColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// The user's hidden activities, each with an Unhide button.
class _HiddenSheet extends StatefulWidget {
  const _HiddenSheet({required this.activities, required this.onUnhide});

  final List<Activity> activities;
  final Future<void> Function(Activity activity) onUnhide;

  @override
  State<_HiddenSheet> createState() => _HiddenSheetState();
}

class _HiddenSheetState extends State<_HiddenSheet> {
  late List<Activity> _left = widget.activities;
  final Set<String> _busy = {};

  Future<void> _unhide(Activity activity) async {
    setState(() => _busy.add(activity.id));
    try {
      await widget.onUnhide(activity);
      if (!mounted) return;
      setState(() {
        _left = [
          for (final a in _left)
            if (a.id != activity.id) a,
        ];
      });
      if (_left.isEmpty) Navigator.pop(context);
    } catch (_) {
      // Stays in the list; the button can be tapped again.
    } finally {
      if (mounted) setState(() => _busy.remove(activity.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                context.l10n.hiddenActivitiesTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 12, 16),
                children: [
                  for (final activity in _left)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          ActivityThumbnail(
                            activity: activity,
                            size: 44,
                            radius: 10,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: SynkColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  formatShortDate(activity.dateTime),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: SynkColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: _busy.contains(activity.id)
                                ? null
                                : () => _unhide(activity),
                            style: TextButton.styleFrom(
                              foregroundColor: SynkColors.orangeDark,
                            ),
                            child: Text(context.l10n.unhide),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The profile's card style; tapping the title folds it away.
class FoldCard extends StatefulWidget {
  const FoldCard({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  State<FoldCard> createState() => _FoldCardState();
}

class _FoldCardState extends State<FoldCard> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: SynkColors.textSecondary,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_open) ...[
              const SizedBox(height: 4),
              widget.child,
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

// Image, title and date of one ended activity.
class RecentActivityTile extends StatelessWidget {
  const RecentActivityTile({
    super.key,
    required this.activity,
    this.width = 104,
    this.onHide,
  });

  final Activity activity;
  final double width;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ActivityThumbnail(activity: activity, size: width, radius: 14),
              if (onHide != null)
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onHide,
                      child: Tooltip(
                        message: context.l10n.hide,
                        child: const Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(
                            Icons.visibility_off_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            activity.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SynkColors.textPrimary,
            ),
          ),
          Text(
            formatShortDate(activity.dateTime),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: SynkColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
