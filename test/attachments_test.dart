import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:shift_ai/util/picked_file.dart';

/// Takes uploads and answers messages, recording both.
class _Engine extends SeedRepository {
  final List<String> uploaded = <String>[];
  final List<List<SentFile>> sentWith = <List<SentFile>>[];
  final List<List<ChatTurn>> histories = <List<ChatTurn>>[];
  bool refuseUploads = false;

  @override
  Future<String> upload({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    if (refuseUploads) {
      throw const ShiftApiException(
        ShiftApiErrorKind.badRequest,
        'That file is too large.',
        status: 413,
      );
    }
    uploaded.add(fileName);
    return 'u-$fileName';
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
    sentWith.add(files);
    histories.add(history);
    return <ChatMessage>[
      ChatMessage(
        id: 'r${sentWith.length}',
        author: MessageAuthor.shift,
        body: 'Seen ${files.length} files',
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

PickedFile _file(String name, String mime) => PickedFile(
      name: name,
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      mimeType: mime,
    );

Future<void> _settle() async {
  for (int i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
      'attached files are uploaded, then go to the model by id, not as '
      'their names in the text', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    expect(
      state.sendMessage('What is in these?', files: <PickedFile>[
        _file('ferry.png', 'image/png'),
        _file('brief.pdf', 'application/pdf'),
      ]),
      isTrue,
    );
    // On screen at once, still going up.
    expect(
        state.messages.first.files.every((SentFile f) => f.uploading), isTrue);
    await _settle();

    expect(engine.uploaded, <String>['ferry.png', 'brief.pdf']);
    expect(
      engine.sentWith.single.map((SentFile f) => f.uploadId),
      <String>['u-ferry.png', 'u-brief.pdf'],
    );
    final ChatMessage asked = state.messages.first;
    expect(asked.body, 'What is in these?',
        reason: 'the names are no longer pasted into the prompt');
    expect(asked.files.map((SentFile f) => f.uploadId),
        <String>['u-ferry.png', 'u-brief.pdf']);
    expect(state.messages.last.body, 'Seen 2 files');
  });

  test('a file on its own, with no words, still sends', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    expect(
      state.sendMessage('', files: <PickedFile>[_file('a.png', 'image/png')]),
      isTrue,
    );
    await _settle();
    expect(engine.sentWith.single.single.uploadId, 'u-a.png');
  });

  test('a file that will not upload sends nothing and says why', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    engine.refuseUploads = true;
    state.sendMessage('Look',
        files: <PickedFile>[_file('big.mov', 'video/mp4')]);
    await _settle();
    expect(engine.sentWith, isEmpty, reason: 'no model was asked');
    expect(state.messages.last.failure?.sentence, 'Could not upload big.mov.');
    expect(state.messages.first.files, isEmpty,
        reason: 'a file that never went up is not shown as sent');
    expect(state.thinking, isFalse);
  });

  test('Retry and Edit send the same files again without re-uploading',
      () async {
    final (AppState state, _Engine engine) = await _signedIn();
    state.sendMessage('Caption this',
        files: <PickedFile>[_file('ferry.png', 'image/png')]);
    await _settle();
    expect(engine.uploaded, hasLength(1));

    state.regenerate(replyId: state.messages.last.id);
    await _settle();
    expect(engine.uploaded, hasLength(1));
    expect(engine.sentWith.last.single.uploadId, 'u-ferry.png');

    state.editMessage(state.messages.first.id, 'Caption this, shorter');
    await _settle();
    expect(engine.uploaded, hasLength(1));
    expect(engine.sentWith.last.single.uploadId, 'u-ferry.png');
    expect(state.messages.first.body, 'Caption this, shorter');
  });

  test('a later message carries earlier files in its history', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    state.sendMessage('Caption this',
        files: <PickedFile>[_file('ferry.png', 'image/png')]);
    await _settle();
    state.sendMessage('Shorter');
    await _settle();
    final ChatTurn first = engine.histories.last.first;
    expect(first.files.single.uploadId, 'u-ferry.png');
    expect(first.toJson()['attachments'], isNotEmpty);
  });

  test('the request body names the files by upload id', () async {
    late Map<String, dynamic> sent;
    final ApiClient api = ApiClient(
      baseUrl: 'https://api.example.com',
      client: MockClient((http.Request request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(<Object>[
            <String, String>{'id': 'm1', 'author': 'shift', 'body': 'ok'},
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );
    await HttpRepository(api).send('What is this?', files: const <SentFile>[
      SentFile(uploadId: 'u1', name: 'ferry.png', mimeType: 'image/png'),
    ]);
    expect(sent['attachments'], <Object>[
      <String, String>{
        'uploadId': 'u1',
        'name': 'ferry.png',
        'mimeType': 'image/png',
      },
    ]);
    expect(sent['prompt'], 'What is this?');
  });

  test('saved chats keep the files, and drop one still uploading', () {
    const ChatMessage m = ChatMessage(
      id: 'you-1',
      author: MessageAuthor.you,
      body: 'Look',
      files: <SentFile>[
        SentFile(uploadId: 'u1', name: 'a.png', mimeType: 'image/png'),
        SentFile(uploadId: '', name: 'b.png', mimeType: 'image/png'),
      ],
    );
    final ChatMessage back = ChatMessage.fromJson(m.toJson());
    expect(back.files.map((SentFile f) => f.name), <String>['a.png']);
  });
}
