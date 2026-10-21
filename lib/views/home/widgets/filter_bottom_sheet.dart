import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../controllers/home_discovery_controller.dart';
import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_filters.dart';
import '../../widgets/synk_date_picker.dart';
import 'synk_filter_chip.dart';

// Edits a draft; only Show applies it.
Future<void> showHomeFilterBottomSheet({
  required BuildContext context,
  required HomeDiscoveryController controller,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: SynkColors.ink.withValues(alpha: 0.45),
    builder: (context) => FilterBottomSheet(controller: controller),
  );
}

// The Map keeps its own filters. Picking a sort applies it right away and
// closes the sheet, so the map can show the cards in that order.
Future<void> showMapFilterBottomSheet({
  required BuildContext context,
  required HomeDiscoveryController controller,
  required ActivityFilters filters,
  required int Function(ActivityFilters) countFor,
  required ValueChanged<ActivityFilters> onApply,
  required ValueChanged<ActivityFilters> onSortPicked,
  required bool hasLocation,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: SynkColors.ink.withValues(alpha: 0.45),
    builder: (context) => FilterBottomSheet(
      controller: controller,
      filters: filters,
      countFor: countFor,
      onApply: onApply,
      onSortPicked: onSortPicked,
      hasLocation: hasLocation,
    ),
  );
}

const _handleColor = Color(0xFFD8CDBB);

TextStyle _inter(double size, FontWeight weight, Color color) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.controller,
    this.filters,
    this.countFor,
    this.onApply,
    this.onSortPicked,
    this.hasLocation,
  });

  // Location and categories come from here. Without the options below, the
  // sheet edits this controller's (Home's) filters.
  final HomeDiscoveryController controller;
  final ActivityFilters? filters;
  final int Function(ActivityFilters)? countFor;
  final ValueChanged<ActivityFilters>? onApply;

  // When set, tapping a sort applies the filters and closes the sheet.
  final ValueChanged<ActivityFilters>? onSortPicked;

  // The Map finds the user itself, so it says whether it knows where they
  // are. Otherwise the controller's location is used.
  final bool? hasLocation;

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late ActivityFilters _draft = widget.filters ?? widget.controller.filters;

  HomeDiscoveryController get _c => widget.controller;

  // Home's list is already soonest first with no sort picked, so the sheet
  // shows Soonest as chosen there. The Map has no default order.
  bool get _soonestByDefault => widget.filters == null;

  bool _isSortSelected(SortOption option) =>
      _draft.sort == option ||
      (_soonestByDefault &&
          _draft.sort == null &&
          option == SortOption.soonest);

  void _update(ActivityFilters next) => setState(() => _draft = next);

  void _apply() {
    (widget.onApply ?? _c.applyFilters)(_draft);
    Navigator.of(context).pop();
  }

  void _pickSort(SortOption option) {
    // On Home, Soonest is the default, so picking it doesn't count as a
    // changed filter.
    final next = _soonestByDefault && option == SortOption.soonest
        ? _draft.withSort(null)
        : _draft.copyWith(sort: option);
    final onSortPicked = widget.onSortPicked;
    if (onSortPicked == null) {
      _update(next);
      return;
    }
    Navigator.of(context).pop();
    onSortPicked(next);
  }

  Future<void> _onPickDate() async {
    if (_draft.date == DateOption.custom) {
      _update(_draft.withDate(DateOption.any));
      return;
    }
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showSynkDateRangePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      _update(
        _draft.withDate(
          DateOption.custom,
          customDate: picked.start,
          customEndDate: picked.end == picked.start ? null : picked.end,
        ),
      );
    }
  }

  Future<void> _onPickTime() async {
    if (_draft.fromMinute != null) {
      _update(_draft.withTime());
      return;
    }
    final picked = await showSynkTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      title: context.l10n.startingFrom,
    );
    if (picked != null && mounted) {
      _update(_draft.withTime(fromMinute: picked.hour * 60 + picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final count = (widget.countFor ?? _c.countFor)(_draft);
        final hasLocation = widget.hasLocation ?? _c.userLocation != null;

        return Container(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
          decoration: const BoxDecoration(
            color: SynkColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + media.padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Handle(),
              const SizedBox(height: 14),
              _buildHeader(),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSort(hasLocation),
                      const SizedBox(height: 14),
                      _buildDate(),
                      const SizedBox(height: 14),
                      _buildTime(),
                      ..._buildCategories(),
                      const SizedBox(height: 14),
                      _buildDistance(hasLocation),
                      const SizedBox(height: 14),
                      _buildSpots(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildShowButton(count),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: context.l10n.close,
                onPressed: () => Navigator.of(context).pop(),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: SynkColors.ink,
                ),
              ),
            ),
          ),
          Text(
            context.l10n.filters,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: SynkColors.ink,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => _update(ActivityFilters.defaults),
              style: TextButton.styleFrom(
                foregroundColor: SynkColors.tealText,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                context.l10n.reset,
                style: _inter(14, FontWeight.w700, SynkColors.tealText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSort(bool hasLocation) {
    return _Section(
      label: context.l10n.sortBy,
      columns: 2,
      children: [
        for (final option in SortOption.values)
          SynkFilterChip(
            label: option.label,
            selected: _isSortSelected(option),
            onTap:
                (option.needsLocation && !hasLocation) ||
                    (option.bySpots && _draft.spots.isSingleCount)
                ? null
                : () => _pickSort(option),
          ),
      ],
    );
  }

  Widget _buildDate() {
    final custom = _draft.date == DateOption.custom ? _draft.customDate : null;

    SynkFilterChip day(DateOption option) => SynkFilterChip(
      label: option.label,
      selected: _draft.date == option,
      onTap: () => _update(
        _draft.withDate(_draft.date == option ? DateOption.any : option),
      ),
    );

    return _Section(
      label: context.l10n.date,
      columns: 3,
      children: [
        day(DateOption.today),
        day(DateOption.tomorrow),
        SynkFilterChip(
          label: custom == null ? context.l10n.pickADate : _draft.dateLabel!,
          icon: Icons.calendar_month_rounded,
          selected: custom != null,
          onTap: _onPickDate,
        ),
      ],
    );
  }

  Widget _buildTime() {
    final from = _draft.fromMinute;

    return _Section(
      label: context.l10n.time,
      columns: 4,
      children: [
        for (final slot in DaySlot.values)
          _TwoLineChip(
            title: slot.label,
            subtitle: slot.hours,
            selected: _draft.daySlot == slot,
            onTap: () => _update(
              _draft.daySlot == slot
                  ? _draft.withTime()
                  : _draft.withTime(slot: slot),
            ),
          ),
        _TwoLineChip(
          title: from == null
              ? context.l10n.timeChipPick
              : context.l10n.timeChipFrom,
          subtitle: from == null
              ? context.l10n.timeChipATime
              : formatMinute(from),
          icon: Icons.schedule_rounded,
          selected: from != null,
          onTap: _onPickTime,
        ),
      ],
    );
  }

  List<Widget> _buildCategories() {
    final categories = _c.categoriesInFeed(
      HomeDiscoveryController.knownCategories,
    );
    for (final selected in _draft.categories) {
      if (!categories.contains(selected)) categories.add(selected);
    }
    if (categories.isEmpty) return const [];

    return [
      const SizedBox(height: 14),
      _Section(
        label: context.l10n.category,
        columns: 3,
        children: [
          for (final category in categories)
            SynkFilterChip.category(
              category: category,
              selected: _draft.categories.contains(category),
              onTap: () => _update(_draft.toggleCategory(category)),
            ),
        ],
      ),
    ];
  }

  Widget _buildDistance(bool hasLocation) {
    final options = DistanceOption.values.where((o) => o != DistanceOption.any);

    return _Section(
      label: context.l10n.within,
      columns: 3,
      trailing: hasLocation
          ? null
          : _c.isLocating
          ? Text(
              context.l10n.locating,
              style: _inter(13, FontWeight.w600, SynkColors.labelGrey),
            )
          : _LinkButton(
              label: _c.locationBlocked
                  ? context.l10n.allowLocation
                  : context.l10n.tryAgain,
              onTap: () => _c.refreshLocation(request: true),
            ),
      children: [
        for (final option in options)
          SynkFilterChip(
            label: option.label,
            selected: _draft.distance == option,
            onTap: hasLocation
                ? () => _update(
                    _draft.copyWith(
                      distance: _draft.distance == option
                          ? DistanceOption.any
                          : option,
                    ),
                  )
                : null,
          ),
      ],
    );
  }

  Widget _buildSpots() {
    final options = SpotsOption.values.where((o) => o != SpotsOption.any);

    return _Section(
      label: context.l10n.spots,
      columns: 3,
      children: [
        for (final option in options)
          SynkFilterChip(
            label: option.label,
            selected: _draft.spots == option,
            onTap: option.isSingleCount && (_draft.sort?.bySpots ?? false)
                ? null
                : () => _update(
                    _draft.copyWith(
                      spots: _draft.spots == option ? SpotsOption.any : option,
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildShowButton(int count) {
    final label = switch (count) {
      0 => context.l10n.noMatchesTryFewerFilters,
      1 => context.l10n.showOneActivity,
      _ => context.l10n.showActivities(count),
    };

    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: count == 0 ? null : _apply,
        style: FilledButton.styleFrom(
          backgroundColor: SynkColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _handleColor,
          disabledForegroundColor: SynkColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          textStyle: _inter(16, FontWeight.w700, Colors.white),
        ),
        child: Text(label),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: _handleColor,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.columns,
    required this.children,
    this.trailing,
  });

  final String label;
  final int columns;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var j = i; j < i + columns; j++) {
        if (j > i) cells.add(const SizedBox(width: 8));
        cells.add(
          Expanded(child: j < children.length ? children[j] : const SizedBox()),
        );
      }
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(Row(children: cells));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: _inter(13, FontWeight.w700, SynkColors.labelGrey),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }
}

class _TwoLineChip extends StatelessWidget {
  const _TwoLineChip({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? SynkColors.onSelected : SynkColors.ink;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? SynkColors.selected : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 14, color: foreground),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        title,
                        style: _inter(13, FontWeight.w600, foreground),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: _inter(
                      11,
                      FontWeight.w400,
                      selected
                          ? SynkColors.onSelected
                          : SynkColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: SynkColors.tealText,
        minimumSize: const Size(0, 24),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: _inter(13, FontWeight.w700, SynkColors.tealText),
      ),
    );
  }
}
