/// The board's week, as the Suite runs it: Tuesday 10 PM Central to the
/// next Tuesday 10 PM Central. Pools pay on Friday, which is not the close.
///
/// This used to close the week at Sunday 11:59 PM Pacific, which was never
/// the Suite's week. The countdown on the leaderboard was wrong by two
/// days and two hours.
///
/// Central is UTC-6, or UTC-5 while US daylight saving is on: from 2 AM on
/// the second Sunday in March to 2 AM on the first Sunday in November. That
/// rule is written out here rather than pulling in a timezone package, and
/// a week that crosses a change is an hour longer or shorter, as the
/// Suite's is.
class WeekClock {
  WeekClock({DateTime? now}) : _now = (now ?? DateTime.now()).toUtc();

  final DateTime _now;

  static const int _closeHour = 22;

  /// The Nth [weekday] of [month], as a date at midnight UTC.
  static DateTime _nth(int year, int month, int weekday, int n) {
    final DateTime first = DateTime.utc(year, month, 1);
    final int offset = (weekday - first.weekday) % 7;
    return first.add(Duration(days: offset + 7 * (n - 1)));
  }

  /// Whether US daylight saving is in force at [utc], in Central time.
  static bool _isDaylight(DateTime utc) {
    // 2 AM CST (UTC-6) on the second Sunday in March is 08:00 UTC; 2 AM
    // CDT (UTC-5) on the first Sunday in November is 07:00 UTC.
    final DateTime start = _nth(utc.year, DateTime.march, DateTime.sunday, 2)
        .add(const Duration(hours: 8));
    final DateTime end = _nth(utc.year, DateTime.november, DateTime.sunday, 1)
        .add(const Duration(hours: 7));
    return !utc.isBefore(start) && utc.isBefore(end);
  }

  static Duration _offsetAt(DateTime utc) =>
      Duration(hours: _isDaylight(utc) ? -5 : -6);

  /// Central wall-clock time at [utc], carried in a UTC DateTime's fields.
  static DateTime _central(DateTime utc) => utc.add(_offsetAt(utc));

  /// The instant a Central wall-clock time falls on. The close is at
  /// 10 PM, which is never inside the hour a clock change repeats or
  /// skips, so exactly one offset fits.
  static DateTime _fromCentral(DateTime wall) {
    for (final int hours in const <int>[-5, -6]) {
      final DateTime utc = wall.subtract(Duration(hours: hours));
      if (_offsetAt(utc).inHours == hours) return utc;
    }
    return wall.add(const Duration(hours: 6));
  }

  /// The next Tuesday 10 PM Central in wall-clock fields, strictly after now.
  DateTime get _closeWall {
    final DateTime here = _central(_now);
    final int ahead = (DateTime.tuesday - here.weekday) % 7;
    DateTime close =
        DateTime.utc(here.year, here.month, here.day + ahead, _closeHour);
    if (!close.isAfter(here)) {
      close = DateTime.utc(close.year, close.month, close.day + 7, _closeHour);
    }
    return close;
  }

  /// When this week's board closes.
  DateTime get closesAt => _fromCentral(_closeWall);

  /// When this week's board opened: the Tuesday before, at 10 PM Central.
  DateTime get openedAt {
    final DateTime close = _closeWall;
    return _fromCentral(
      DateTime.utc(close.year, close.month, close.day - 7, _closeHour),
    );
  }

  Duration get remaining => closesAt.difference(_now);

  /// 0 at the open, 1 at the close: the bar under the clock.
  double get elapsedFraction {
    final int week = closesAt.difference(openedAt).inSeconds;
    final int gone = _now.difference(openedAt).inSeconds;
    return (gone / week).clamp(0, 1).toDouble();
  }

  /// The ISO week number of the Tuesday the board opened on, in Central
  /// time. What the header calls "Week N".
  int get weekNumber {
    final DateTime opened = _central(openedAt);
    final DateTime thursday =
        opened.add(Duration(days: DateTime.thursday - opened.weekday));
    final DateTime firstOfYear = DateTime.utc(thursday.year, 1, 1);
    final int days = thursday.difference(firstOfYear).inDays;
    return (days / 7).floor() + 1;
  }
}
