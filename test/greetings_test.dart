import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/state/greetings.dart';

void main() {
  test('never hands back the line already showing', () {
    // Every line against many draws, not one sample: a rotation that
    // repeats only on an unlucky seed is exactly the bug worth catching,
    // and it is the one a single-draw test sails past.
    for (final String showing in Greetings.all) {
      for (int seed = 0; seed < 50; seed++) {
        expect(
          Greetings.next(avoid: showing, random: Random(seed)),
          isNot(showing),
        );
      }
    }
  });

  test('draws from the whole list, not a corner of it', () {
    final Set<String> seen = <String>{};
    for (int seed = 0; seed < 500; seed++) {
      seen.add(Greetings.next(random: Random(seed)));
    }
    expect(seen.length, Greetings.all.length);
  });

  test('a cleared thread opens on a different line', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppState state = await AppState.load(tokenStore: MemoryTokenStore());

    for (int i = 0; i < 25; i++) {
      final String before = state.greeting;
      state.clearThread();
      expect(state.greeting, isNot(before));
    }
  });

  test('coming back to a thread in progress leaves the line alone',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppState state = await AppState.load(tokenStore: MemoryTokenStore());
    final String before = state.greeting;

    // Nothing is drawn over a thread that has messages in it, so swapping
    // the line there would only be a surprise waiting for whenever that
    // thread is next cleared.
    state.sendMessage('Cut a 20 second vertical promo');
    state.freshenGreeting();
    expect(state.greeting, before);
  });

  test('coming back to an empty thread brings a new line', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppState state = await AppState.load(tokenStore: MemoryTokenStore());

    final String before = state.greeting;
    state.freshenGreeting();
    expect(state.greeting, isNot(before));
  });
}
