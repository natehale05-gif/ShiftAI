import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// A real socket, so the answer really arrives in pieces.
class _Server {
  late HttpServer _http;
  final List<String> accepts = <String>[];

  /// Set per test: what /v1/messages does with the request.
  late Future<void> Function(HttpResponse out) answer;

  Future<String> start() async {
    _http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _http.listen((HttpRequest request) async {
      accepts.add(request.headers.value('accept') ?? '');
      await request.drain<void>();
      await answer(request.response);
    });
    return 'http://127.0.0.1:${_http.port}';
  }

  Future<void> stop() => _http.close(force: true);
}

Future<void> _events(
  HttpResponse out,
  List<(String, Object)> events, {
  Duration gap = const Duration(milliseconds: 30),
}) async {
  out.headers.contentType = ContentType('text', 'event-stream');
  out.bufferOutput = false;
  for (final (String name, Object data) in events) {
    out.write('event: $name\ndata: ${jsonEncode(data)}\n\n');
    await out.flush();
    await Future<void>.delayed(gap);
  }
  await out.close();
}

const Map<String, Object> _done = <String, Object>{
  'id': 'm1',
  'author': 'shift',
  'model': 'claude',
  'modelName': 'Claude',
  'body': 'Harbour light, one crossing.',
};

void main() {
  group('ApiClient.postEvents', () {
    late _Server server;
    late ApiClient api;
    setUp(() async {
      server = _Server();
      api = ApiClient(baseUrl: await server.start());
    });
    tearDown(() async {
      api.close();
      await server.stop();
    });

    test('hands over each piece as it lands, then returns the answer',
        () async {
      server.answer = (HttpResponse out) => _events(out, <(String, Object)>[
            ('text', <String, String>{'text': 'Harbour '}),
            ('text', <String, String>{'text': 'light, '}),
            ('text', <String, String>{'text': 'one crossing.'}),
            ('messages', <Object>[_done]),
          ]);
      final List<(String, Duration)> pieces = <(String, Duration)>[];
      final Stopwatch clock = Stopwatch()..start();
      final dynamic body = await api.postEvents(
        '/v1/messages',
        body: <String, Object>{},
        onText: (String t) => pieces.add((t, clock.elapsed)),
      );
      expect(server.accepts.single, contains('text/event-stream'));
      expect(pieces.map((p) => p.$1).join(), 'Harbour light, one crossing.');
      expect(pieces.last.$2 - pieces.first.$2,
          greaterThan(const Duration(milliseconds: 40)),
          reason: 'the pieces arrived as they were sent, not all at the end');
      expect((body as List<dynamic>).single['body'],
          'Harbour light, one crossing.');
    });

    test('a server that does not stream answers JSON, as before', () async {
      server.answer = (HttpResponse out) async {
        out.headers.contentType = ContentType.json;
        out.write(jsonEncode(<Object>[_done]));
        await out.close();
      };
      int pieces = 0;
      final dynamic body = await api.postEvents('/v1/messages',
          body: <String, Object>{}, onText: (_) => pieces++);
      expect(pieces, 0);
      expect((body as List<dynamic>).single['id'], 'm1');
    });

    test('an error event is a refusal with its sentence', () async {
      server.answer = (HttpResponse out) => _events(out, <(String, Object)>[
            ('text', <String, String>{'text': 'Harbour '}),
            ('error', <String, String>{'message': 'Out of credits.'}),
          ]);
      await expectLater(
        api.postEvents('/v1/messages', body: <String, Object>{}),
        throwsA(isA<ShiftApiException>().having(
            (ShiftApiException e) => e.message, 'message', 'Out of credits.')),
      );
    });

    test('an error status is still an error, with its message', () async {
      server.answer = (HttpResponse out) async {
        out.statusCode = 402;
        out.headers.contentType = ContentType.json;
        out.write(jsonEncode(<String, String>{'message': 'Top up first.'}));
        await out.close();
      };
      await expectLater(
        api.postEvents('/v1/messages', body: <String, Object>{}),
        throwsA(isA<ShiftApiException>()
            .having((ShiftApiException e) => e.status, 'status', 402)
            .having((ShiftApiException e) => e.message, 'message',
                'Top up first.')),
      );
    });

    test('the repository keeps what was written when the stream just ends',
        () async {
      server.answer = (HttpResponse out) => _events(out, <(String, Object)>[
            ('text', <String, String>{'text': 'Harbour '}),
            ('text', <String, String>{'text': 'light.'}),
          ]);
      final List<String> soFar = <String>[];
      final List<ChatMessage> answer = await HttpRepository(api)
          .send('Name it', model: 'claude', onText: soFar.add);
      expect(soFar, <String>['Harbour ', 'Harbour light.'],
          reason: 'the answer so far, not only the newest piece');
      expect(answer.single.body, 'Harbour light.');
      expect(answer.single.model, 'claude');
    });
  });

  group('the thread', () {
    test('grows the reply in place, then puts the finished one there',
        () async {
      final (AppState state, _Engine engine) = await _signedIn();
      state.sendMessage('Name the ferry');
      await _settle();
      expect(state.streamingId, isNull, reason: '"Working" until words come');

      engine.write('Harbour ');
      expect(state.streamingId, isNotNull);
      expect(state.messages.last.body, 'Harbour ');
      engine.write('Harbour light');
      expect(state.messages.length, 2, reason: 'one reply, growing');
      expect(state.messages.last.body, 'Harbour light');
      expect(state.thinking, isTrue, reason: 'Stop still works');

      engine.finish('Harbour light, one crossing.');
      await _settle();
      expect(state.streamingId, isNull);
      expect(state.thinking, isFalse);
      expect(state.messages.map((ChatMessage m) => m.body), <String>[
        'Name the ferry',
        'Harbour light, one crossing.',
      ]);
    });

    test('Stop part way keeps what was written', () async {
      final (AppState state, _Engine engine) = await _signedIn();
      state.sendMessage('Name the ferry');
      await _settle();
      engine.write('Harbour light');
      state.stopReply();
      await _settle();
      expect(state.stopped, isTrue);
      expect(state.streamingId, isNull);
      expect(state.messages.last.body, 'Harbour light');
      expect(state.chatHistory.last.body, 'Harbour light',
          reason: 'the next message reads what it said');
    });
  });
}

/// An engine the test writes the answer for, piece by piece.
class _Engine extends SeedRepository {
  void Function(String soFar)? _onText;
  Completer<List<ChatMessage>>? _answer;

  void write(String soFar) => _onText!(soFar);

  void finish(String body) => _answer!.complete(<ChatMessage>[
        ChatMessage(id: 'done', author: MessageAuthor.shift, body: body),
      ]);

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
    _onText = onText;
    final Completer<List<ChatMessage>> answer =
        _answer = Completer<List<ChatMessage>>();
    cancel?.then((_) {
      if (!answer.isCompleted) {
        answer.completeError(
          const ShiftApiException(ShiftApiErrorKind.offline, 'Aborted.'),
        );
      }
    });
    return answer.future;
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

Future<(AppState, _Engine)> _signedIn() async {
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
  final _Engine engine = _Engine();
  final AppState state = await AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
  );
  return (state, engine);
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
