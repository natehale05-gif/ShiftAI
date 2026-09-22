import 'dart:math';

/// The line the Suite opens on when the thread is empty.
///
/// One fixed sentence read as a static label after the second or third
/// time — part of the furniture rather than an invitation. These rotate:
/// a new one every time a thread is cleared, and again whenever the app is
/// opened or comes back from the background, so the screen someone lands
/// on is not the one they left.
///
/// Short, plainly asked, and none of them cute — this is the first thing
/// on the screen every day, and a joke stops being one by the fourth
/// reading.
abstract final class Greetings {
  const Greetings._();

  static const List<String> all = <String>[
    'What are we making today?',
    'What are we working on?',
    'What is the idea?',
    'Where do you want to start?',
    'What should we build?',
    'What is on your mind?',
    'Ready when you are.',
    'Start anywhere.',
    'What are we shipping today?',
    'Got something in mind?',
    'What do you need made?',
    'Something new today?',
    'What are we finishing?',
    'Say the word.',
  ];

  /// A line to open on, never the one already showing.
  ///
  /// Repeating is what makes a rotation look broken — twice in a row and
  /// it reads as though nothing changed — so [avoid] is taken out of the
  /// draw rather than re-rolled until it misses, which would otherwise be
  /// unbounded on a short list.
  static String next({String? avoid, Random? random}) {
    final List<String> pool =
        all.where((String line) => line != avoid).toList(growable: false);
    if (pool.isEmpty) return all.first;
    return pool[(random ?? _random).nextInt(pool.length)];
  }

  static final Random _random = Random();
}
