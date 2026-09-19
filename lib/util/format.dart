/// Small formatters. The app carries no locale package: every figure in the
/// product is a dollar amount or a plain count.
abstract final class Fmt {
  static String money(double value) {
    final negative = value < 0;
    final cents = (value.abs() * 100).round();
    final whole = cents ~/ 100;
    final fraction = (cents % 100).toString().padLeft(2, '0');
    return '${negative ? '-' : ''}\$${grouped(whole)}.$fraction';
  }

  static String grouped(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String date(DateTime when) =>
      '${when.day} ${_months[when.month - 1]} ${when.year}';

  static String dateTime(DateTime when) {
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    return '${date(when)}, $hh:$mm';
  }

  static String seconds(int? value) => value == null ? '' : '${value}s';

  /// "04d 11:38:06" — the shape the board locks down to.
  static String countdown(Duration left) {
    if (left.isNegative) return 'LOCKED';
    final String days = left.inDays.toString().padLeft(2, '0');
    final String hours = (left.inHours % 24).toString().padLeft(2, '0');
    final String minutes = (left.inMinutes % 60).toString().padLeft(2, '0');
    final String seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '${days}d $hours:$minutes:$seconds';
  }
}
