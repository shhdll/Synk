import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/constants/synk_colors.dart';
import '../../../l10n/l10n.dart';
import '../../../models/activity_model.dart';

const _flameGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFC23D), SynkColors.orangeDark, Color(0xFFFF5E7E)],
);

// Small 🔥 chip with the streak, shown next to the user's name in the home
// header. It turns grey when the week is nearly over and nothing is booked.
// Tapping opens the sheet.
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
                color: active
                    ? SynkColors.orangeLight
                    : SynkColors.textSecondary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Flame(size: 16, lit: active),
                  const SizedBox(width: 2),
                  Text(
                    '${streak.weeks}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: active
                          ? SynkColors.orangeDeep
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
            _Hero(weeks: streak.weeks, lit: active),
            if (best > 0) ...[
              const SizedBox(height: 12),
              _BestChip(best: best),
            ],
            const SizedBox(height: 20),
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

// Glowing flame that pops in, with the count rolling up beneath it.
class _Hero extends StatelessWidget {
  const _Hero({required this.weeks, required this.lit});

  final int weeks;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: lit
                  ? RadialGradient(
                      colors: [
                        const Color(0xFFFFD27A).withValues(alpha: 0.6),
                        SynkColors.orange.withValues(alpha: 0.0),
                      ],
                    )
                  : null,
              color: lit
                  ? null
                  : SynkColors.textSecondary.withValues(alpha: 0.08),
            ),
            child: Center(child: _Flame(size: 76, lit: lit)),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: weeks.toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            final text = Text(
              '${value.round()}',
              style: TextStyle(
                fontSize: 56,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: lit ? Colors.white : SynkColors.textSecondary,
              ),
            );
            if (!lit) return text;
            return ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [SynkColors.orange, SynkColors.orangeDark],
              ).createShader(bounds),
              child: text,
            );
          },
        ),
        Text(
          context.l10n.streakWeeksInARow(weeks),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: SynkColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _BestChip extends StatelessWidget {
  const _BestChip({required this.best});

  final int best;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: SynkColors.orangeLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            size: 16,
            color: SynkColors.orangeDeep,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.l10n.streakBest(best),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: SynkColors.orangeDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// This week's seven days, Sunday first, with a flame on each attended day.
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: SynkColors.textSecondary.withValues(alpha: 0.10),
        ),
      ),
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
              _StatusPill(done: done, daysLeft: daysLeft),
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
          Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.local_fire_department_rounded,
                size: 18,
                color: done ? SynkColors.teal : SynkColors.orangeDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SynkColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.done, required this.daysLeft});

  final bool done;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final color = done ? SynkColors.tealText : SynkColors.orangeDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: done
            ? SynkColors.teal.withValues(alpha: 0.12)
            : SynkColors.orangeLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        done ? context.l10n.streakDone : context.l10n.streakDaysLeft(daysLeft),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
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
    final BoxDecoration decoration;
    Widget? icon;
    if (attended) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        gradient: _flameGradient,
        boxShadow: [
          BoxShadow(
            color: SynkColors.orangeDark.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );
      icon = const Icon(
        Icons.local_fire_department_rounded,
        color: Colors.white,
        size: 20,
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
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
        Container(width: 36, height: 36, decoration: decoration, child: icon),
        const SizedBox(height: 6),
        Text(
          letter,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
            color: isToday ? SynkColors.orangeDeep : SynkColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Flame extends StatelessWidget {
  const _Flame({required this.size, required this.lit});

  final double size;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    if (!lit) {
      return Icon(
        Icons.local_fire_department_rounded,
        size: size,
        color: SynkColors.textSecondary.withValues(alpha: 0.45),
      );
    }
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => _flameGradient.createShader(bounds),
      child: Icon(
        Icons.local_fire_department_rounded,
        size: size,
        color: Colors.white,
      ),
    );
  }
}
