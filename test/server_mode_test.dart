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
import 'package:shift_ai/features/settings/connectors.dart';
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

/// A repository whose only interesting behaviour is what changing the
/// handle does — everything else is the empty snapshot.
class _HandleRepo implements ShiftRepository {
  _HandleRepo({this.fail = false});

  final bool fail;

  @override
  Future<ShiftSnapshot> load() async => emptySnapshot();

  @override
  Future<Creator> updateHandle(String handle) async {
    if (fail) {
      throw const ShiftApiException(
        ShiftApiErrorKind.badRequest,
        'That username is taken.',
      );
    }
    return _other.copyWith(handle: handle);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A repository whose avatar writes always refuse, to exercise rollback.
class _RefusingAvatarRepo implements ShiftRepository {
  @override
  Future<ShiftSnapshot> load() async => ShiftSnapshot(
        creator: Seed.creator,
        standings: <StandingRow>[],
        trophies: <Trophy>[],
        vault: <VaultItem>[],
        ecoVault: <VaultItem>[],
        notes: <Note>[],
        agentRuns: <AgentRun>[],
        jobs: <JobRow>[],
        designs: <DesignDoc>[],
        connectors: <Connector>[],
        weekPool: 0,
        payoutLine: '',
        avatars: List<Avatar>.of(Seed.avatars),
      );

  static Never _refuse() => throw const ShiftApiException(
        ShiftApiErrorKind.badRequest,
        'Refused.',
      );

  @override
  Future<Avatar> createAvatar({
    required String uploadId,
    required String name,
  }) async =>
      _refuse();

  @override
  Future<Avatar> makeAvatarPersonal(String id) async => _refuse();

  @override
  Future<void> deleteAvatar(String id) async => _refuse();

  @override
  Future<League?> shareLocation({
    required double lat,
    required double lng,
  }) async =>
      _refuse();

  @override
  Future<String> upload({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async =>
      'u1';

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

    test('offline, your own last-seen copy comes back, and says so',
        () async {
      // The session on this device is Rae's, and so is the blob. The
      // engine cannot be reached: the screens are Rae's last-seen copy,
      // marked as such, not empty and never seeded.
      final AppState state = await _server(
        repo: _DeadRepository(),
        signedIn: true,
        prefs: <String, Object>{
          'shift.app.v1': '{"v":2,"account":"rae@example.com","vault":'
              '[{"id":"mine-cached","title":"Rae\'s own clip",'
              '"kind":"video","prompt":"","model":"","createdAt":'
              '"2026-01-01T00:00:00Z","credits":0,"aspect":1}]}',
        },
      );

      expect(state.lastError, isNotNull);
      expect(state.showingCached, isTrue);
      expect(state.vault.single.id, 'mine-cached');
      expect(
        state.vault.any((VaultItem v) => v.id == Seed.vault.first.id),
        isFalse,
      );
    });

    test('offline, a copy belonging to someone else still gets nothing',
        () async {
      final AppState state = await _server(
        repo: _DeadRepository(),
        signedIn: true,
        prefs: <String, Object>{
          'shift.app.v1': '{"v":2,"account":"someone-else@example.com",'
              '"vault":[{"id":"leaked","title":"Their private clip",'
              '"kind":"video","prompt":"","model":"","createdAt":'
              '"2026-01-01T00:00:00Z","credits":0,"aspect":1}]}',
        },
      );
      expect(state.showingCached, isFalse);
      expect(state.vault, isEmpty);
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
      expect(prolific.progressLabel, '8 of 10');
      expect(prolific.unearned().progressLabel, '0 of 10');
    });

    test('a label sent shouted is still understood, and written calmly', () {
      // The contract asks for sentence case, but an engine that sends
      // "8 OF 10" must not lose its target on the way to a new account's
      // shelf — nor bring the capitals with it.
      final Trophy prolific =
          Seed.trophies.firstWhere((Trophy t) => t.id == 'prolific');
      final Trophy shouted = prolific.copyWith(progressLabel: '8 OF 10');
      expect(shouted.unearned().progressLabel, '0 of 10');
    });

    test("what the server does say is what shows", () {
      final List<Trophy> shelf = Decode.trophies(<dynamic>[
        <String, dynamic>{
          'id': 'first_light',
          'earnedOn': '2026-09-01T00:00:00Z',
          'progress': 1.0,
          'progressLabel': '1 of 1',
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

  group('changing the username', () {
    test('a refusal rolls it back', () async {
      final AppState state =
          await _server(repo: _HandleRepo(fail: true), signedIn: true);
      final String before = state.creator.handle;

      expect(await state.updateHandle('taken'), isFalse);
      expect(state.creator.handle, before);
      expect(state.lastError?.message, 'That username is taken.');
    });

    test('success is kept in the session, not just on screen', () async {
      final MemoryTokenStore store = MemoryTokenStore();
      final AppState state = await _server(
        repo: _HandleRepo(),
        store: store,
        signedIn: true,
      );

      expect(await state.updateHandle(' newhandle '), isTrue);
      expect(state.creator.handle, 'newhandle');
      // The keychain-backed session carries it, so a restart still shows
      // it — not just the screen that made the change.
      expect((await store.read())!.creator.handle, 'newhandle');
    });

    test('an engine that sends the @ does not get it drawn twice', () {
      // Every screen writes its own '@' in front of the handle, so one
      // arriving in the value is what made the account card read
      // "@@shiftai".
      const Creator withAt = Creator(
        handle: '@shiftai',
        name: 'ShiftAi',
        email: 'demo@shiftai.club',
        initials: 'SA',
      );
      const Creator without = Creator(
        handle: 'shiftai',
        name: 'ShiftAi',
        email: 'demo@shiftai.club',
        initials: 'SA',
      );
      expect(withAt.bareHandle, 'shiftai');
      expect(without.bareHandle, 'shiftai');
    });
  });

  group('avatars', () {
    test('the personal avatar is the one flagged personal', () async {
      final AppState state =
          await _server(repo: SeedRepository(replyDelay: Duration.zero), signedIn: true);
      expect(state.personalAvatar?.id, 'av-1');
      expect(state.personalAvatar?.status, AvatarStatus.ready);
    });

    test('creating one waits for the engine\'s id, same as a note', () async {
      final AppState state =
          await _server(repo: SeedRepository(replyDelay: Duration.zero), signedIn: true);
      final int before = state.avatars.length;

      final Avatar? created =
          await state.createAvatar(<int>[1, 2, 3], name: 'New face');
      expect(created, isNotNull);
      expect(created!.status, AvatarStatus.training);
      expect(state.avatars.length, before + 1);
      expect(state.avatars.last.id, created.id);
    });

    test('a refused creation reports why and adds nothing', () async {
      final AppState state = await _server(repo: _RefusingAvatarRepo(), signedIn: true);
      final int before = state.avatars.length;

      final Avatar? created =
          await state.createAvatar(<int>[1, 2, 3], name: 'New face');
      expect(created, isNull);
      expect(state.avatars.length, before);
      expect(state.lastError?.message, 'Refused.');
    });

    test('making one personal demotes whichever one was', () async {
      final AppState state =
          await _server(repo: SeedRepository(replyDelay: Duration.zero), signedIn: true);
      final String wasPersonal = state.personalAvatar!.id;
      final Avatar toPromote =
          state.avatars.firstWhere((Avatar a) => a.id != wasPersonal);

      expect(await state.makeAvatarPersonal(toPromote.id), isTrue);
      expect(state.personalAvatar?.id, toPromote.id);
      expect(
        state.avatars.firstWhere((Avatar a) => a.id == wasPersonal).personal,
        isFalse,
      );
    });

    test('a refusal rolls the personal flag back', () async {
      final AppState state = await _server(repo: _RefusingAvatarRepo(), signedIn: true);
      final String before = state.personalAvatar!.id;
      final Avatar other =
          state.avatars.firstWhere((Avatar a) => a.id != before);

      expect(await state.makeAvatarPersonal(other.id), isFalse);
      expect(state.personalAvatar?.id, before);
      expect(state.lastError?.message, 'Refused.');
    });

    test('deleting one is optimistic and rolls back on refusal', () async {
      final AppState ok =
          await _server(repo: SeedRepository(replyDelay: Duration.zero), signedIn: true);
      final String id = ok.avatars.first.id;
      expect(await ok.deleteAvatar(id), isTrue);
      expect(ok.avatars.any((Avatar a) => a.id == id), isFalse);

      final AppState refused = await _server(repo: _RefusingAvatarRepo(), signedIn: true);
      final List<Avatar> before = refused.avatars;
      expect(await refused.deleteAvatar(before.first.id), isFalse);
      expect(refused.avatars.length, before.length);
    });
  });

  group('the local league', () {
    test('is null before anything has placed this account', () async {
      final AppState state = await _server(repo: _RefusingAvatarRepo(), signedIn: true);
      expect(state.league, isNull);
    });

    test('sharing a location applies whatever the engine places you in',
        () async {
      // The seeded demo shows the league already placed, same as every
      // other list in it — sharing a location here just re-asks and gets
      // the same answer back, which is what matters: the write reaches the
      // repository and applies its result rather than being a no-op.
      final AppState state =
          await _server(repo: SeedRepository(replyDelay: Duration.zero), signedIn: true);
      expect(state.league, isNotNull);

      expect(await state.shareLocation(30.2672, -97.7431), isTrue);
      expect(state.league, isNotNull);
      expect(state.league!.regionLabel, Seed.league.regionLabel);
      expect(state.league!.rows, Seed.league.rows);
      expect(state.lastError, isNull);
    });

    test('a refusal reports why and never invents a placement', () async {
      final AppState state = await _server(repo: _RefusingAvatarRepo(), signedIn: true);
      expect(await state.shareLocation(30.2672, -97.7431), isFalse);
      expect(state.league, isNull);
      expect(state.lastError?.message, 'Refused.');
    });
  });
}
