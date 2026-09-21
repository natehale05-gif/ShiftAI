import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/state/daily_rings.dart';

void main() {
  group('the day rolls over cleanly', () {
    test('the same day changes nothing', () {
      final DateTime now = DateTime(2026, 9, 20, 14, 30);
      final DailyRings rings =
          DailyRings(day: DailyRings.keyFor(now), create: true, streak: 2);
      expect(rings.rolledTo(now), same(rings));
      expect(rings.rolledTo(DateTime(2026, 9, 20, 23, 59)), same(rings));
    });

    test('a fresh day clears all three but keeps the streak going', () {
      final DateTime yesterday = DateTime(2026, 9, 20);
      final DailyRings closed = DailyRings(
        day: DailyRings.keyFor(yesterday),
        create: true,
        publish: true,
        compete: true,
        streak: 4,
      );
      final DailyRings today = closed.rolledTo(DateTime(2026, 9, 21, 8));
      expect(today.create, isFalse);
      expect(today.publish, isFalse);
      expect(today.compete, isFalse);
      expect(today.streak, 5);
      expect(today.day, DailyRings.keyFor(DateTime(2026, 9, 21)));
    });

    test('a day left open breaks the streak', () {
      final DateTime yesterday = DateTime(2026, 9, 20);
      final DailyRings open = DailyRings(
        day: DailyRings.keyFor(yesterday),
        create: true,
        publish: true,
        streak: 4,
      );
      final DailyRings today = open.rolledTo(DateTime(2026, 9, 21, 8));
      expect(today.streak, 0);
    });

    test('a gap of more than a day breaks the streak even if that day closed',
        () {
      final DateTime twoDaysAgo = DateTime(2026, 9, 19);
      final DailyRings closed = DailyRings(
        day: DailyRings.keyFor(twoDaysAgo),
        create: true,
        publish: true,
        compete: true,
        streak: 4,
      );
      // The app was never opened on the 20th, so nothing says that day
      // closed too — a gap this size cannot assume it did.
      final DailyRings today = closed.rolledTo(DateTime(2026, 9, 21, 8));
      expect(today.streak, 0);
    });

    test('rolling forward more than once lands on the same place as once',
        () {
      final DateTime day1 = DateTime(2026, 9, 20);
      final DailyRings closed = DailyRings(
        day: DailyRings.keyFor(day1),
        create: true,
        publish: true,
        compete: true,
        streak: 1,
      );
      final DateTime day3 = DateTime(2026, 9, 22, 8);
      final DailyRings direct = closed.rolledTo(day3);
      final DailyRings stepped =
          closed.rolledTo(DateTime(2026, 9, 21, 8)).rolledTo(day3);
      expect(direct.day, stepped.day);
      // Read only once, three days later, there is no way to tell the 21st
      // ever closed, so the streak resets exactly as the stepped path does.
      expect(direct.streak, 0);
      expect(stepped.streak, 0);
    });
  });

  group('closing a ring', () {
    test('closes exactly the one asked for', () {
      const DailyRings blank = DailyRings(day: '2026-09-21');
      final DailyRings afterCreate = blank.close(RingKind.create);
      expect(afterCreate.create, isTrue);
      expect(afterCreate.publish, isFalse);
      expect(afterCreate.compete, isFalse);
      expect(afterCreate.closedCount, 1);
      expect(afterCreate.allClosed, isFalse);
    });

    test('closing an already-closed ring is a no-op', () {
      const DailyRings blank = DailyRings(day: '2026-09-21', create: true);
      expect(blank.close(RingKind.create).create, isTrue);
    });

    test('closing all three is allClosed', () {
      const DailyRings blank = DailyRings(day: '2026-09-21');
      final DailyRings full = blank
          .close(RingKind.create)
          .close(RingKind.publish)
          .close(RingKind.compete);
      expect(full.allClosed, isTrue);
      expect(full.closedCount, 3);
    });
  });

  group('persistence', () {
    test('round-trips through json', () {
      const DailyRings rings = DailyRings(
        day: '2026-09-21',
        create: true,
        publish: false,
        compete: true,
        streak: 7,
      );
      final DailyRings back =
          DailyRings.fromJson(rings.toJson(), DateTime(2026, 9, 21));
      expect(back.day, rings.day);
      expect(back.create, rings.create);
      expect(back.publish, rings.publish);
      expect(back.compete, rings.compete);
      expect(back.streak, rings.streak);
    });

    test('missing or null blob starts fresh on today', () {
      final DateTime now = DateTime(2026, 9, 21, 9);
      final DailyRings rings = DailyRings.fromJson(null, now);
      expect(rings.day, DailyRings.keyFor(now));
      expect(rings.allClosed, isFalse);
      expect(rings.streak, 0);
    });
  });
}
