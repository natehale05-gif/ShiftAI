import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/util/week.dart';

void main() {
  test('the week closes at Tuesday 10 PM Central, daylight time', () {
    // Tue 22 Sep 2026, 9 PM CDT (UTC-5).
    final WeekClock clock = WeekClock(now: DateTime.utc(2026, 9, 23, 2));
    expect(clock.closesAt, DateTime.utc(2026, 9, 23, 3));
    expect(clock.remaining, const Duration(hours: 1));
    expect(clock.openedAt, DateTime.utc(2026, 9, 16, 3));
  });

  test('just after the close, the next week has begun', () {
    // Tue 22 Sep 2026, 10:30 PM CDT.
    final WeekClock clock = WeekClock(now: DateTime.utc(2026, 9, 23, 3, 30));
    expect(clock.closesAt, DateTime.utc(2026, 9, 30, 3));
    expect(clock.openedAt, DateTime.utc(2026, 9, 23, 3));
  });

  test('in winter the close is an hour later in UTC', () {
    // Tue 1 Dec 2026, noon CST (UTC-6).
    final WeekClock clock = WeekClock(now: DateTime.utc(2026, 12, 1, 18));
    expect(clock.closesAt, DateTime.utc(2026, 12, 2, 4));
  });

  test('the week that crosses the November change is an hour longer', () {
    // Fri 30 Oct 2026. The clocks go back on Sun 1 Nov.
    final WeekClock clock = WeekClock(now: DateTime.utc(2026, 10, 30, 12));
    expect(clock.openedAt, DateTime.utc(2026, 10, 28, 3));
    expect(clock.closesAt, DateTime.utc(2026, 11, 4, 4));
    expect(
      clock.closesAt.difference(clock.openedAt),
      const Duration(hours: 169),
    );
  });

  test('the week that crosses the March change is an hour shorter', () {
    // Fri 6 Mar 2026. This week opened Tue 3 Mar in CST and closes Tue
    // 10 Mar in CDT: the clocks go forward on Sun 8 Mar.
    final WeekClock clock = WeekClock(now: DateTime.utc(2026, 3, 6, 12));
    expect(clock.openedAt, DateTime.utc(2026, 3, 4, 4));
    expect(clock.closesAt, DateTime.utc(2026, 3, 11, 3));
    expect(
      clock.closesAt.difference(clock.openedAt),
      const Duration(hours: 167),
    );
  });

  test('never closes on a Friday', () {
    // Across a whole year, every close is a Tuesday at 10 PM Central.
    DateTime t = DateTime.utc(2026, 1, 1);
    while (t.year == 2026) {
      final WeekClock clock = WeekClock(now: t);
      final DateTime close = clock.closesAt;
      final DateTime central = close.subtract(
        Duration(hours: close.hour == 3 ? 5 : 6),
      );
      expect(central.weekday, DateTime.tuesday, reason: '$t');
      expect(central.hour, 22, reason: '$t');
      t = t.add(const Duration(hours: 13));
    }
  });
}
