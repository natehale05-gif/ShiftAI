import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/features/chat/suite_surface.dart';
import 'package:shift_ai/features/vault/media_player.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

const ChatModel _chat = ChatModel(id: 'chat', name: 'Chat', isDefault: true);
const ChatModel _image = ChatModel(
  id: 'shift-image',
  name: 'SHIFT Image',
  bestFor: <TaskKind>{TaskKind.image},
);
const ChatModel _music = ChatModel(
  id: 'shift-music',
  name: 'SHIFT Music',
  bestFor: <TaskKind>{TaskKind.audio},
);

/// A music model whose answer says "audio" on the attachment, or, with
/// [unlabelled], says nothing and leaves it to the vault row.
class _Engine extends SeedRepository {
  _Engine({this.unlabelled = false, this.allImage = false});

  final bool unlabelled;

  /// The contract's first draft: kind "image" on the answer and the row,
  /// nothing else. Only the model that made it says it is a track.
  final bool allImage;
  final List<({String? model, List<SentFile> files})> sent = [];
  bool made = false;

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
      models: const <ChatModel>[_chat, _image, _music],
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
    sent.add((model: model, files: files));
    if (model != _music.id) {
      return <ChatMessage>[
        ChatMessage(
            id: 'r${sent.length}',
            author: MessageAuthor.shift,
            body: 'Words.',
            model: model),
      ];
    }
    made = true;
    return <ChatMessage>[
      ChatMessage(
        id: 'r${sent.length}',
        author: MessageAuthor.shift,
        body: 'Instrumental track',
        model: model,
        modelName: _music.name,
        attachment: MessageAttachment.tryParse(<String, dynamic>{
          'fileName': unlabelled || allImage ? 'track-1' : 'track-1.mp3',
          'kind': allImage
              ? 'image'
              : unlabelled
                  ? null
                  : 'audio',
          'meta': '2:41',
          'vaultItemId': 'v-song',
        }),
      ),
    ];
  }

  @override
  Future<List<VaultItem>> vault() async => <VaultItem>[
        if (made)
          VaultItem.fromJson(<String, dynamic>{
            ...Seed.vault.first.toJson(),
            'id': 'v-song',
            'title': 'A country song',
            'kind': 'image',
            'mediaType': allImage ? 'image' : 'audio',
            'mediaUrl': 'https://app.example.com/media/song.mp3',
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

Future<AppState> _open(WidgetTester tester, _Engine engine) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final AppState state = await _signedIn(engine);
  await tester.pumpWidget(ShiftApp(state: state));
  await tester.pumpAndSettle();
  final Finder close = find.byTooltip('Close');
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close.first);
    await tester.pumpAndSettle();
  }
  return state;
}

void main() {
  test('a made file is audio by what it is called, its type or its name', () {
    MediaType of(Map<String, dynamic> json) => MessageAttachment.tryParse(
            <String, dynamic>{'vaultItemId': 'v1', ...json})!
        .type;
    expect(of(<String, dynamic>{'fileName': 'a', 'kind': 'audio'}),
        MediaType.audio);
    expect(of(<String, dynamic>{'fileName': 'a', 'kind': 'music'}),
        MediaType.audio);
    expect(of(<String, dynamic>{'fileName': 'a', 'mimeType': 'audio/mpeg'}),
        MediaType.audio);
    expect(of(<String, dynamic>{'fileName': 'song.mp3'}), MediaType.audio);
    expect(
        of(<String, dynamic>{
          'fileName': 'a',
          'url': 'https://x.test/files/track.wav?sig=1',
        }),
        MediaType.audio);
    expect(of(<String, dynamic>{'fileName': 'clip.mp4'}), MediaType.video);
    expect(of(<String, dynamic>{'fileName': 'deck.pdf'}), MediaType.document);
    expect(of(<String, dynamic>{'fileName': 'flower.png'}), MediaType.image);
    expect(of(<String, dynamic>{'fileName': 'flower.png', 'kind': 'image'}),
        MediaType.image);
    // Through a saved chat and back.
    final MessageAttachment song = MessageAttachment.tryParse(
        <String, dynamic>{'fileName': 'song', 'kind': 'audio'})!;
    expect(MessageAttachment.tryParse(song.toJson())!.type, MediaType.audio);
  });

  testWidgets(
      'a made song is played in the thread, not drawn as a picture that '
      'did not load', (WidgetTester tester) async {
    final AppState state = await _open(tester, _Engine());
    state.sendMessage('generate a country song');
    await tester.pumpAndSettle();
    expect(find.byType(AudioPiece), findsOneWidget);
    expect(find.byType(MadePreview), findsNothing);
    expect(find.textContaining('did not load'), findsNothing);
    expect(find.text('Edit image'), findsNothing);
    expect(find.text('Open in Vault'), findsOneWidget);
    final AudioPiece piece = tester.widget(find.byType(AudioPiece));
    expect(piece.url, 'https://app.example.com/media/song.mp3');
  });

  testWidgets('a song the answer did not label is audio by its vault row',
      (WidgetTester tester) async {
    final AppState state = await _open(tester, _Engine(unlabelled: true));
    state.sendMessage('generate a country song');
    await tester.pumpAndSettle();
    expect(find.byType(AudioPiece), findsOneWidget);
    expect(find.byType(MadePreview), findsNothing);
  });

  testWidgets(
      'labelled an image on the answer and the row, a track from SHIFT '
      'Music is still played', (WidgetTester tester) async {
    final AppState state = await _open(tester, _Engine(allImage: true));
    state.sendMessage('generate a country song');
    await tester.pumpAndSettle();
    expect(find.byType(AudioPiece), findsOneWidget);
    expect(find.byType(MadePreview), findsNothing);
  });

  test('"make it slower" after a song is not an edit to a picture', () async {
    final _Engine engine = _Engine();
    final AppState state = await _signedIn(engine);
    state.sendMessage('generate a country song');
    for (int i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    state.sendMessage('make it brighter');
    for (int i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(engine.sent.last.model, isNot(_image.id));
    expect(engine.sent.last.files, isEmpty);
    // Sent back with its turn, the song says what it is.
    expect(state.madeFileOf(state.messages[1])?.mimeType, 'audio/mpeg');
  });
}
