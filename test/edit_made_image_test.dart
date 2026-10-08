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
import 'package:shift_ai/util/model_router.dart';

const ChatModel _chat = ChatModel(id: 'chat', name: 'Chat', isDefault: true);
const ChatModel _image = ChatModel(
  id: 'shift-image',
  name: 'SHIFT Image',
  bestFor: <TaskKind>{TaskKind.image},
);

/// Two models; the image one makes a picture, saved in the vault.
class _Engine extends SeedRepository {
  final List<
      ({
        String prompt,
        String? model,
        List<SentFile> files,
        List<ChatTurn> history
      })> sent = [];
  int made = 0;
  List<ChatModel> models = const <ChatModel>[_chat, _image];

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
    List<SentFile> files = const <SentFile>[],
  }) async {
    sent.add((prompt: prompt, model: model, files: files, history: history));
    if (model == _image.id) {
      made++;
      return <ChatMessage>[
        ChatMessage(
          id: 'r${sent.length}',
          author: MessageAuthor.shift,
          body: 'Here it is.',
          model: _image.id,
          modelName: _image.name,
          attachment: MessageAttachment(
            fileName: 'image-$made.png',
            meta: '1024 × 1024',
            kind: MediaKind.image,
            vaultItemId: 'v-$made',
          ),
        ),
      ];
    }
    return <ChatMessage>[
      ChatMessage(
        id: 'r${sent.length}',
        author: MessageAuthor.shift,
        body: 'Words.',
        model: model,
      ),
    ];
  }

  @override
  Future<List<VaultItem>> vault() async => <VaultItem>[
        for (int i = made; i >= 1; i--)
          VaultItem.fromJson(<String, dynamic>{
            ...Seed.vault.first.toJson(),
            'id': 'v-$i',
            'kind': 'image',
            'mediaUrl': 'https://app.example.com/media/$i.png',
          }),
      ];

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
  for (int i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<(AppState, _Engine)> _withAFlower() async {
  final (AppState state, _Engine engine) = await _signedIn();
  state.sendMessage('Generate an image of a pink flower');
  await _settle();
  expect(engine.sent.single.model, _image.id);
  return (state, engine);
}

void main() {
  test(
      'a change right after a picture goes to the model that made it, with '
      'the picture', () async {
    final (AppState state, _Engine engine) = await _withAFlower();
    state.sendMessage('make the petals purple');
    await _settle();

    final edit = engine.sent.last;
    expect(edit.model, _image.id,
        reason: 'it used to go to the chat model, which had only a name');
    expect(edit.files.single.vaultItemId, 'v-1');
    expect(edit.files.single.url, 'https://app.example.com/media/1.png');
    // The new picture is the next answer, and the question shows what it
    // changed.
    expect(state.messages.last.attachment?.vaultItemId, 'v-2');
    expect(state.messages[state.messages.length - 2].files.single.name,
        'image-1.png');
  });

  test(
      'a question or a caption about it goes to the chat model, which is '
      'given the picture too', () async {
    final (AppState state, _Engine engine) = await _withAFlower();
    state.sendMessage('What flower is this?');
    await _settle();
    expect(engine.sent.last.model, _chat.id);
    final ChatTurn made = engine.sent.last.history.last;
    expect(made.role, 'assistant');
    expect(made.files.single.vaultItemId, 'v-1',
        reason: 'the picture goes back with its turn, not only its name');

    state.sendMessage('write a caption for it');
    await _settle();
    expect(engine.sent.last.model, _chat.id);
  });

  test(
      'putting the picture into a website goes to a model that builds one, '
      'with the picture, not back to the image model', () async {
    final (AppState state, _Engine engine) = await _withAFlower();
    state.sendMessage('put this into a website about pink flowers');
    await _settle();
    expect(engine.sent.last.model, _chat.id,
        reason: 'it went to SHIFT Image as an edit and came back as more '
            'flowers');
    expect(engine.sent.last.files, isEmpty);
    expect(engine.sent.last.history.last.files.single.vaultItemId, 'v-1',
        reason: 'the picture is in the conversation for it to use');
  });

  test('Edit picks the picture, whatever the words, and then lets go',
      () async {
    final (AppState state, _Engine engine) = await _withAFlower();
    final String reply = state.messages.last.id;
    // Thanks is not a change on its own...
    state.sendMessage('thanks');
    await _settle();
    expect(engine.sent.last.model, _chat.id);
    expect(engine.sent.last.files, isEmpty);

    // ...but with Edit picked, the next message changes that picture.
    state.editMade(reply);
    expect(state.editing?.id, reply);
    state.sendMessage('a bee on it');
    await _settle();
    expect(engine.sent.last.model, _image.id);
    expect(engine.sent.last.files.single.vaultItemId, 'v-1');
    expect(state.editingId, isNull, reason: 'one message, one edit');
  });

  test('with no image model to edit with, nothing is sent', () async {
    final (AppState state, _Engine engine) = await _withAFlower();
    engine.models = const <ChatModel>[_chat];
    await state.refresh();
    final int before = engine.sent.length;
    state.sendMessage('make it brighter');
    await _settle();
    expect(engine.sent.length, before);
    expect(state.messages.last.failure?.sentence,
        'No image model is connected yet.');
  });

  test('what reads as a change to a picture', () {
    for (final String edit in <String>[
      'make the petals purple',
      'add a bee',
      'brighter',
      'remove the background',
      'try it in watercolour style',
    ]) {
      expect(ModelRouter.looksLikeEdit(edit), isTrue, reason: edit);
    }
    for (final String other in <String>[
      'What flower is this?',
      'write a caption for it',
      'thanks',
      'make a video of it',
      // Using the picture in something else is not changing it.
      'put this into a website about pink flowers',
      'make a landing page with it',
    ]) {
      expect(ModelRouter.looksLikeEdit(other), isFalse, reason: other);
    }
  });
}
