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

const ChatModel _chat = ChatModel(id: 'chat', name: 'Chat', isDefault: true);
const ChatModel _image = ChatModel(
  id: 'shift-image',
  name: 'SHIFT Image',
  bestFor: <TaskKind>{TaskKind.image},
);

/// The load comes back with no models (it ran past the first screen, or
/// its /v1/models failed); the list read on its own is [later].
class _Engine extends SeedRepository {
  _Engine({required this.later, this.refuse = false});

  final List<ChatModel> later;
  final bool refuse;
  final List<String?> sentTo = <String?>[];

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
    );
  }

  @override
  Future<List<ChatModel>> listModels({bool fresh = false}) async {
    if (refuse) {
      throw const ShiftApiException(
        ShiftApiErrorKind.server,
        'The model list is down.',
        status: 502,
      );
    }
    return later;
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
    List<SentFile> files = const <SentFile>[],
  }) async {
    sentTo.add(model);
    return <ChatMessage>[
      ChatMessage(
        id: 'r${sentTo.length}',
        author: MessageAuthor.shift,
        body: 'Here it is.',
        model: model,
      ),
    ];
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

Future<AppState> _signedIn(_Engine engine) async {
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
  return AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
  );
}

Future<void> _settle() async {
  for (int i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
      'an image request is not turned away on a model list that had not '
      'loaded: the list is read again, and the image model makes it', () async {
    final _Engine engine = _Engine(later: const <ChatModel>[_chat, _image]);
    final AppState state = await _signedIn(engine);
    expect(state.chatModels, isEmpty);

    state.sendMessage('generate an image of a pink flower');
    await _settle();
    expect(engine.sentTo, <String?>[_image.id],
        reason: 'it said "No image model is connected yet" and sent nothing');
    expect(state.messages.last.failure, isNull);
    expect(
        state.chatModels.map((ChatModel m) => m.id), contains('shift-image'));
  });

  test('a list that really has none says which models it does have', () async {
    final _Engine engine = _Engine(later: const <ChatModel>[_chat]);
    final AppState state = await _signedIn(engine);
    state.sendMessage('generate an image of a pink flower');
    await _settle();
    expect(engine.sentTo, isEmpty);
    final FailureInfo failure = state.messages.last.failure!;
    expect(failure.sentence, 'No image model is connected yet.');
    expect(failure.details, contains('The server lists Chat'));
    expect(state.thinking, isFalse);
  });

  test('a list that will not load says so, rather than "no image model"',
      () async {
    final _Engine engine = _Engine(later: const <ChatModel>[], refuse: true);
    final AppState state = await _signedIn(engine);
    state.sendMessage('generate an image of a pink flower');
    await _settle();
    expect(engine.sentTo, isEmpty);
    final FailureInfo failure = state.messages.last.failure!;
    expect(failure.sentence, 'The list of models did not load.');
    expect(failure.details, contains('502 · The model list is down.'));
  });

  test('words still go straight to the server, with no extra read', () async {
    final _Engine engine = _Engine(later: const <ChatModel>[_chat, _image]);
    final AppState state = await _signedIn(engine);
    state.sendMessage('why is the sky blue');
    await _settle();
    expect(engine.sentTo, <String?>[null]);
  });

  test('what a model makes, in the words a catalogue uses', () {
    Set<TaskKind> of(Map<String, dynamic> json) =>
        ChatModel.fromJson(<String, dynamic>{'id': 'm', ...json}).bestFor;
    expect(
        of(<String, dynamic>{
          'bestFor': <String>['text-to-image']
        }),
        <TaskKind>{TaskKind.image});
    expect(of(<String, dynamic>{'bestFor': 'image_generation'}),
        <TaskKind>{TaskKind.image});
    // Words this build does not know: the name says what it is.
    expect(
        of(<String, dynamic>{
          'name': 'SHIFT Image',
          'bestFor': <String>['generation'],
        }),
        <TaskKind>{TaskKind.image});
    // Said to be general, it is general, whatever its name.
    expect(of(<String, dynamic>{'name': 'Image Helper', 'bestFor': <String>[]}),
        isEmpty);
  });
}
