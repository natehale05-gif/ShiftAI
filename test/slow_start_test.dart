import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

/// An engine that answers when the test says so.
class _SlowEngine extends SeedRepository {
  final Completer<ShiftSnapshot> answer = Completer<ShiftSnapshot>();

  @override
  Future<ShiftSnapshot> load() => answer.future;
}

class _StubAuth implements AuthService {
  @override
  Future<void> signOut(String refreshToken) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

final Note _cachedNote = Note(
  id: 'n-cached',
  title: 'Last seen',
  body: 'From the device',
  editedAt: DateTime.utc(2026, 9, 23),
);

/// A device that has seen this account before: its blob, keyed to it.
Map<String, Object> _deviceOf(String account) => <String, Object>{
      'shift-backend': 'https://api.example.com',
      StoreKeys.app: jsonEncode(<String, Object>{
        'v': 2,
        'account': account,
        'notes': <Object>[_cachedNote.toJson()],
        'threads': <Object>[
          ChatThread(
            id: 'chat-1',
            title: 'A saved chat',
            updatedAt: DateTime.utc(2026, 9, 24),
            messages: const <ChatMessage>[
              ChatMessage(id: 'u', author: MessageAuthor.you, body: 'Hi'),
            ],
          ).toJson(),
        ],
      }),
    };

Future<(AppState, _SlowEngine)> _open(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final TokenStore tokens = MemoryTokenStore();
  await tokens.write(Session(
    accessToken: 'a',
    refreshToken: 'r',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    creator: Seed.creator,
  ));
  final AuthController auth =
      AuthController(service: _StubAuth(), store: tokens);
  await auth.restore();
  final _SlowEngine engine = _SlowEngine();
  final AppState state = await AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
    firstScreenBudget: const Duration(milliseconds: 50),
  );
  return (state, engine);
}

Future<ShiftSnapshot> _serverSnapshot() async {
  final ShiftSnapshot s = await SeedRepository().load();
  return ShiftSnapshot(
    creator: Seed.creator,
    standings: s.standings,
    trophies: s.trophies,
    vault: s.vault,
    ecoVault: s.ecoVault,
    notes: <Note>[
      Note(
        id: 'n-server',
        title: 'From the server',
        body: '',
        editedAt: DateTime.utc(2026, 9, 24),
      ),
    ],
    agentRuns: s.agentRuns,
    jobs: s.jobs,
    designs: s.designs,
    connectors: s.connectors,
    weekPool: s.weekPool,
    payoutLine: s.payoutLine,
    avatars: const <Avatar>[],
  );
}

void main() {
  test(
      'a slow engine does not hold the first screen: it opens on the '
      'last-seen copy and fills in when the answer lands', () async {
    final (AppState state, _SlowEngine engine) =
        await _open(_deviceOf(Seed.creator.email));

    // Open, within the budget, on this account's copy from the device.
    expect(state.refreshing, isTrue);
    expect(state.showingCached, isTrue);
    expect(state.notes.single.title, 'Last seen');
    expect(state.threads.single.title, 'A saved chat');
    expect(state.lastError, isNull);

    engine.answer.complete(await _serverSnapshot());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(state.refreshing, isFalse);
    expect(state.showingCached, isFalse);
    expect(state.notes.single.title, 'From the server');
    // Saved chats merge; they are not wiped by the server's answer.
    expect(state.threads.single.title, 'A saved chat');
  });

  test('a load that fails late keeps the copy and says why', () async {
    final (AppState state, _SlowEngine engine) =
        await _open(_deviceOf(Seed.creator.email));
    engine.answer.completeError(
      const ShiftApiException(ShiftApiErrorKind.timeout, 'Too slow.'),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(state.refreshing, isFalse);
    expect(state.lastError?.message, 'Too slow.');
    expect(state.notes.single.title, 'Last seen');
  });

  test('signing out while it loads: the late answer is not put back', () async {
    final (AppState state, _SlowEngine engine) =
        await _open(_deviceOf(Seed.creator.email));
    await state.signOut();
    engine.answer.complete(await _serverSnapshot());
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(state.notes, isEmpty);
    expect(state.threads, isEmpty);
  });

  test('another account\'s device copy, chats included, is never shown',
      () async {
    final (AppState state, _) = await _open(_deviceOf('someone@else.com'));
    expect(state.notes, isEmpty);
    expect(state.threads, isEmpty,
        reason: 'Recents are the account\'s, like the vault');
    expect(state.showingCached, isFalse);
  });
}
