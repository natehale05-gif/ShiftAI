import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/data/api/decode.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

const Creator _other = Creator(
  handle: 'rae',
  name: 'Rae Okonkwo',
  email: 'rae@example.com',
  initials: 'RO',
);

/// An engine that is configured but unreachable — the case that used to
/// hand the seeded catalogue to whoever was holding the phone.
class _DeadRepository implements ShiftRepository {
  @override
  Future<ShiftSnapshot> load() async => throw const ShiftApiException(
        ShiftApiErrorKind.offline,
        'Could not reach the server.',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _StubAuth implements AuthService {
  _StubAuth(this.creator);
  final Creator creator;
  int refreshes = 0;
  bool deleted = false;

  @override
  Future<Session> signIn({
    required String email,
    required String password,
  }) async {
    if (password != 'right') {
      throw const ShiftApiException(
        ShiftApiErrorKind.unauthorised,
        'That email and password do not match.',
        status: 401,
      );
    }
    return Session(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      creator: creator,
    );
  }

  @override
  Future<Session> refresh(String refreshToken) async {
    refreshes++;
    throw const ShiftApiException(
      ShiftApiErrorKind.unauthorised,
      'That session has expired.',
      status: 401,
    );
  }

  @override
  Future<void> signOut(String refreshToken) async {}

  @override
  Future<void> deleteAccount() async => deleted = true;
}

Session _liveSession(Creator who) => Session(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      creator: who,
    );

Future<AppState> _server({
  ShiftRepository? repo,
  AuthService? auth,
  TokenStore? store,
  bool signedIn = false,
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'shift-backend': 'https://api.example.com',
    ...prefs,
  });
  final TokenStore tokens = store ?? MemoryTokenStore();
  // A session already in the keychain is what a returning person has, and
  // it is the state in which a failed load could leak somebody else's
  // catalogue onto the screen.
  if (signedIn) await tokens.write(_liveSession(_other));
  final AuthController controller = AuthController(
    service: auth ?? _StubAuth(_other),
    store: tokens,
  );
  await controller.restore();
  return AppState.load(
    engine: Backend(
      repository: repo ?? SeedRepository(replyDelay: Duration.zero),
      auth: controller,
      seeded: false,
    ),
  );
}

void main() {
  group('the seeded catalogue never stands in for an account', () {
    test('an unreachable engine leaves the screens empty, not seeded',
        () async {
      final AppState state =
          await _server(repo: _DeadRepository(), signedIn: true);

      expect(state.vault, isEmpty);
      expect(state.trophies, isEmpty);
      expect(state.standings, isEmpty);
      expect(state.notes, isEmpty);
      expect(state.designs, isEmpty);
      expect(state.lastError, isNotNull);
      // The tell: none of the seeded rows made it through.
      expect(
        state.vault.any((VaultItem v) => v.id == Seed.vault.first.id),
        isFalse,
      );
    });

    test('with no engine configured the catalogue is still the demo', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppState state =
          await AppState.load(tokenStore: MemoryTokenStore());
      expect(state.seededDemo, isTrue);
      expect(state.vault, isNotEmpty);
    });

    test("one account's cache is not read back for another", () async {
      // A blob left behind by a previous sign-in on this device.
      final AppState state = await _server(
        signedIn: true,
        prefs: <String, Object>{
          'shift.app.v1': '{"v":2,"account":"someone-else@example.com","vault":'
              '[{"id":"leaked","title":"Their private clip",'
              '"kind":"video","prompt":"","model":"","createdAt":'
              '"2026-01-01T00:00:00Z","credits":0,"aspect":1}]}',
        },
      );

      expect(
        state.vault.any((VaultItem v) => v.id == 'leaked'),
        isFalse,
        reason: 'a cache belonging to another account was read back',
      );
    });

    test('signing out empties the screens and the cache', () async {
      final AppState state = await _server(signedIn: true);
      expect(state.vault, isNotEmpty);

      await state.signOut();

      expect(state.signedIn, isFalse);
      expect(state.vault, isEmpty);
      expect(state.notes, isEmpty);
      expect(state.standings, isEmpty);
      expect(state.messages, isEmpty);
    });
  });

  group('the trophy shelf is the engine\'s, not the catalogue\'s', () {
    test('a server that says nothing leaves every trophy unearned', () {
      final List<Trophy> shelf = Decode.trophies(<dynamic>[]);

      expect(shelf, isNotEmpty, reason: 'the artwork is still the client\'s');
      expect(shelf.every((Trophy t) => !t.earned), isTrue);
      expect(shelf.every((Trophy t) => t.progress == 0), isTrue);
      expect(shelf.every((Trophy t) => t.memberPercent == 0), isTrue);
      // The seed has four earned; none of them may survive the decode.
      expect(Seed.trophies.where((Trophy t) => t.earned), isNotEmpty);
    });

    test('the target in a progress label is kept, the count is not', () {
      final Trophy prolific =
          Seed.trophies.firstWhere((Trophy t) => t.id == 'prolific');
      expect(prolific.progressLabel, '8 OF 10');
      expect(prolific.unearned().progressLabel, '0 OF 10');
    });

    test("what the server does say is what shows", () {
      final List<Trophy> shelf = Decode.trophies(<dynamic>[
        <String, dynamic>{
          'id': 'first_light',
          'earnedOn': '2026-09-01T00:00:00Z',
          'progress': 1.0,
          'progressLabel': '1 OF 1',
          'memberPercent': 91,
        },
      ]);

      final Trophy first =
          shelf.firstWhere((Trophy t) => t.id == 'first_light');
      expect(first.earned, isTrue);
      expect(first.memberPercent, 91);
      // And only that one.
      expect(shelf.where((Trophy t) => t.earned).length, 1);
    });
  });

  group('the board survives having no rows', () {
    test('no row for you means no rank rather than a stranger\'s', () async {
      final AppState state =
          await _server(repo: _DeadRepository(), signedIn: true);
      // This used to be standings.last, which threw here.
      expect(state.you, isNull);
      expect(state.target, isNull);
      expect(state.chaser, isNull);
      expect(state.podium, isEmpty);
      expect(state.rest, isEmpty);
    });
  });

  group('auth', () {
    test('a wrong password is reported, not swallowed', () async {
      final AppState state = await _server();
      final String? refused = await state.signIn('rae@example.com', 'wrong');
      expect(refused, 'That email and password do not match.');
      expect(state.signedIn, isFalse);
      expect(state.signingIn, isFalse);
    });

    test('a good password signs in and pulls that account', () async {
      final AppState state = await _server();
      expect(await state.signIn('rae@example.com', 'right'), isNull);
      expect(state.signedIn, isTrue);
      expect(state.creator.email, 'rae@example.com');
    });

    test('the session is kept in the token store, not the blob', () async {
      final MemoryTokenStore store = MemoryTokenStore();
      final AppState state = await _server(store: store);
      await state.signIn('rae@example.com', 'right');

      expect((await store.read())!.refreshToken, 'refresh-1');
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String blob = prefs.getString('shift.app.v1') ?? '';
      expect(blob.contains('refresh-1'), isFalse);
      expect(blob.contains('access-1'), isFalse);
    });

    test('a refresh the server refuses signs you out once, not in a loop',
        () async {
      final _StubAuth auth = _StubAuth(_other);
      final AuthController controller = AuthController(
        service: auth,
        store: MemoryTokenStore(),
      );
      await controller.signIn(email: 'rae@example.com', password: 'right');

      // Two callers hit 401 at the same time: one refresh between them.
      final List<String?> answers = await Future.wait<String?>(
        <Future<String?>>[controller.recover(), controller.recover()],
      );

      expect(answers, <String?>[null, null]);
      expect(auth.refreshes, 1);
      expect(controller.signedIn, isFalse);
    });

    test('deleting the account signs out and clears the store', () async {
      final _StubAuth auth = _StubAuth(_other);
      final MemoryTokenStore store = MemoryTokenStore();
      final AppState state = await _server(auth: auth, store: store);
      await state.signIn('rae@example.com', 'right');

      expect(await state.deleteAccount(), isNull);
      expect(auth.deleted, isTrue);
      expect(state.signedIn, isFalse);
      expect(await store.read(), isNull);
      expect(state.vault, isEmpty);
    });
  });
}
