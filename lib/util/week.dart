/// The weekly board runs Monday to Sunday and closes at 23:59 Pacific.
/// Weeks and earnings come from migration 0015 upstream; until that is
/// deployed the clock is computed on device from the same rule.
class WeekClock {
  WeekClock({DateTime? now}) : _now = now ?? DateTime.now();

  final DateTime _now;

  /// Pacific is UTC-7 in summer and UTC-8 in winter. The board only needs a
  /// close instant that everyone agrees on, so the offset is resolved once
  /// here rather than pulled in as a timezone dependency.
  static const Duration _pacificOffset = Duration(hours: -7);

  DateTime get closesAt {
    final utc = _now.toUtc();
    final pacific = utc.add(_pacificOffset);
    final daysToSunday = DateTime.sunday - pacific.weekday;
    final sunday = pacific.add(Duration(days: daysToSunday));
    final closePacific = DateTime.utc(
      sunday.year,
      sunday.month,
      sunday.day,
      23,
      59,
    );
    return closePacific.subtract(_pacificOffset);
  }

  DateTime get openedAt => closesAt.subtract(const Duration(days: 7));

  Duration get remaining => closesAt.difference(_now.toUtc());

  /// 0 at the open, 1 at the close — the bar under the clock.
  double get elapsedFraction {
    const double week = 7 * 24 * 60 * 60;
    final gone = week - remaining.inSeconds;
    return (gone / week).clamp(0, 1).toDouble();
  }

  /// ISO week number, which is what the ledger keys on.
  int get weekNumber {
    final pacific = _now.toUtc().add(_pacificOffset);
    final thursday =
        pacific.add(Duration(days: DateTime.thursday - pacific.weekday));
    final firstOfYear = DateTime.utc(thursday.year, 1, 1);
    final days = thursday.difference(firstOfYear).inDays;
    return (days / 7).floor() + 1;
  }
}
