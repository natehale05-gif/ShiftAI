import 'dart:convert';

import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/data/api/api_client.dart';
import 'package:shift_ai/data/api/http_repository.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

/// Answers every message, and records what it was asked to keep.
class _Engine extends SeedRepository {
  _Engine({this.serverThreads});

  final List<ChatThread>? serverThreads;
  final List<ChatThread> saved = <ChatThread>[];
  final List<String> deleted = <String>[];
  int replies = 0;

  @override
  Future<ShiftSnapshot> load() async {
    final ShiftSnapshot s = await super.load();
    return ShiftSnapshot(
      creator: s.creator,
      standings: s.standings,
      trophies: s.trophies,
      vault: s.vault,
      ecoVault: s.ecoVault,
      notes: s.notes,
      agentRuns: s.agentRuns,
      jobs: s.jobs,
      designs: s.designs,
      connectors: s.connectors,
      weekPool: s.weekPool,
      payoutLine: s.payoutLine,
      avatars: s.avatars,
      threads: serverThreads,
    );
  }

  @override
  Future<List<ChatMessage>> send(
    String prompt, {
    bool private = false,
    String? avatarId,
    String? model,
    List<ChatTurn> history = const <ChatTurn>[],
    Future<void>? cancel,
  }) async {
    replies++;
    return <ChatMessage>[
      ChatMessage(
          id: 'r$replies', author: MessageAuthor.shift, body: 'Reply $replies'),
    ];
  }

  @override
  Future<void> saveThread(ChatThread thread) async => saved.add(thread);

  @override
  Future<void> deleteThread(String id) async => deleted.add(id);
}

class _StubAuth implements AuthService {
  @override
  Future<void> signOut(String refreshToken) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<(AppState, _Engine)> _signedIn({
  Map<String, Object> prefs = const <String, Object>{},
  List<ChatThread>? serverThreads,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'shift-backend': 'https://api.example.com',
    ...prefs,
  });
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
  final _Engine engine = _Engine(serverThreads: serverThreads);
  final AppState state = await AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
  );
  return (state, engine);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

Future<String> _blob(AppState state) async {
  await state.flush();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getString(StoreKeys.app)!;
}

class _Client extends http.BaseClient {
  _Client(this.route);
  final http.Response Function(http.Request) route;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final http.Response r = route(request as http.Request);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(r.body)),
      r.statusCode,
      request: request,
    );
  }
}

void main() {
  test(
      'a chat is saved as it happens, survives a restart, and opens again '
      'where it left off', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    state.sendMessage('Plan a shoot at the ferry terminal');
    await _settle();
    state.sendMessage('Make it shorter');
    await _settle();

    expect(state.threads, hasLength(1));
    final ChatThread saved = state.threads.single;
    expect(saved.title, 'Plan a shoot at the ferry terminal');
    expect(saved.messages.map((ChatMessage m) => m.body), <String>[
      'Plan a shoot at the ferry terminal',
      'Reply 1',
      'Make it shorter',
      'Reply 2',
    ]);
    // And on the server, whose last copy is the whole of it.
    expect(engine.saved.last.messages, hasLength(4));

    // A restart: a new app on the same device, same account.
    final String blob = await _blob(state);
    final (AppState again, _) =
        await _signedIn(prefs: <String, Object>{StoreKeys.app: blob});
    expect(again.messages, isEmpty, reason: 'it opens on a new chat');
    expect(again.threads.single.title, 'Plan a shoot at the ferry terminal');

    again.openThread(again.threads.single.id);
    expect(again.messages, hasLength(4));
    expect(again.currentThreadId, saved.id);
    // Carrying on adds to the same saved chat, not a new one.
    again.sendMessage('And a caption');
    await _settle();
    expect(again.threads, hasLength(1));
    expect(again.threads.single.messages, hasLength(6));
  });

  test('New chat keeps the last one; Recents are newest first', () async {
    final (AppState state, _) = await _signedIn();
    state.sendMessage('First chat');
    await _settle();
    state.clearThread();
    expect(state.currentThreadId, isNull);
    state.sendMessage('Second chat');
    await _settle();
    expect(state.threads.map((ChatThread t) => t.title),
        <String>['Second chat', 'First chat']);
  });

  test('a private chat is saved nowhere, and going private starts afresh',
      () async {
    final (AppState state, _Engine engine) = await _signedIn();
    state.sendMessage('A saved chat');
    await _settle();
    final String savedId = state.currentThreadId!;

    state.togglePrivateChat();
    expect(state.messages, isEmpty, reason: 'not carried into private');
    state.sendMessage('something private');
    await _settle();
    state.togglePrivateChat();
    state.sendMessage('Back in the open');
    await _settle();

    expect(
      state.threads.expand((ChatThread t) => t.messages).map((m) => m.body),
      isNot(contains('something private')),
    );
    expect(engine.saved.expand((ChatThread t) => t.messages).map((m) => m.body),
        isNot(contains('something private')));
    expect(await _blob(state), isNot(contains('something private')));
    // The saved chat from before is untouched.
    expect(
      state.threads.firstWhere((ChatThread t) => t.id == savedId).messages,
      hasLength(2),
    );
  });

  test('failure notices are not kept in a saved chat', () async {
    final (AppState state, _) = await _signedIn();
    state.sendMessage('Make an image of a lighthouse');
    await _settle();
    state.sendMessage('Write a caption for it');
    await _settle();
    // With no image model, the first ask got the app's notice, which is
    // not part of the conversation.
    final List<ChatMessage> kept = state.threads.single.messages;
    expect(kept.any((ChatMessage m) => m.failure != null), isFalse);
  });

  test('deleting one removes it here and on the server', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    state.sendMessage('Delete me');
    await _settle();
    final String id = state.threads.single.id;
    state.deleteThread(id);
    await _settle();
    expect(state.threads, isEmpty);
    expect(state.messages, isEmpty, reason: 'it was the one on screen');
    expect(engine.deleted, <String>[id]);
  });

  test('signing out takes the account\'s chats with it', () async {
    final (AppState state, _) = await _signedIn();
    state.sendMessage('Mine');
    await _settle();
    await state.signOut();
    expect(state.threads, isEmpty);
    expect(await _blob(state), isNot(contains('Mine')));
  });

  test('the server\'s chats load, merged with the device\'s by newest',
      () async {
    final ChatThread onServer = ChatThread(
      id: 'chat-1',
      title: 'From the laptop',
      updatedAt: DateTime.utc(2026, 9, 24, 9),
      messages: const <ChatMessage>[
        ChatMessage(
            id: 'u', author: MessageAuthor.you, body: 'From the laptop'),
      ],
    );
    final (AppState state, _) =
        await _signedIn(serverThreads: <ChatThread>[onServer]);
    expect(state.threads.single.title, 'From the laptop');
  });

  group('over HTTP', () {
    test('GET, PUT and DELETE /v1/threads, and an engine without them',
        () async {
      final List<String> seen = <String>[];
      final HttpRepository repo = HttpRepository(ApiClient(
        baseUrl: 'https://api.example.com',
        client: _Client((http.Request r) {
          seen.add('${r.method} ${r.url.path}');
          if (r.url.path.startsWith('/v1/threads/')) {
            return http.Response('{}', 200);
          }
          return http.Response('{"message":"no route"}', 404);
        }),
      ));
      final ChatThread t = ChatThread(
        id: 'chat-9',
        title: 'Hi',
        updatedAt: DateTime.utc(2026, 9, 24),
        messages: const <ChatMessage>[
          ChatMessage(id: 'u', author: MessageAuthor.you, body: 'Hi'),
        ],
      );
      await repo.saveThread(t);
      await repo.deleteThread('chat-9');
      expect(seen,
          <String>['PUT /v1/threads/chat-9', 'DELETE /v1/threads/chat-9']);

      // No /v1/threads at all: nothing thrown, the device's copy stands.
      final HttpRepository none = HttpRepository(ApiClient(
        baseUrl: 'https://api.example.com',
        client: _Client((_) => http.Response('{"message":"no route"}', 404)),
      ));
      await none.saveThread(t);
      await none.deleteThread('chat-9');
    });

    test('a thread goes and comes back whole, attachment and all', () {
      final ChatThread t = ChatThread(
        id: 'chat-2',
        title: 'Promo',
        updatedAt: DateTime.utc(2026, 9, 24, 10),
        messages: const <ChatMessage>[
          ChatMessage(id: 'u', author: MessageAuthor.you, body: 'A promo'),
          ChatMessage(
            id: 'r',
            author: MessageAuthor.shift,
            body: 'Here it is',
            model: 'veo',
            modelName: 'Veo 3',
            attachment: MessageAttachment(
              fileName: 'promo.mp4',
              meta: '20S',
              kind: MediaKind.video,
              vaultItemId: 'v1',
            ),
          ),
        ],
      );
      final ChatThread back =
          ChatThread.tryParse(jsonDecode(jsonEncode(t.toJson())))!;
      expect(back.id, 'chat-2');
      expect(back.updatedAt, t.updatedAt);
      expect(back.messages.last.modelName, 'Veo 3');
      expect(back.messages.last.attachment?.fileName, 'promo.mp4');
      expect(back.messages.last.attachment?.kind, MediaKind.video);
    });
  });

  test('a title is the first ask, on one line, cut short', () {
    expect(
      ChatThread.titleFor(<ChatMessage>[
        ChatMessage(
          id: 'u',
          author: MessageAuthor.you,
          body: '${'word ' * 20}\nsecond line',
        ),
      ]).length,
      lessThanOrEqualTo(60),
    );
    expect(ChatThread.titleFor(const <ChatMessage>[]), 'New chat');
  });

  testWidgets('Recents in the drawer lists saved chats and opens one',
      (WidgetTester tester) async {
    // A phone's height: the drawer builds rows as they scroll into view.
    tester.view.physicalSize = const Size(412 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final (AppState state, _) = await _signedIn();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pumpAndSettle();
    final Finder close = find.byTooltip('Close');
    if (close.evaluate().isNotEmpty) {
      await tester.tap(close.first);
      await tester.pumpAndSettle();
    }

    state.sendMessage('Plan the ferry shoot');
    await tester.pumpAndSettle();
    state.clearThread();
    await tester.pumpAndSettle();
    expect(state.messages, isEmpty);

    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Recents'), findsOneWidget);
    await tester.tap(find.text('Plan the ferry shoot'));
    await tester.pumpAndSettle();

    expect(state.messages.map((ChatMessage m) => m.body),
        <String>['Plan the ferry shoot', 'Reply 1']);
    expect(tester.takeException(), isNull);
  });
}
