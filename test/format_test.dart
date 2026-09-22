import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/util/format.dart';

void main() {
  group('the week clock', () {
    test('days unpadded, the clock padded', () {
      expect(
        Fmt.countdown(const Duration(days: 5, hours: 9, minutes: 36, seconds: 9)),
        '5d 09:36:09',
      );
      expect(Fmt.countdown(const Duration(minutes: 1)), '0d 00:01:00');
    });

    test('a closed week has no countdown rather than a negative one', () {
      // The formatter written for the leaderboard printed "-1d" here.
      // The week locking is not a time left; it is a state, and the
      // screen says it in words.
      expect(Fmt.countdown(const Duration(seconds: -1)), isNull);
      expect(Fmt.countdown(const Duration(days: -2)), isNull);
    });
  });
}
