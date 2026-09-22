import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/state/greetings.dart';

class _StubAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// An engine configured with a session already in the keychain — the one
/// case chat actually sends in.
Future<AppState> _signedInState() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'shift-backend': 'https://api.example.com',
  });
  final TokenStore tokens = MemoryTokenStore();
  await tokens.write(Session(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    creator: Seed.creator,
  ));
  final AuthController auth =
      AuthController(service: _StubAuth(), store: tokens);
  await auth.restore();
  return AppState.load(
    engine: Backend(
      repository: SeedRepository(replyDelay: Duration.zero),
      auth: auth,
      seeded: false,
    ),
  );
}

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
    // Signed in, because chat refuses to send on the seeded demo — and a
    // thread that never got its message would leave this testing the
    // empty case twice over.
    final AppState state = await _signedInState();
    final String before = state.greeting;

    // Nothing is drawn over a thread that has messages in it, so swapping
    // the line there would only be a surprise waiting for whenever that
    // thread is next cleared.
    expect(state.sendMessage('Cut a 20 second vertical promo'), isTrue);
    expect(state.messages, isNotEmpty);
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
