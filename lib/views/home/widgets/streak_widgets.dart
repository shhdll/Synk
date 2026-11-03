import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_model.dart';

// Small flame chip with the streak, shown next to the user's name in the
// home header. It turns grey when the week is nearly over and nothing is
// booked. Tapping opens the sheet.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.activityStore});

  final ActivityStore activityStore;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: activityStore,
      builder: (context, _) {
        final streak = activityStore.weeklyStreak;
        // Grey while fading, as a nudge to book something.
        final active = streak.weeks > 0 && !activityStore.streakFading;

        return Tooltip(
          message: context.l10n.streakTitle,
          child: GestureDetector(
            key: const ValueKey('streak-chip'),
            behavior: HitTestBehavior.opaque,
            onTap: () => showStreakSheet(context, activityStore),
            child: StreakPill(weeks: streak.weeks, active: active),
          ),
        );
      },
    );
  }
}

// The flame and the number of weeks, no box. Grey when not [active].
class StreakPill extends StatelessWidget {
  const StreakPill({super.key, required this.weeks, required this.active});

  final int weeks;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey(active ? 'streak-lit' : 'streak-grey'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_fire_department_rounded,
          size: 17,
          color: active ? SynkColors.orangeDark : SynkColors.labelGrey,
        ),
        const SizedBox(width: 2),
        Text(
          '$weeks',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: active ? SynkColors.textPrimary : SynkColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

Future<void> showStreakSheet(BuildContext context, ActivityStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StreakSheet(attendedAt: store.attendedTimes),
  );
}

// The streak up close: the count, the user's best, and this week's days so
// it's clear what's left to do.
class StreakSheet extends StatelessWidget {
  const StreakSheet({super.key, required this.attendedAt, this.now});

  // Start times of attended activities.
  final List<DateTime> attendedAt;

  // Overridable for tests.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = now ?? DateTime.now();
    final streak = WeeklyStreak.from(attendedAt, now: today);
    final best = WeeklyStreak.best(attendedAt, now: today);
    final lit = streak.weeks > 0;
    final message = streak.attendedThisWeek
        ? l.streakKeptThisWeek
        : lit
        ? l.streakKeepGoing
        : l.streakStart;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: SynkColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SynkColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 22),
            Icon(
              Icons.local_fire_department_rounded,
              size: 52,
              color: lit ? SynkColors.orangeDark : SynkColors.labelGrey,
            ),
            Text(
              '${streak.weeks}',
              style: GoogleFonts.nunito(
                fontSize: 46,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: SynkColors.ink,
              ),
            ),
            Text(
              l.streakWeeksInARow(streak.weeks),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SynkColors.textSecondary,
              ),
            ),
            if (best > 0) ...[
              const SizedBox(height: 4),
              Text(
                l.streakBest(best),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: SynkColors.labelGrey,
                ),
              ),
            ],
            const SizedBox(height: 22),
            _Weeks(attendedAt: attendedAt, today: today),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: SynkColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The week's seven days, Sunday first; days with an activity show a flame.
// Swipe back to see earlier weeks.
class _Weeks extends StatefulWidget {
  const _Weeks({required this.attendedAt, required this.today});

  final List<DateTime> attendedAt;
  final DateTime today;

  // How far back the user can swipe.
  static const int _weeksBack = 52;

  @override
  State<_Weeks> createState() => _WeeksState();
}

class _WeeksState extends State<_Weeks> {
  final PageController _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        // Title line, gap and day tiles; the title grows with text size.
        height:
            math.max(
              _WeekArrow.size,
              MediaQuery.textScalerOf(context).scale(13) * 1.5,
            ) +
            12 +
            52,
        // Reversed, so the week before is the one you swipe back to.
        child: PageView.builder(
          controller: _pages,
          reverse: true,
          itemCount: _Weeks._weeksBack + 1,
          itemBuilder: (context, weeksAgo) => _week(context, weeksAgo),
        ),
      ),
    );
  }

  Widget _week(BuildContext context, int weeksAgo) {
    final l = context.l10n;
    final today = widget.today;
    final current = weeksAgo == 0;
    final start = WeeklyStreak.weekStart(weeksAgo: weeksAgo, now: today);
    final end = DateTime(start.year, start.month, start.day + 6);
    // The last moment of that week, or now for this week.
    final until = current
        ? today
        : DateTime(
            start.year,
            start.month,
            start.day + 7,
          ).subtract(const Duration(microseconds: 1));
    final days = WeeklyStreak.daysThisWeek(widget.attendedAt, now: until);
    final done = days.contains(true);
    final todayIndex = current ? today.weekday % 7 : 7;
    final dayName = DateFormat(
      'EEEEE',
      Localizations.localeOf(context).languageCode,
    );

    final title = switch (weeksAgo) {
      0 => l.streakThisWeek,
      1 => l.streakLastWeek,
      _ =>
        start.month == end.month
            ? '${monthShort(start.month)} ${start.day} – ${end.day}'
            : '${monthShort(start.month)} ${start.day} – '
                  '${monthShort(end.month)} ${end.day}',
    };
    final String? status = current && !done
        ? l.streakDaysLeft(WeeklyStreak.daysLeft(now: today))
        : null;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Column(
      children: [
        Row(
          children: [
            // Earlier weeks sit on the start side, later ones on the end.
            _WeekArrow(
              icon: rtl
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              label: l.streakEarlierWeek,
              onTap: weeksAgo < _Weeks._weeksBack
                  ? () => _pages.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    )
                  : null,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: SynkColors.textSecondary,
                ),
              ),
            ),
            if (status != null)
              Text(
                status,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: SynkColors.orangeDeep,
                ),
              ),
            const SizedBox(width: 2),
            _WeekArrow(
              icon: rtl
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              label: l.streakLaterWeek,
              onTap: weeksAgo > 0
                  ? () => _pages.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: _Day(
                  letter: dayName.format(
                    DateTime(start.year, start.month, start.day + i),
                  ),
                  attended: days[i],
                  isToday: i == todayIndex,
                  isPast: i < todayIndex,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// A very small arrow to the week before or after; empty space when there's
// none, so the title doesn't move.
class _WeekArrow extends StatelessWidget {
  const _WeekArrow({required this.icon, required this.label, this.onTap});

  static const double size = 24;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return const SizedBox(width: size, height: size);
    return Semantics(
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 18, color: SynkColors.labelGrey),
        ),
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.letter,
    required this.attended,
    required this.isToday,
    required this.isPast,
  });

  final String letter;
  final bool attended;
  final bool isToday;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    if (attended) {
      fill = SynkColors.orangeLight;
    } else if (isPast) {
      fill = SynkColors.textSecondary.withValues(alpha: 0.08);
    } else {
      fill = SynkColors.background;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: isToday
              ? Border.all(color: SynkColors.orangeDark, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              letter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                color: isToday
                    ? SynkColors.textPrimary
                    : SynkColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 18,
              child: attended
                  ? const Icon(
                      Icons.local_fire_department_rounded,
                      size: 18,
                      color: SynkColors.orangeDark,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
