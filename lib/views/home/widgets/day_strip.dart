import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_filters.dart';

class DayStrip extends StatelessWidget {
  const DayStrip({
    super.key,
    required this.filters,
    required this.countsByDay,
    required this.onDayTap,
    this.padding = EdgeInsets.zero,
    this.days = 14,
  });

  final ActivityFilters filters;
  final Map<DateTime, int> countsByDay;
  final ValueChanged<DateTime> onDayTap;
  final EdgeInsets padding;
  final int days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);

    return SizedBox(
      height: 66,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding.add(const EdgeInsets.only(bottom: 6)),
        physics: const BouncingScrollPhysics(),
        itemCount: days,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = DateTime(today.year, today.month, today.day + index);
          return _DayCell(
            day: day,
            label: index == 0 ? context.l10n.today : shortWeekday(day),
            selected: filters.coversDay(day, now),
            count: countsByDay[day] ?? 0,
            onTap: () => onDayTap(day),
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final DateTime day;
  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPlans = count > 0;
    final radius = BorderRadius.circular(16);

    final Color background;
    final Color foreground;
    final Color subtle;
    if (selected) {
      background = SynkColors.selected;
      foreground = SynkColors.onSelected;
      subtle = SynkColors.onSelected;
    } else if (hasPlans) {
      background = Colors.white;
      foreground = SynkColors.ink;
      subtle = SynkColors.labelGrey;
    } else {
      background = Colors.transparent;
      foreground = SynkColors.labelGrey;
      subtle = SynkColors.labelGrey;
    }

    return Semantics(
      button: true,
      selected: selected,
      label:
          '${formatShortDate(day)}, '
          '${hasPlans ? context.l10n.planCount(count) : context.l10n.noPlans}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: hasPlans || selected
              ? null
              : Border.all(color: SynkColors.labelGrey.withValues(alpha: 0.25)),
          boxShadow: hasPlans && !selected
              ? [
                  BoxShadow(
                    color: SynkColors.orangeDark.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: background,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: SizedBox(
              width: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: subtle,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: GoogleFonts.inter(
                      fontSize: 19,
                      fontWeight: hasPlans || selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                      height: 1.1,
                      color: foreground,
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
