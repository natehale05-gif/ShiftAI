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
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

const ChatModel _chat = ChatModel(id: 'chat', name: 'Chat', isDefault: true);
const ChatModel _image = ChatModel(
  id: 'shift-image',
  name: 'SHIFT Image',
  bestFor: <TaskKind>{TaskKind.image},
);

/// An image model that makes v-1, v-2, ...; [marks] says whether it puts
/// `editedFrom` on an edit, as the contract asks.
class _Engine extends SeedRepository {
  _Engine({required this.marks});

  final bool marks;
  int made = 0;

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
      models: const <ChatModel>[_chat, _image],
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
    made++;
    final String? source = files
        .where((SentFile f) => f.vaultItemId != null)
        .firstOrNull
        ?.vaultItemId;
    return <ChatMessage>[
      ChatMessage(
        id: 'r$made',
        author: MessageAuthor.shift,
        body: prompt,
        model: model,
        modelName: _image.name,
        attachment: MessageAttachment(
          fileName: 'image-$made.png',
          meta: '1024 × 1024',
          kind: MediaKind.image,
          vaultItemId: 'v-$made',
          url: 'https://app.example.com/media/$made.png',
          editedFrom: marks ? source : null,
        ),
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

Future<AppState> _open(WidgetTester tester, _Engine engine) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
  final AppState state = await AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
  );
  await tester.pumpWidget(ShiftApp(state: state));
  await tester.pumpAndSettle();
  final Finder close = find.byTooltip('Close');
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close.first);
    await tester.pumpAndSettle();
  }
  return state;
}

Future<void> _flowerThenEdit(WidgetTester tester, AppState state) async {
  state.sendMessage('Generate an image of a pink flower');
  await tester.pumpAndSettle();
  state.sendMessage('make one of the petals blue');
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an edit the server marks says what it was changed from',
      (WidgetTester tester) async {
    final AppState state = await _open(tester, _Engine(marks: true));
    await _flowerThenEdit(tester, state);
    expect(state.messages.last.attachment?.editedFrom, 'v-1');
    expect(find.text('Edited from image-1.png'), findsOneWidget);
    expect(find.textContaining('may have made a new picture'), findsNothing);
  });

  testWidgets(
      'an edit that comes back unmarked says it may be a new picture, not '
      'the edit', (WidgetTester tester) async {
    final AppState state = await _open(tester, _Engine(marks: false));
    await _flowerThenEdit(tester, state);
    // The first picture was made from words; nothing to say under it.
    expect(state.editNotConfirmed(state.messages[1]), isFalse);
    expect(state.editNotConfirmed(state.messages.last), isTrue);
    expect(
        find.text('SHIFT Image may have made a new picture rather than '
            'changing yours: it did not say it edited the one you sent.'),
        findsOneWidget);
    expect(find.textContaining('Edited from'), findsNothing);
  });

  test('editedFrom survives a saved chat', () {
    final MessageAttachment a = MessageAttachment.tryParse(<String, dynamic>{
      'fileName': 'image-2.png',
      'vaultItemId': 'v-2',
      'editedFrom': 'v-1',
    })!;
    expect(MessageAttachment.tryParse(a.toJson())!.editedFrom, 'v-1');
  });
}
