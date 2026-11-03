import 'package:flutter/material.dart';
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
            child: Container(
              key: ValueKey(active ? 'streak-lit' : 'streak-grey'),
              padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: SynkColors.textSecondary.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 15,
                    color: active
                        ? SynkColors.orangeDark
                        : SynkColors.labelGrey,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${streak.weeks}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: active
                          ? SynkColors.textPrimary
                          : SynkColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    final today = now ?? DateTime.now();
    final streak = WeeklyStreak.from(attendedAt, now: today);
    final best = WeeklyStreak.best(attendedAt, now: today);
    final active = streak.weeks > 0;
    final message = streak.attendedThisWeek
        ? context.l10n.streakKeptThisWeek
        : active
        ? context.l10n.streakKeepGoing
        : context.l10n.streakStart;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        20 + MediaQuery.viewPaddingOf(context).bottom,
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
            const SizedBox(height: 18),
            _Summary(weeks: streak.weeks, best: best, lit: active),
            const SizedBox(height: 12),
            _ThisWeekCard(
              days: WeeklyStreak.daysThisWeek(attendedAt, now: today),
              today: today,
              done: streak.attendedThisWeek,
              message: message,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.streakHowItWorks,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: SynkColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The count next to a plain flame, with the best streak under it.
class _Summary extends StatelessWidget {
  const _Summary({required this.weeks, required this.best, required this.lit});

  final int weeks;
  final int best;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 44,
            color: lit ? SynkColors.orangeDark : SynkColors.labelGrey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$weeks',
                      style: const TextStyle(
                        fontSize: 34,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: SynkColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.l10n.streakWeeksInARow(weeks),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SynkColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (best > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.streakBest(best),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: SynkColors.labelGrey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

// This week's seven days, Sunday first; attended days are filled.
class _ThisWeekCard extends StatelessWidget {
  const _ThisWeekCard({
    required this.days,
    required this.today,
    required this.done,
    required this.message,
  });

  final List<bool> days;
  final DateTime today;
  final bool done;
  final String message;

  @override
  Widget build(BuildContext context) {
    final start = WeeklyStreak.weekStart(now: today);
    final todayIndex = today.weekday % 7;
    final daysLeft = WeeklyStreak.daysLeft(now: today);
    final dayName = DateFormat(
      'EEEEE',
      Localizations.localeOf(context).languageCode,
    );

    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.streakThisWeek,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: SynkColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                done
                    ? context.l10n.streakDone
                    : context.l10n.streakDaysLeft(daysLeft),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: done ? SynkColors.tealText : SynkColors.orangeDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: SynkColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
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
    final BoxDecoration decoration;
    if (attended) {
      decoration = const BoxDecoration(
        shape: BoxShape.circle,
        color: SynkColors.orangeDark,
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: SynkColors.orangeDark, width: 2),
      );
    } else {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: SynkColors.textSecondary.withValues(alpha: isPast ? 0.12 : 0.06),
      );
    }

    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: decoration,
          child: attended
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          letter,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday ? SynkColors.textPrimary : SynkColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
