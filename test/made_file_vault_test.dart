import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

/// Answers with a made file, which it has just put in its vault.
class _Engine extends SeedRepository {
  _Engine(this.fileId);

  final String fileId;
  int vaultReads = 0;
  bool made = false;

  VaultItem get _made => VaultItem.fromJson(
      <String, dynamic>{...Seed.vault.first.toJson(), 'id': fileId});

  @override
  Future<List<ChatMessage>> send(
    String prompt, {
    bool private = false,
    String? avatarId,
    String? model,
    List<ChatTurn> history = const <ChatTurn>[],
    Future<void>? cancel,
  }) async {
    made = true;
    return <ChatMessage>[
      ChatMessage(
        id: 'r1',
        author: MessageAuthor.shift,
        body: 'Here it is.',
        attachment: MessageAttachment(
          fileName: 'miami.png',
          meta: '1024 × 1024',
          kind: MediaKind.image,
          vaultItemId: fileId,
        ),
      ),
    ];
  }

  @override
  Future<List<VaultItem>> vault() async {
    vaultReads++;
    final List<VaultItem> mine = await super.vault();
    return <VaultItem>[
      if (made && !mine.any((VaultItem v) => v.id == fileId)) _made,
      ...mine,
    ];
  }
}

class _StubAuth implements AuthService {
  @override
  Future<void> signOut(String refreshToken) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<(AppState, _Engine)> _signedIn(String fileId) async {
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
  final _Engine engine = _Engine(fileId);
  final AppState state = await AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
  );
  return (state, engine);
}

Future<void> _settle() async {
  for (int i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
      'a made file the vault on screen has not got is read in, so '
      '"Open in Vault" finds it', () async {
    final (AppState state, _Engine engine) = await _signedIn('v-new');
    expect(state.vault.any((VaultItem v) => v.id == 'v-new'), isFalse);
    state.sendMessage('Write the launch post');
    await _settle();
    expect(engine.vaultReads, 1);
    expect(state.vault.any((VaultItem v) => v.id == 'v-new'), isTrue);
  });

  test('a file already in the vault costs no extra read', () async {
    final (AppState state, _Engine engine) =
        await _signedIn(Seed.vault.first.id);
    state.sendMessage('Write the launch post');
    await _settle();
    expect(state.messages.last.attachment, isNotNull);
    expect(engine.vaultReads, 0);
  });
}
