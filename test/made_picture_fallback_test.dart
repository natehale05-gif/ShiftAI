import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/data/api/api_client.dart';
import 'package:shift_ai/data/api/http_repository.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/theme/app_theme.dart';
import 'package:shift_ai/theme/tokens.dart';
import 'package:shift_ai/widgets/made_preview.dart';
import 'package:shift_ai/widgets/markdown_text.dart';

/// Makes a picture whose vault row is saved [lateBy] vault reads after the
/// answer, or never, and whose answer may name it by another id.
class _Engine extends SeedRepository {
  _Engine({this.lateBy = 0, this.never = false, this.answerId = 'v-flower'});

  final int lateBy;
  final bool never;
  final String answerId;
  int reads = 0;
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
          vaultItemId: answerId,
        ),
      ),
    ];
  }

  @override
  Future<List<VaultItem>> vault() async {
    if (made) reads++;
    return <VaultItem>[
      if (made && !never && reads > lateBy)
        VaultItem.fromJson(<String, dynamic>{
          ...Seed.vault.first.toJson(),
          'id': 'v-flower',
          'title': 'A pink flower',
          'kind': 'image',
          'mediaUrl': 'https://cdn.example.com/u/image-94be8963.png',
        }),
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

Future<void> _waitFor(bool Function() done) async {
  for (int i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Answers one route with [body]; everything else empty.
class _Server extends http.BaseClient {
  _Server(this.path, this.body);
  final String path;
  final Object body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        Stream<List<int>>.value(utf8
            .encode(jsonEncode(request.url.path == path ? body : <Object?>[]))),
        200,
        request: request,
        headers: <String, String>{'content-type': 'application/json'},
      );
}

/// One red pixel, as an engine sending the picture inline would.
const String _pixel = 'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==';

void main() {
  final List<Duration> waits = AppState.vaultWaits;
  setUp(() => AppState.vaultWaits = const <Duration>[
        Duration(milliseconds: 1),
        Duration(milliseconds: 1),
        Duration(milliseconds: 1),
      ]);
  tearDown(() => AppState.vaultWaits = waits);

  test(
      'a vault row saved after the answer is still found: the vault is read '
      'again until it is there', () async {
    AppState.vaultWaits = const <Duration>[
      Duration(milliseconds: 40),
      Duration(milliseconds: 40),
      Duration(milliseconds: 40),
    ];
    final _Engine engine = _Engine(lateBy: 2);
    final AppState state = await _signedIn(engine);
    state.sendMessage('Write a caption');
    await _waitFor(() => engine.reads >= 1);
    expect(state.lookingInVault('r1'), isTrue);

    await _waitFor(() => !state.lookingInVault('r1'));
    expect(engine.reads, 3, reason: 'it used to read the vault once');
    final MessageAttachment made = state.messages.last.attachment!;
    expect(state.vaultRowOf(made)?.id, 'v-flower');
    expect(state.notInVault('r1'), isFalse);
  });

  test('a row that never comes is said, not waited on for good', () async {
    final _Engine engine = _Engine(never: true);
    final AppState state = await _signedIn(engine);
    state.sendMessage('Write a caption');
    await _waitFor(() => state.notInVault('r1'));
    expect(state.notInVault('r1'), isTrue);
    expect(state.lookingInVault('r1'), isFalse);
    expect(engine.reads, AppState.vaultWaits.length + 1);
  });

  test(
      'an answer naming the picture by another id finds its row by file '
      'name', () async {
    final _Engine engine = _Engine(answerId: 'job-31');
    final AppState state = await _signedIn(engine);
    state.sendMessage('Write a caption');
    await _waitFor(() => engine.reads >= 1 && !state.lookingInVault('r1'));
    final ChatMessage reply = state.messages.last;
    expect(state.vaultRowOf(reply.attachment!)?.id, 'v-flower');
    // Edits and later turns name the row the vault knows.
    expect(state.madeFileOf(reply)?.vaultItemId, 'v-flower');
    expect(state.madeFileOf(reply)?.url,
        'https://cdn.example.com/u/image-94be8963.png');
  });

  test('a name with nothing particular in it matches nothing', () async {
    final AppState state = await _signedIn(_Engine());
    state.vault = <VaultItem>[
      VaultItem.fromJson(<String, dynamic>{
        ...Seed.vault.first.toJson(),
        'id': 'v1',
        'mediaUrl': 'https://cdn.example.com/image.png',
      }),
    ];
    const MessageAttachment plain = MessageAttachment(
      fileName: 'image.png',
      meta: '',
      kind: MediaKind.image,
      vaultItemId: 'job-1',
    );
    expect(state.vaultRowOf(plain), isNull);
  });

  test('the link is read under the names image APIs give it', () {
    for (final String key in <String>[
      'url',
      'mediaUrl',
      'imageUrl',
      'image_url',
      'fileUrl',
      'downloadUrl',
      'src',
    ]) {
      final MessageAttachment a = MessageAttachment.tryParse(<String, dynamic>{
        'fileName': 'f.png',
        'vaultItemId': 'v1',
        key: 'https://x.test/f.png',
      })!;
      expect(a.url, 'https://x.test/f.png', reason: key);
    }
    // No file name: the link's own name stands in, rather than the whole
    // attachment being dropped.
    final MessageAttachment unnamed =
        MessageAttachment.tryParse(<String, dynamic>{
      'imageUrl': 'https://x.test/a/flower-1.png?sig=1',
    })!;
    expect(unnamed.fileName, 'flower-1.png');
    expect(
        MessageAttachment.tryParse(<String, dynamic>{'name': 'g.png'})
            ?.fileName,
        'g.png');
  });

  test('links relative to the engine are made whole against it', () async {
    final HttpRepository vault = HttpRepository(ApiClient(
      baseUrl: 'https://app.example.com/preview/api',
      client: _Server('/preview/api/v1/vault', <Map<String, dynamic>>[
        <String, dynamic>{
          ...Seed.vault.first.toJson(),
          'mediaUrl': '/media/flower.png',
          'thumbnailUrl': 'thumbs/flower.webp',
        },
      ]),
    ));
    final VaultItem row = (await vault.vault()).single;
    expect(row.mediaUrl, 'https://app.example.com/media/flower.png');
    expect(row.thumbnailUrl,
        'https://app.example.com/preview/api/thumbs/flower.webp');

    final HttpRepository chat = HttpRepository(ApiClient(
      baseUrl: 'https://app.example.com/preview/api',
      client: _Server('/preview/api/v1/messages', <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'm1',
          'author': 'shift',
          'body': 'Here it is.',
          'attachment': <String, dynamic>{
            'fileName': 'flower.png',
            'vaultItemId': 'v1',
            'url': '/media/flower.png',
          },
        },
      ]),
    ));
    final List<ChatMessage> answer = await chat.send('a flower');
    expect(answer.single.attachment?.url,
        'https://app.example.com/media/flower.png');
    // A whole link, and inline data, are left as they are.
    expect(
        MessageAttachment.tryParse(<String, dynamic>{
          'fileName': 'f.png',
          'url': _pixel,
        })!
            .url,
        _pixel);
  });

  test('a picture linked in the answer\'s words is drawn, not shown as source',
      () {
    List<MdBlock> parse(String s) => MdBlock.parse(s);
    final MdImage md =
        parse('Here it is.\n\n![A pink flower](https://x.test/f.png)').last
            as MdImage;
    expect(md.url, 'https://x.test/f.png');
    expect(md.alt, 'A pink flower');
    final MdImage bare =
        parse('https://x.test/a/f.webp?sig=2').single as MdImage;
    expect(bare.url, 'https://x.test/a/f.webp?sig=2');
    expect(parse(_pixel).single, isA<MdImage>());
    // A link to a page is still a link in a sentence.
    expect(parse('https://x.test/page').single, isA<MdParagraph>());
    expect(parse('See [the file](https://x.test/f.png).').single,
        isA<MdParagraph>());
  });

  testWidgets(
      'a full picture that will not load gives way to the next link, and '
      'with none left says why', (WidgetTester tester) async {
    Future<void> show(List<String> urls) async {
      await tester.pumpWidget(MaterialApp(
        theme: ShiftTheme.build(ShiftThemeId.values.first),
        home: Scaffold(
          body: MadePreview(
            urls: urls,
            aspect: 1,
            video: false,
            label: 'flower.png',
          ),
        ),
      ));
      // The test HTTP client answers 400 to everything, on the real clock.
      for (int i = 0; i < 4; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    await show(<String>['https://x.test/full.png', _pixel]);
    expect(
      find.byWidgetPredicate(
          (Widget w) => w is Image && w.image is MemoryImage),
      findsOneWidget,
      reason: 'the second link is drawn once the first fails',
    );
    expect(find.textContaining('did not load'), findsNothing);

    await show(<String>['https://x.test/full.png', 'https://x.test/t.png']);
    expect(find.textContaining('did not load'), findsOneWidget);
    expect(find.text('HTTP 400 from x.test'), findsOneWidget);
  });

  testWidgets('a reply with a picture in its words draws it',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ShiftTheme.build(ShiftThemeId.values.first),
      home: const Scaffold(
        body: MarkdownText('Made it.\n\n![A pink flower]($_pixel)'),
      ),
    ));
    expect(find.text('Made it.', findRichText: true), findsOneWidget);
    expect(find.textContaining('![', findRichText: true), findsNothing);
    expect(find.bySemanticsLabel('A pink flower'), findsOneWidget);
  });
}
