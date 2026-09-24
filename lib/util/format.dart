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

  /// How long ago, the way a feed says it: "Just now", "5 minutes ago",
  /// "3 hours ago", "2 days ago", then the date once it is over a week.
  static String ago(DateTime when, {DateTime? now}) {
    final Duration since = (now ?? DateTime.now()).difference(when);
    String unit(int n, String one) => '$n $one${n == 1 ? '' : 's'} ago';
    if (since.inMinutes < 1) return 'Just now';
    if (since.inHours < 1) return unit(since.inMinutes, 'minute');
    if (since.inDays < 1) return unit(since.inHours, 'hour');
    if (since.inDays < 7) return unit(since.inDays, 'day');
    return date(when);
  }

  /// "5d 09:36:49" — days unpadded, the clock padded, so it does not read
  /// like a register being dumped. Null once the week has closed, so the
  /// caller says so in its own words and drops its "Ends in" with it.
  static String? countdown(Duration left) {
    if (left.isNegative) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${left.inDays}d ${two(left.inHours % 24)}:'
        '${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
  }
}
