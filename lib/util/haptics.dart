import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The small physical answers a native app gives a finger: a tick as a
/// switch or a segment changes, a tap when something is saved, a firmer
/// one when a daily ring closes.
///
/// The web has no haptics, and the unit tests have no platform binding,
/// so every call is a no-op there. A haptic that cannot fire must never
/// take the action down with it.
abstract final class Haptics {
  /// A switch, a segment, a swatch, a filter: a choice changed.
  static void selection() => _fire(HapticFeedback.selectionClick);

  /// Something was made or saved: a heart, a sent message.
  static void light() => _fire(HapticFeedback.lightImpact);

  /// Something finished: a daily ring closing.
  static void success() => _fire(HapticFeedback.mediumImpact);

  static void _fire(Future<void> Function() haptic) {
    if (kIsWeb) return;
    try {
      haptic().ignore();
    } on Object {
      // No binding (a plain unit test) or no engine behind it.
    }
  }
}
