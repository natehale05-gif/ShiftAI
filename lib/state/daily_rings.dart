import 'package:flutter/foundation.dart';

/// The three things a productive day in SHIFT looks like: making
/// something, putting work in front of people, and checking where you
/// stand. Tracked entirely on device — there is no server concept of a
/// "day" to disagree with local midnight, so this never touches the
/// engine and never appears in `docs/API.md`.
enum RingKind { create, publish, compete }

@immutable
class DailyRings {
  const DailyRings({
    required this.day,
    this.create = false,
    this.publish = false,
    this.compete = false,
    this.streak = 0,
  });

  /// `yyyy-mm-dd`, device-local. Which day the three bools below describe.
  final String day;
  final bool create;
  final bool publish;
  final bool compete;

  /// Consecutive days, ending the day before [day], that closed all three.
  /// A day the app was never opened breaks it, the same as a missed workout
  /// breaks an activity streak.
  final int streak;

  int get closedCount =>
      (create ? 1 : 0) + (publish ? 1 : 0) + (compete ? 1 : 0);

  bool get allClosed => closedCount == 3;

  bool isClosed(RingKind kind) => switch (kind) {
        RingKind.create => create,
        RingKind.publish => publish,
        RingKind.compete => compete,
      };

  static String keyFor(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  /// What today looks like. Rolls the day over — and settles the streak —
  /// if [now] has moved past [day] since this was last read; otherwise
  /// returns this unchanged.
  DailyRings rolledTo(DateTime now) {
    final String today = keyFor(now);
    if (today == day) return this;
    final String yesterday = keyFor(now.subtract(const Duration(days: 1)));
    // Only a streak that was still running as of yesterday carries forward.
    // A gap of two days or more means at least one day in between was never
    // tracked, which reads the same as not having closed it.
    final int nextStreak = (day == yesterday && allClosed) ? streak + 1 : 0;
    return DailyRings(day: today, streak: nextStreak);
  }

  /// [kind] happened today. Closing an already-closed ring changes nothing.
  DailyRings close(RingKind kind) => DailyRings(
        day: day,
        create: create || kind == RingKind.create,
        publish: publish || kind == RingKind.publish,
        compete: compete || kind == RingKind.compete,
        streak: streak,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'day': day,
        'create': create,
        'publish': publish,
        'compete': compete,
        'streak': streak,
      };

  factory DailyRings.fromJson(Map<String, dynamic>? json, DateTime now) {
    if (json == null) return DailyRings(day: keyFor(now));
    return DailyRings(
      day: json['day'] as String? ?? keyFor(now),
      create: json['create'] as bool? ?? false,
      publish: json['publish'] as bool? ?? false,
      compete: json['compete'] as bool? ?? false,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
    );
  }
}
