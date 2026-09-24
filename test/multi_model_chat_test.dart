import 'dart:convert';

import 'package:flutter/material.dart';
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

const List<ChatModel> _models = <ChatModel>[
  ChatModel(
      id: 'claude', name: 'Claude', provider: 'Anthropic', isDefault: true),
  ChatModel(id: 'other', name: 'Other model', provider: 'Elsewhere'),
];

/// A server stand-in that records what each message carried, and answers
/// as whichever model was asked, the way docs/API.md says it should.
class _Engine extends SeedRepository {
  final List<({String prompt, String? model, List<ChatTurn> history})> sent =
      <({String prompt, String? model, List<ChatTurn> history})>[];

  /// The model that refuses, for the round's failure test.
  String? failFor;

  List<ChatModel> models = _models;

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
      league: s.league,
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
  }) async {
    sent.add((prompt: prompt, model: model, history: history));
    if (model != null && model == failFor) {
      throw const ShiftApiException(ShiftApiErrorKind.server, 'Down.');
    }
    final String id = model ?? 'claude';
    return <ChatMessage>[
      ChatMessage(
        id: 'r${sent.length}',
        author: MessageAuthor.shift,
        body: 'Answer ${sent.length} from $id',
        bullets: sent.length == 1 ? <String>['first point'] : <String>[],
        model: id,
        modelName: _models.firstWhere((ChatModel m) => m.id == id).name,
      ),
    ];
  }
}

class _StubAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<(AppState, _Engine)> _signedIn([Map<String, Object>? prefs]) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'shift-backend': 'https://api.example.com',
    ...?prefs,
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

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test(
      'each message carries the whole conversation, every model\'s '
      'reply as the assistant\'s own', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    expect(state.chatModels.map((ChatModel m) => m.id), <String>[
      'claude',
      'other',
    ]);

    state.setChatModel('claude');
    expect(state.sendMessage('Write a caption'), isTrue);
    await _settle();
    expect(engine.sent.single.model, 'claude');
    expect(engine.sent.single.history, isEmpty);

    // Switch AIs mid-conversation. The second one is given the first
    // one's reply as an assistant turn, list folded in, so it can carry on.
    state.setChatModel('other');
    state.sendMessage('Now shorter');
    await _settle();
    final List<ChatTurn> history = engine.sent.last.history;
    expect(engine.sent.last.model, 'other');
    expect(history.map((ChatTurn t) => t.role), <String>['user', 'assistant']);
    expect(history.first.body, 'Write a caption');
    expect(history.last.body, 'Answer 1 from claude\n- first point');
    expect(history.last.model, 'claude');

    // And back again: the first AI reads the second one's answer as well.
    state.setChatModel('claude');
    state.sendMessage('One more');
    await _settle();
    expect(engine.sent.last.history.map((ChatTurn t) => t.body), <String>[
      'Write a caption',
      'Answer 1 from claude\n- first point',
      'Now shorter',
      'Answer 2 from other',
    ]);
    expect(
      engine.sent.last.history
          .where((ChatTurn t) => t.role == 'assistant')
          .map((ChatTurn t) => t.model),
      <String>['claude', 'other'],
    );
  });

  test('Auto sends no model, and a failure notice is never history', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    // Auto is a pick now; with nothing picked, every model answers.
    state.setChatModel(null);
    expect(state.answeringWithEvery, isFalse);
    state.sendMessage('Hello');
    await _settle();
    expect(engine.sent.single.model, isNull);
    state.messages = <ChatMessage>[
      ...state.messages,
      const ChatMessage(
        id: 'e1',
        author: MessageAuthor.shift,
        body: 'Could not reach the server.',
        failure: FailureInfo(
          sentence: 'That did not reach the server.',
          reassurance: 'Nothing was charged.',
          details: 'offline',
        ),
      ),
    ];
    expect(
      state.chatHistory.any((ChatTurn t) => t.body.contains('Could not')),
      isFalse,
    );
  });

  test('the pick survives a restart, and a model the server dropped is Auto',
      () async {
    final (AppState state, _) = await _signedIn();
    state.setChatModel('other');
    await state.flush();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String blob = prefs.getString(StoreKeys.app)!;

    final (AppState again, _) =
        await _signedIn(<String, Object>{StoreKeys.app: blob});
    expect(again.chatModel?.id, 'other');

    final Map<String, dynamic> gone = jsonDecode(blob) as Map<String, dynamic>
      ..['chatModel'] = 'retired';
    final (AppState later, _) =
        await _signedIn(<String, Object>{StoreKeys.app: jsonEncode(gone)});
    expect(later.chatModel, isNull);
  });

  test(
      'over HTTP: model and history in the body, who answered in the reply, '
      'and /v1/models optional', () async {
    final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
    http.Response route(http.Request r) => switch (r.url.path) {
          '/v1/messages' => () {
              bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
              return http.Response(
                jsonEncode(<Map<String, dynamic>>[
                  <String, dynamic>{
                    'id': 'm2',
                    'author': 'shift',
                    'model': 'claude',
                    'modelName': 'Claude',
                    'body': 'Hi',
                  },
                ]),
                200,
              );
            }(),
          '/v1/models' => http.Response('{"message":"no route"}', 404),
          '/v1/me' => http.Response(
              '{"handle":"n","name":"Nate","email":"n@example.com"}', 200),
          '/v1/week' ||
          '/v1/league' ||
          '/v1/boards' =>
            http.Response('{}', 200),
          _ => http.Response('[]', 200),
        };
    final HttpRepository repo = HttpRepository(ApiClient(
      baseUrl: 'https://api.example.com',
      client: _Client(route),
    ));

    final ShiftSnapshot snap = await repo.load();
    expect(snap.models, isEmpty);

    final List<ChatMessage> answer = await repo.send(
      'Again',
      model: 'claude',
      history: const <ChatTurn>[
        ChatTurn(role: 'user', body: 'Hello'),
        ChatTurn(role: 'assistant', body: 'Hi there', model: 'other'),
      ],
    );
    expect(bodies.single['model'], 'claude');
    expect(bodies.single['history'], <Map<String, dynamic>>[
      <String, dynamic>{'role': 'user', 'body': 'Hello'},
      <String, dynamic>{
        'role': 'assistant',
        'body': 'Hi there',
        'model': 'other',
      },
    ]);
    expect(answer.single.model, 'claude');
    expect(answer.single.modelName, 'Claude');
  });

  testWidgets(
      'replies are labelled by who wrote them, and the composer '
      'says who answers next', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(412 * 3, 1600 * 3);
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

    // Every model, until one is picked.
    expect(find.text('Every model'), findsOneWidget);
    await tester.tap(find.text('Every model'));
    await tester.pumpAndSettle();
    expect(find.text('Who answers'), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);
    await tester.tap(find.text('Other model'));
    await tester.pumpAndSettle();
    expect(state.chatModel?.id, 'other');

    state.sendMessage('Hi');
    await tester.pumpAndSettle();
    // The label over the reply, and the picker naming the next answerer.
    expect(find.text('Other model'), findsNWidgets(2));
    expect(find.text('Answer 1 from other'), findsOneWidget);
  });

  group('every model answers', () {
    test(
        'with nothing picked, each connected AI answers the message in turn, '
        'the second reading the first as its own', () async {
      final (AppState state, _Engine engine) = await _signedIn();
      expect(state.answeringWithEvery, isTrue);
      expect(state.answeringLabel, 'Every model');

      state.sendMessage('Write a caption');
      await _settle();
      await _settle();

      // One call per model, in the order the server lists them.
      expect(engine.sent.map((s) => s.model), <String?>['claude', 'other']);
      // The first gets the message itself and what came before it.
      expect(engine.sent[0].prompt, 'Write a caption');
      expect(engine.sent[0].history, isEmpty);
      // The second gets the message and the first answer as the
      // assistant's own, then the ask to carry on from it.
      expect(engine.sent[1].prompt, AppState.everyModelFollowUp);
      expect(engine.sent[1].history.map((ChatTurn t) => t.role),
          <String>['user', 'assistant']);
      expect(engine.sent[1].history.first.body, 'Write a caption');
      expect(engine.sent[1].history.last.body,
          'Answer 1 from claude\n- first point');

      // Both answers are in the thread, labelled, and the follow-up is not.
      expect(
        state.messages.map((ChatMessage m) => m.modelName ?? m.author.name),
        <String>['you', 'Claude', 'Other model'],
      );
      expect(
          state.messages
              .any((ChatMessage m) => m.body == AppState.everyModelFollowUp),
          isFalse);
      expect(state.thinking, isFalse);

      // The next message's history has both answers.
      state.sendMessage('Shorter');
      await _settle();
      await _settle();
      expect(engine.sent[2].history.map((ChatTurn t) => t.model),
          <String?>[null, 'claude', 'other']);
    });

    test('picking one model, or Auto, turns it off; Every model back on',
        () async {
      final (AppState state, _Engine engine) = await _signedIn();
      state.setChatModel('other');
      expect(state.answeringWithEvery, isFalse);
      state.sendMessage('Hi');
      await _settle();
      expect(engine.sent.single.model, 'other');

      state.setAnswerWithEvery();
      expect(state.answeringWithEvery, isTrue);
      await state.flush();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final (AppState again, _) = await _signedIn(
          <String, Object>{StoreKeys.app: prefs.getString(StoreKeys.app)!});
      expect(again.answeringWithEvery, isTrue);
    });

    test('one model failing does not stop the others', () async {
      final (AppState state, _Engine engine) = await _signedIn();
      engine.failFor = 'claude';
      state.sendMessage('Hi');
      await _settle();
      await _settle();
      expect(engine.sent.map((s) => s.model), <String?>['claude', 'other']);
      expect(state.messages[1].failure?.sentence, 'Claude did not answer.');
      expect(state.messages[2].modelName, 'Other model');
      // The failure is not something the next model reads.
      expect(
          engine.sent[1].history.map((ChatTurn t) => t.role), <String>['user']);
    });

    test('a new message ends the round before it', () async {
      final (AppState state, _Engine engine) = await _signedIn();
      state.sendMessage('First');
      state.clearThread();
      await _settle();
      await _settle();
      expect(engine.sent, hasLength(1));
      expect(state.messages, isEmpty);
    });

    test('with one model connected there is no round', () async {
      final (AppState state, _Engine engine) = await _signedIn();
      engine.models = <ChatModel>[_models.first];
      await state.refresh();
      expect(state.answeringWithEvery, isFalse);
      state.sendMessage('Hi');
      await _settle();
      expect(engine.sent, hasLength(1));
    });
  });
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
