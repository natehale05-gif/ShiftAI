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
import 'package:shift_ai/util/model_router.dart';

/// A server with specialists: a video and an image model beside two
/// general ones.
final List<ChatModel> _panel = <ChatModel>[
  ..._models,
  ChatModel.fromJson(const <String, String>{'id': 'veo', 'name': 'Veo 3'}),
  ChatModel.fromJson(const <String, String>{'id': 'flux', 'name': 'Flux Pro'}),
];

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
        modelName: models
            .firstWhere((ChatModel m) => m.id == id,
                orElse: () => ChatModel(id: id, name: id))
            .name,
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

  test(
      'Best fit sends one model, the default for plain talk, and a failure '
      'notice is never history', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    expect(state.answeringLabel, 'Best fit');
    state.sendMessage('Hello');
    await _settle();
    expect(engine.sent.single.model, 'claude');
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

    // Best fit, until one is picked.
    expect(find.text('Best fit'), findsOneWidget);
    await tester.tap(find.text('Best fit'));
    await tester.pumpAndSettle();
    expect(find.text('Who answers'), findsOneWidget);
    await tester.tap(find.text('Other model'));
    await tester.pumpAndSettle();
    expect(state.chatModel?.id, 'other');

    state.sendMessage('Hi');
    await tester.pumpAndSettle();
    // The label over the reply, and the picker naming the next answerer.
    expect(find.text('Other model'), findsNWidgets(2));
    expect(find.text('Answer 1 from other'), findsOneWidget);
  });

  group('Best fit: one model per message, the right one', () {
    test('the message goes to the model suited to it, and only that one',
        () async {
      final (AppState state, _Engine engine) = await _signedIn();
      engine.models = _panel;
      await state.refresh();

      state.sendMessage('Make a video of Miami at sunset');
      await _settle();
      expect(engine.sent.single.model, 'veo');

      state.sendMessage('Now a poster for it');
      await _settle();
      expect(engine.sent.last.model, 'flux');

      state.sendMessage('Write a caption for the clip');
      await _settle();
      expect(engine.sent.last.model, 'claude');
      expect(engine.sent, hasLength(3), reason: 'one call per message');
    });

    test(
        'a follow-up stays with the general model that answered; a question '
        'after a specialist goes back to the default', () async {
      final (AppState state, _Engine engine) = await _signedIn();
      engine.models = _panel;
      await state.refresh();

      state.setChatModel('other');
      state.sendMessage('Hello');
      await _settle();
      state.setChatModel(null);
      state.sendMessage('Thanks, shorter please');
      await _settle();
      expect(engine.sent.last.model, 'other', reason: 'no hop for nothing');

      state.sendMessage('Make a video of it');
      await _settle();
      expect(engine.sent.last.model, 'veo');
      state.sendMessage('Why is the sky blue?');
      await _settle();
      expect(engine.sent.last.model, 'claude', reason: 'not the video model');
    });

    test('a model picked by hand answers everything; null is Best fit again',
        () async {
      final (AppState state, _Engine engine) = await _signedIn();
      engine.models = _panel;
      await state.refresh();
      state.setChatModel('other');
      state.sendMessage('Make a video of Miami');
      await _settle();
      expect(engine.sent.last.model, 'other');
      state.setChatModel(null);
      expect(state.answeringLabel, 'Best fit');
    });

    test('an older build\'s stored "*every" reads as Best fit', () async {
      final (AppState state, _) = await _signedIn(<String, Object>{
        StoreKeys.app: jsonEncode(<String, Object>{'chatModel': '*every'}),
      });
      expect(state.chatModel, isNull);
      expect(state.answeringLabel, 'Best fit');
    });

    test('with no models listed the server chooses', () async {
      final (AppState state, _Engine engine) = await _signedIn();
      engine.models = const <ChatModel>[];
      await state.refresh();
      state.sendMessage('Make a video');
      await _settle();
      expect(engine.sent.single.model, isNull);
    });
  });

  group('what a message asks for', () {
    test('a medium when the thing itself is wanted, writing for words', () {
      final Map<String, TaskKind?> cases = <String, TaskKind?>{
        'make a video of Miami': TaskKind.video,
        'a 15 second reel for the launch': TaskKind.video,
        'generate a logo for the café': TaskKind.image,
        'a poster for Friday': TaskKind.image,
        'compose a jingle for the ad': TaskKind.audio,
        'write a caption for the ferry clip': TaskKind.writing,
        'make me a caption for the video': TaskKind.writing,
        'a script for the promo video': TaskKind.writing,
        'describe this photo': TaskKind.writing,
        'fix this bug in my Dart function': TaskKind.code,
        'find the latest news on the launch': TaskKind.research,
        'draft an email to the venue': TaskKind.writing,
        'thanks, shorter please': null,
        'why is the sky blue?': null,
      };
      cases.forEach((String prompt, TaskKind? kind) {
        expect(ModelRouter.kindOf(prompt), kind, reason: prompt);
      });
    });

    test('a model says what it is for, or its name does', () {
      expect(
        ChatModel.fromJson(const <String, Object>{
          'id': 'x',
          'name': 'Studio',
          'bestFor': <String>['video', 'images'],
        }).bestFor,
        <TaskKind>{TaskKind.video, TaskKind.image},
      );
      TaskKind? only(String id, String name) {
        final Set<TaskKind> k =
            ChatModel.fromJson(<String, String>{'id': id, 'name': name})
                .bestFor;
        return k.length == 1 ? k.single : null;
      }

      expect(only('veo-3', 'Veo 3'), TaskKind.video);
      expect(only('sora-2', 'Sora'), TaskKind.video);
      expect(only('flux-pro', 'Flux Pro'), TaskKind.image);
      expect(only('dall-e-3', 'DALL·E 3'), TaskKind.image);
      expect(only('suno-v4', 'Suno'), TaskKind.audio);
      expect(
        ChatModel.fromJson(const <String, String>{
          'id': 'claude-opus-5-5',
          'name': 'Claude Opus 5.5',
        }).bestFor,
        isEmpty,
        reason: 'a general model takes whatever no specialist does',
      );
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
