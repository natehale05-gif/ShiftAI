import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/features/chat/suite_surface.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

/// Answers with a made image whose file is only on its vault row, the way
/// the preview did for "generate an image of a pink flower".
class _Engine extends SeedRepository {
  _Engine({this.onAnswer});

  final String? onAnswer;
  bool made = false;

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
    made = true;
    return <ChatMessage>[
      ChatMessage(
        id: 'r1',
        author: MessageAuthor.shift,
        body: 'Here it is.',
        attachment: MessageAttachment(
          fileName: 'image-94be8963.png',
          meta: '1024 × 1024',
          kind: MediaKind.image,
          vaultItemId: 'v-flower',
          url: onAnswer,
        ),
      ),
    ];
  }

  @override
  Future<List<VaultItem>> vault() async => <VaultItem>[
        if (made)
          VaultItem.fromJson(<String, dynamic>{
            ...Seed.vault.first.toJson(),
            'id': 'v-flower',
            'kind': 'image',
            'mediaType': 'image',
            'aspect': 1.0,
            'mediaUrl': 'https://app.example.com/media/flower.png',
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
  tester.view.physicalSize = const Size(1000, 1400);
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

void main() {
  testWidgets(
      'a made image is shown in the thread, from its vault row, not only '
      'its file name', (WidgetTester tester) async {
    final AppState state = await _open(tester, _Engine());
    state.sendMessage('Write a caption');
    await tester.pumpAndSettle();

    final MadePreview preview =
        tester.widget<MadePreview>(find.byType(MadePreview));
    expect(preview.url, 'https://app.example.com/media/flower.png');
    // What can be done with it, under it: the file-name card it used to
    // be is not repeated.
    expect(find.text('Edit image'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Open in Vault'), findsOneWidget);
  });

  testWidgets('a link on the answer itself is used first',
      (WidgetTester tester) async {
    final AppState state = await _open(
        tester, _Engine(onAnswer: 'https://cdn.example.com/flower-full.png'));
    state.sendMessage('Write a caption');
    await tester.pumpAndSettle();
    expect(tester.widget<MadePreview>(find.byType(MadePreview)).url,
        'https://cdn.example.com/flower-full.png');
  });

  test('the attachment keeps its links through a saved chat', () {
    final MessageAttachment a = MessageAttachment.tryParse(<String, dynamic>{
      'fileName': 'f.png',
      'kind': 'image',
      'vaultItemId': 'v1',
      'mediaUrl': 'https://x.test/f.png',
      'thumbnailUrl': 'https://x.test/f-small.webp',
    })!;
    expect(a.url, 'https://x.test/f.png');
    final MessageAttachment back = MessageAttachment.tryParse(a.toJson())!;
    expect(back.url, a.url);
    expect(back.thumbnailUrl, 'https://x.test/f-small.webp');
  });
}
