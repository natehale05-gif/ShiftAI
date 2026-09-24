import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/data/api/api_client.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

/// One call to [_Engine.send], held until the test answers it.
class _Call {
  _Call(this.prompt, this.model, this.history, this.cancel);

  final String prompt;
  final String? model;
  final List<ChatTurn> history;
  final Future<void>? cancel;
  final Completer<List<ChatMessage>> answer = Completer<List<ChatMessage>>();
  bool cancelled = false;

  void reply(String body, {String? model}) => answer.complete(<ChatMessage>[
        ChatMessage(
          id: 'r-$body',
          author: MessageAuthor.shift,
          body: body,
          model: model,
        ),
      ]);
}

/// An engine that answers when the test says so, and notices a Stop.
class _Engine extends SeedRepository {
  _Engine({this.models = const <ChatModel>[]});

  final List<ChatModel> models;
  final List<_Call> calls = <_Call>[];

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
      models: models,
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
    void Function(String soFar)? onText,
  }) {
    final _Call call = _Call(prompt, model, history, cancel);
    calls.add(call);
    cancel?.then((_) {
      call.cancelled = true;
      if (!call.answer.isCompleted) {
        call.answer.completeError(
          const ShiftApiException(ShiftApiErrorKind.offline, 'Aborted.'),
        );
      }
    });
    return call.answer.future;
  }

  @override
  Future<void> saveThread(ChatThread thread) async {}
}

class _StubAuth implements AuthService {
  @override
  Future<void> signOut(String refreshToken) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const ChatModel _claude =
    ChatModel(id: 'claude', name: 'Claude', isDefault: true);
const ChatModel _gpt = ChatModel(id: 'gpt', name: 'GPT');

Future<(AppState, _Engine)> _signedIn({
  List<ChatModel> models = const <ChatModel>[],
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'shift-backend': 'https://api.example.com',
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
  final _Engine engine = _Engine(models: models);
  final AppState state = await AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
  );
  return (state, engine);
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

List<String> _bodies(AppState state) =>
    state.messages.map((ChatMessage m) => m.body).toList();

void main() {
  group('Stop', () {
    test('cancels the request, keeps the question, and drops a late answer',
        () async {
      final (AppState state, _Engine engine) = await _signedIn();
      state.sendMessage('Write a long essay');
      await _settle();
      expect(state.thinking, isTrue);

      state.stopReply();
      await _settle();
      expect(engine.calls.single.cancelled, isTrue,
          reason: 'the request is aborted, not only ignored');
      expect(state.thinking, isFalse);
      expect(state.stopped, isTrue);
      expect(_bodies(state), <String>['Write a long essay']);
      expect(state.lastError, isNull, reason: 'a stop is not a failure');
    });

    test('Ask again after a stop sends the same question in place', () async {
      final (AppState state, _Engine engine) = await _signedIn();
      state.sendMessage('Write a long essay');
      await _settle();
      state.stopReply();
      await _settle();

      expect(state.regenerate(), isTrue);
      await _settle();
      expect(state.stopped, isFalse);
      expect(engine.calls.last.prompt, 'Write a long essay');
      expect(engine.calls.last.history, isEmpty);
      engine.calls.last.reply('Here it is');
      await _settle();
      expect(_bodies(state), <String>['Write a long essay', 'Here it is'],
          reason: 'the question is on screen once');
    });

    test('a new message replaces the one being waited for, and cancels it',
        () async {
      final (AppState state, _Engine engine) = await _signedIn();
      state.sendMessage('First');
      await _settle();
      state.sendMessage('Second');
      await _settle();
      expect(engine.calls.first.cancelled, isTrue);
      engine.calls.last.reply('Answer to second');
      await _settle();
      expect(_bodies(state), <String>['First', 'Second', 'Answer to second']);
    });

    test('signing out cancels it, and its answer never lands', () async {
      final (AppState state, _Engine engine) = await _signedIn();
      state.sendMessage('Write a long essay');
      await _settle();
      await state.signOut();
      await _settle();
      expect(engine.calls.single.cancelled, isTrue);
      expect(state.messages, isEmpty);
      expect(state.threads, isEmpty);
    });
  });

  test('a slow answer says it is still working, and stays waited for',
      () async {
    final (AppState state, _Engine engine) = await _signedIn();
    state.slowReplyAfter = const Duration(milliseconds: 20);
    state.sendMessage('Make it long');
    await _settle();
    expect(state.slowReply, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(state.slowReply, isTrue);
    expect(state.thinking, isTrue);
    engine.calls.single.reply('Done');
    await _settle();
    expect(state.slowReply, isFalse);
    expect(state.thinking, isFalse);
    expect(_bodies(state).last, 'Done');
  });

  group('Retry', () {
    test('replaces the reply in place, and does not send the old answer',
        () async {
      final (AppState state, _Engine engine) =
          await _signedIn(models: <ChatModel>[_claude, _gpt]);
      state.sendMessage('Name the boat');
      await _settle();
      engine.calls.last.reply('Sea Glass', model: 'claude');
      await _settle();

      final String replyId = state.messages.last.id;
      expect(state.regenerate(replyId: replyId), isTrue);
      await _settle();
      final _Call again = engine.calls.last;
      expect(again.prompt, 'Name the boat');
      expect(again.history, isEmpty,
          reason: 'the answer being replaced is not something it said');
      expect(again.model, 'claude', reason: 'the same model tries again');
      again.reply('Tidewater', model: 'claude');
      await _settle();
      expect(_bodies(state), <String>['Name the boat', 'Tidewater']);
    });

    test('an older reply: the question behind it, and what followed goes',
        () async {
      final (AppState state, _Engine engine) =
          await _signedIn(models: <ChatModel>[_claude, _gpt]);
      state.sendMessage('Name the boat');
      await _settle();
      engine.calls.last.reply('Sea Glass', model: 'claude');
      await _settle();
      final String first = state.messages.last.id;
      state.sendMessage('Now a slogan');
      await _settle();
      engine.calls.last.reply('Always forward', model: 'claude');
      await _settle();

      state.regenerate(replyId: first, using: _gpt);
      await _settle();
      expect(engine.calls.last.prompt, 'Name the boat');
      expect(engine.calls.last.model, 'gpt', reason: 'picked for this try');
      expect(_bodies(state), <String>['Name the boat']);
    });

    test('never hands an image request to a chat model, even when chosen',
        () async {
      final (AppState state, _Engine engine) =
          await _signedIn(models: <ChatModel>[_claude, _gpt]);
      state.sendMessage('Generate an image of Miami');
      await _settle();
      final int sent = engine.calls.length;
      expect(state.regenerate(using: _gpt), isTrue);
      await _settle();
      expect(engine.calls.length, sent, reason: 'nothing was sent');
      expect(state.messages.last.failure?.sentence,
          'No image model is connected yet.');
    });
  });

  test('Edit changes the question and asks again from there', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    state.sendMessage('Name the boat');
    await _settle();
    engine.calls.last.reply('Sea Glass');
    await _settle();
    state.sendMessage('Now a slogan');
    await _settle();
    engine.calls.last.reply('Always forward');
    await _settle();

    final String question = state.messages.first.id;
    expect(state.editMessage(question, 'Name the ferry'), isTrue);
    await _settle();
    expect(engine.calls.last.prompt, 'Name the ferry');
    expect(engine.calls.last.history, isEmpty);
    engine.calls.last.reply('Crossing');
    await _settle();
    expect(_bodies(state), <String>['Name the ferry', 'Crossing']);
  });

  group('ApiClient', () {
    late HttpServer server;
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      // Never answers: the request is only ever ended by the client.
      server.listen((HttpRequest _) {});
    });
    tearDown(() => server.close(force: true));

    test('abort ends a request that would otherwise wait', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        timeout: const Duration(seconds: 30),
      );
      final Completer<void> stop = Completer<void>();
      final Stopwatch clock = Stopwatch()..start();
      final Future<dynamic> call = api.post('/v1/messages',
          body: <String, Object>{}, abort: stop.future);
      Timer(const Duration(milliseconds: 100), stop.complete);
      await expectLater(call, throwsA(isA<ShiftApiException>()));
      expect(clock.elapsed, lessThan(const Duration(seconds: 5)));
      api.close();
    });

    test('wait replaces the timeout for that one call', () async {
      final ApiClient api = ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        timeout: const Duration(milliseconds: 50),
      );
      final Completer<void> stop = Completer<void>();
      bool done = false;
      unawaited(api
          .post(
            '/v1/messages',
            body: <String, Object>{},
            wait: const Duration(seconds: 30),
            abort: stop.future,
          )
          .then((_) {}, onError: (Object _) {})
          .whenComplete(() => done = true));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(done, isFalse, reason: 'still waiting past the 50 ms default');
      stop.complete();
      api.close();
    });
  });
}
