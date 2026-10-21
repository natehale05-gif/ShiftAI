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
const ChatModel _video = ChatModel(
  id: 'showcase-video',
  name: 'Showcase video (with sound)',
  bestFor: <TaskKind>{TaskKind.video},
);

Map<String, dynamic> _row(
  String id,
  String kind, {
  DateTime? at,
  bool file = true,
  String? from,
}) =>
    <String, dynamic>{
      if (from != null) 'editedFrom': from,
      ...Seed.vault.first.toJson(),
      'id': id,
      'title': 'Row $id',
      'kind': kind,
      'mediaType': kind,
      'createdAt': (at ?? DateTime.now()).toUtc().toIso8601String(),
      'mediaUrl': file ? 'https://app.example.com/media/$id.mp4' : null,
      'thumbnailUrl': 'https://app.example.com/media/$id.webp',
      'durationSeconds': 8,
      'width': 1280,
      'height': 720,
    }..remove('byHandle');

/// The image model makes a picture at once; the video model answers the
/// way Showcase did on 16 Oct, with words, and saves the video later.
class _Engine extends SeedRepository {
  final List<({String prompt, String? model, List<SentFile> files})> sent = [];
  final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  String videoSays =
      'Making your video now. It will be in your Vault in about 3 minutes.';

  @override
  Future<ShiftSnapshot> load() async {
    final ShiftSnapshot s = await super.load();
    return ShiftSnapshot(
      creator: s.creator,
      standings: s.standings,
      trophies: s.trophies,
      vault: await vault(),
      ecoVault: s.ecoVault,
      notes: s.notes,
      agentRuns: s.agentRuns,
      jobs: s.jobs,
      designs: s.designs,
      connectors: s.connectors,
      weekPool: s.weekPool,
      payoutLine: s.payoutLine,
      avatars: s.avatars,
      models: const <ChatModel>[_chat, _image, _video],
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
    sent.add((prompt: prompt, model: model, files: files));
    if (model == _image.id) {
      rows.add(_row('flag', 'image'));
      return <ChatMessage>[
        const ChatMessage(
          id: 'r-flag',
          author: MessageAuthor.shift,
          body: 'Here it is.',
          model: 'shift-image',
          attachment: MessageAttachment(
            fileName: 'image-flag.png',
            meta: '1024 × 1024',
            kind: MediaKind.image,
            vaultItemId: 'flag',
          ),
        ),
      ];
    }
    return <ChatMessage>[
      ChatMessage(
        id: 'r${sent.length}',
        author: MessageAuthor.shift,
        eyebrow: 'ShiftAi · Video',
        body: model == _video.id ? videoSays : 'Words.',
        model: model,
      ),
    ];
  }

  @override
  Future<List<VaultItem>> vault() async =>
      rows.reversed.map(VaultItem.fromJson).toList();

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

Future<(AppState, _Engine)> _signedIn([_Engine? given]) async {
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
  final _Engine engine = given ?? _Engine();
  final AppState state = await AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
  );
  return (state, engine);
}

Future<void> _settle([int turns = 12]) async {
  for (int i = 0; i < turns; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

/// A flag, then "make it sway in the wind", answered with words.
Future<(AppState, _Engine)> _swaying() async {
  final (AppState state, _Engine engine) = await _signedIn();
  state.sendMessage('generate an image of the spanish flag');
  await _settle();
  state.sendMessage('make it sway in the wind');
  await _settle();
  expect(engine.sent.last.model, _video.id);
  return (state, engine);
}

void main() {
  setUp(() {
    AppState.vaultWaits = const <Duration>[];
    AppState.madeEvery = const Duration(milliseconds: 5);
    AppState.madeFor = const Duration(seconds: 2);
  });

  test(
      'a video that is still being made appears in its reply when it lands '
      'in the vault', () async {
    final (AppState state, _Engine engine) = await _swaying();
    final ChatMessage reply = state.messages.last;
    expect(reply.awaiting, MediaType.video,
        reason: 'on 16 Oct the chat stopped at "It will be in your Vault in '
            'about 3 minutes" and never showed the video');
    expect(reply.attachment, isNull);

    engine.rows.add(_row('swaying', 'video'));
    await _settle(40);

    final ChatMessage done = state.messages.last;
    expect(done.attachment?.vaultItemId, 'swaying');
    expect(done.attachment?.url, 'https://app.example.com/media/swaying.mp4');
    expect(done.attachment?.thumbnailUrl,
        'https://app.example.com/media/swaying.webp');
    expect(state.madeTypeOf(done.attachment!), MediaType.video);
    expect(done.awaiting, isNull);
    // Saved that way, so the chat reopens on the video.
    expect(
      state.threads.first.messages.last.attachment?.vaultItemId,
      'swaying',
    );
  });

  test(
      'an older video, a picture, or a row whose file is not there yet is '
      'not taken for it', () async {
    final _Engine engine = _Engine()
      ..rows.add(_row(
        'old',
        'video',
        at: DateTime.now().subtract(const Duration(hours: 1)),
      ))
      ..rows.add(_row('already', 'video'));
    final (AppState state, _) = await _signedIn(engine);
    state.sendMessage('generate an image of the spanish flag');
    await _settle();
    state.sendMessage('make it sway in the wind');
    await _settle();
    engine.rows.add(_row('placeholder', 'video', file: false));
    engine.rows.add(_row('picture', 'image'));
    await _settle(20);
    expect(state.messages.last.attachment, isNull,
        reason: 'the video in the vault before it was asked is not this one');

    engine.rows.add(_row('this-one', 'video'));
    await _settle(40);
    expect(state.messages.last.attachment?.vaultItemId, 'this-one');
  });

  test(
      'the video model is told which picture "it" is and what it shows; the '
      'thread shows what was typed', () async {
    final (AppState state, _Engine engine) = await _swaying();
    final String sent = engine.sent.last.prompt;
    expect(sent, contains('Animate the attached picture (image-flag.png)'),
        reason: 'on 21 Oct a leaf came back as a tree: the model had only '
            '"make it sway in the wind"');
    expect(sent, contains('which shows the spanish flag'));
    expect(sent, contains('make it sway in the wind'));
    expect(sent, contains('do not make a new scene'));
    expect(engine.sent.last.files.single.vaultItemId, 'flag');
    expect(state.messages[state.messages.length - 2].body,
        'make it sway in the wind');

    // Words alone, about something else, go as they were typed.
    state.sendMessage('make a video of Miami');
    await _settle();
    expect(engine.sent.last.prompt, 'make a video of Miami');
  });

  test(
      'a video of the picture that does not say it used it says it may be '
      'a new one; one that does says what it was made from', () async {
    final (AppState state, _Engine engine) = await _swaying();
    engine.rows.add(_row('tree', 'video'));
    await _settle(40);
    final ChatMessage tree = state.messages.last;
    expect(tree.attachment?.vaultItemId, 'tree');
    expect(state.editNotConfirmed(tree), isTrue);

    final (AppState again, _Engine other) = await _swaying();
    other.rows.add(_row('leaf', 'video', from: 'flag'));
    await _settle(40);
    final ChatMessage leaf = again.messages.last;
    expect(leaf.attachment?.editedFrom, 'flag');
    expect(again.editNotConfirmed(leaf), isFalse);
    expect(again.editedFromName(leaf), 'image-flag.png');
  });

  test('a question back from the video model is not waited on', () async {
    final _Engine engine = _Engine()..videoSays = 'How long should it be?';
    final (AppState state, _) = await _signedIn(engine);
    state.sendMessage('generate an image of the spanish flag');
    await _settle();
    state.sendMessage('make it sway in the wind');
    await _settle();
    expect(state.messages.last.awaiting, isNull);
  });

  test('words from a chat model are not waited on', () async {
    final (AppState state, _) = await _signedIn();
    state.sendMessage('why is the sky blue');
    await _settle();
    expect(state.messages.last.awaiting, isNull);
  });

  test('a video that takes too long says so, and Look again finds it',
      () async {
    AppState.madeFor = const Duration(milliseconds: 60);
    final (AppState state, _Engine engine) = await _swaying();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await _settle();
    final String id = state.messages.last.id;
    expect(state.madeLate(id), isTrue);
    expect(state.messages.last.awaiting, MediaType.video,
        reason: 'still waiting, so a reopened chat looks again');

    engine.rows.add(_row('late', 'video'));
    state.lookAgainForMade(id);
    expect(state.madeLate(id), isFalse);
    await _settle(20);
    expect(state.messages.last.attachment?.vaultItemId, 'late');
  });

  test('a saved chat still waiting looks again when it is opened', () async {
    AppState.madeFor = const Duration(milliseconds: 60);
    final (AppState state, _Engine engine) = await _swaying();
    final String thread = state.currentThreadId!;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    state.clearThread();

    final ChatMessage kept = state.threads
        .firstWhere((ChatThread t) => t.id == thread)
        .messages
        .last;
    final ChatMessage back = ChatMessage.fromJson(kept.toJson());
    expect(back.awaiting, MediaType.video);
    expect(back.askedAt, isNotNull);

    AppState.madeFor = const Duration(minutes: 10);
    engine.rows.add(_row('while-away', 'video'));
    state.openThread(thread);
    await _settle(20);
    expect(state.messages.last.attachment?.vaultItemId, 'while-away');
  });
}
