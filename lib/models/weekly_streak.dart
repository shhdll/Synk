// How many weeks in a row the user attended at least one activity.
//
// Weeks run Sunday to Saturday in the device's local time. The current week
// keeps the streak alive until it ends: if nothing was attended yet this
// week, the streak still counts the weeks before it, and only breaks once a
// whole week passes with no activity.
class WeeklyStreak {
  const WeeklyStreak({required this.weeks, required this.attendedThisWeek});

  static const WeeklyStreak none = WeeklyStreak(
    weeks: 0,
    attendedThisWeek: false,
  );

  final int weeks;

  // True once an activity was attended in the current week.
  final bool attendedThisWeek;

  // [attendedAt] holds the start times of attended activities. Times after
  // [now] are ignored, since those activities haven't happened yet.
  factory WeeklyStreak.from(Iterable<DateTime> attendedAt, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final attendedWeeks = {
      for (final time in attendedAt)
        if (!time.isAfter(today)) weekIndex(time),
    };

    final currentWeek = weekIndex(today);
    final attendedThisWeek = attendedWeeks.contains(currentWeek);

    var week = attendedThisWeek ? currentWeek : currentWeek - 1;
    var weeks = 0;
    while (attendedWeeks.contains(week)) {
      weeks++;
      week--;
    }

    return WeeklyStreak(weeks: weeks, attendedThisWeek: attendedThisWeek);
  }

  // The longest run of weeks in a row ever attended, including the current
  // streak.
  static int best(Iterable<DateTime> attendedAt, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final weeks = {
      for (final time in attendedAt)
        if (!time.isAfter(today)) weekIndex(time),
    }.toList()..sort();

    var best = 0;
    var run = 0;
    for (var i = 0; i < weeks.length; i++) {
      run = i > 0 && weeks[i] == weeks[i - 1] + 1 ? run + 1 : 1;
      if (run > best) best = run;
    }
    return best;
  }

  // Which days of the current week (Sunday first) had an attended activity.
  static List<bool> daysThisWeek(
    Iterable<DateTime> attendedAt, {
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final start = weekStart(now: today);
    final days = List<bool>.filled(7, false);
    for (final time in attendedAt) {
      if (time.isAfter(today)) continue;
      final local = time.toLocal();
      final day = DateTime.utc(
        local.year,
        local.month,
        local.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
      if (day >= 0 && day < 7) days[day] = true;
    }
    return days;
  }

  // The streak is about to break: it's the last [warnDays] days of the week,
  // nothing was attended yet, and nothing is booked before the week ends.
  // [booked] holds start times of upcoming hosted or joined activities.
  static bool isFading(
    WeeklyStreak streak,
    Iterable<DateTime> booked, {
    int warnDays = 2,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    if (streak.weeks == 0 || streak.attendedThisWeek) return false;
    if (daysLeft(now: today) > warnDays) return false;
    final week = weekIndex(today);
    return !booked.any(
      (time) => time.isAfter(today) && weekIndex(time) == week,
    );
  }

  // Days left in the current week, counting today (Saturday is 1).
  static int daysLeft({DateTime? now}) {
    final today = (now ?? DateTime.now()).toLocal();
    return 7 - today.weekday % 7;
  }

  // The Sunday that starts the week [weeksAgo] weeks before [now]'s week.
  static DateTime weekStart({int weeksAgo = 0, DateTime? now}) {
    final today = (now ?? DateTime.now()).toLocal();
    return DateTime(
      today.year,
      today.month,
      today.day - today.weekday % 7 - 7 * weeksAgo,
    );
  }

  // A Sunday, used as the start of week 0.
  static final DateTime _firstSunday = DateTime.utc(1970, 1, 4);

  // Number of the Sunday-to-Saturday week [time] falls in, by local date.
  // Counting calendar days (not hours) keeps daylight saving from shifting
  // a time into the wrong week.
  static int weekIndex(DateTime time) {
    final local = time.toLocal();
    final days = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).difference(_firstSunday).inDays;
    return (days - days % 7) ~/ 7;
  }

  @override
  bool operator ==(Object other) =>
      other is WeeklyStreak &&
      other.weeks == weeks &&
      other.attendedThisWeek == attendedThisWeek;

  @override
  int get hashCode => Object.hash(weeks, attendedThisWeek);

  @override
  String toString() =>
      'WeeklyStreak(weeks: $weeks, attendedThisWeek: $attendedThisWeek)';
}
