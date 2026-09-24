import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/data/api/api_client.dart';
import 'package:shift_ai/data/api/decode.dart';
import 'package:shift_ai/data/api/http_repository.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/features/settings/avatar.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

const Avatar _training =
    Avatar(id: 'a2', name: 'Studio lighting', status: AvatarStatus.training);
const Avatar _ready = Avatar(
  id: 'a2',
  name: 'Studio lighting',
  status: AvatarStatus.ready,
  previewUrl: 'https://cdn.example.com/a2.png',
);

/// An engine whose avatar list is whatever the test last set, counting
/// how often the gallery asked for it and what was uploaded.
class _Engine extends SeedRepository {
  _Engine(this.list);

  List<Avatar> list;
  int reads = 0;
  final List<String> uploads = <String>[];
  final List<String?> sentAs = <String?>[];

  @override
  Future<List<ChatMessage>> send(
    String prompt, {
    bool private = false,
    String? avatarId,
    String? model,
    List<ChatTurn> history = const <ChatTurn>[],
    Future<void>? cancel,
    void Function(String soFar)? onText,
  }) async {
    sentAs.add(avatarId);
    return <ChatMessage>[
      ChatMessage(
          id: 'r${sentAs.length}', author: MessageAuthor.shift, body: 'Done'),
    ];
  }

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
      avatars: list,
    );
  }

  @override
  Future<List<Avatar>> avatars() async {
    reads++;
    return list;
  }

  @override
  Future<String> upload({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    uploads.add('$fileName $mimeType');
    return 'u1';
  }
}

class _StubAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<(AppState, _Engine)> _signedIn(List<Avatar> avatars) async {
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
  final _Engine engine = _Engine(avatars);
  final AppState state = await AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
  );
  return (state, engine);
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

Future<Uint8List> _png(int w, int h) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF3366CC),
  );
  final ui.Image image = await recorder.endRecording().toImage(w, h);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<void> _openSettings(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(ShiftApp(state: state));
  // The daily-rings sheet opens on its own after a moment; settle so it
  // is up, then close it, or it sits over the gallery.
  await tester.pumpAndSettle();
  final Finder close = find.byTooltip('Close');
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close.first);
    await tester.pumpAndSettle();
  }
  state.setSurface(Surface.settings);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('decoding', () {
    test('a video sent as previewUrl is a clip, never the picture', () {
      final Avatar a = Decode.avatar(<String, dynamic>{
        'id': 'a1',
        'name': 'Everyday',
        'status': 'ready',
        'previewUrl': 'https://cdn.example.com/avatars/a1.mp4?sig=x',
      });
      // Image.network cannot draw an mp4: this used to fall back to
      // initials on the profile, the board and the gallery.
      expect(a.previewUrl, isNull);
      expect(a.clipUrl, 'https://cdn.example.com/avatars/a1.mp4?sig=x');
    });

    test('a still and a clip each land where they belong', () {
      final Avatar a = Decode.avatar(<String, dynamic>{
        'id': 'a1',
        'name': 'Everyday',
        'status': 'ready',
        'previewUrl': 'https://cdn.example.com/a1.png',
        'clipUrl': 'https://cdn.example.com/a1.mp4',
      });
      expect(a.previewUrl, 'https://cdn.example.com/a1.png');
      expect(a.clipUrl, 'https://cdn.example.com/a1.mp4');
    });

    test('a failure carries its reason; an unknown status is not ready', () {
      final Avatar failed = Decode.avatar(<String, dynamic>{
        'id': 'a3',
        'name': 'Hat',
        'status': 'failed',
        'failureReason': 'The face was covered.',
      });
      expect(failed.failureReason, 'The face was covered.');
      final Avatar odd = Decode.avatar(
          <String, dynamic>{'id': 'a4', 'name': 'X', 'status': 'queued'});
      expect(odd.status, AvatarStatus.training);
    });
  });

  test('over HTTP: the list on its own, and consent on the create', () async {
    final List<http.Request> seen = <http.Request>[];
    final HttpRepository repo = HttpRepository(ApiClient(
      baseUrl: 'https://api.example.com',
      client: _Client((http.Request r) {
        seen.add(r);
        return switch ((r.method, r.url.path)) {
          ('GET', '/v1/avatars') => http.Response(
              '{"data":[{"id":"a2","name":"Studio","status":"ready",'
              '"previewUrl":"https://cdn.example.com/a2.png"}]}',
              200),
          ('POST', '/v1/avatars') => http.Response(
              '{"id":"a5","name":"Studio","status":"training"}', 200),
          _ => http.Response('{"message":"no route"}', 404),
        };
      }),
    ));

    final List<Avatar> list = await repo.avatars();
    expect(list.single.ready, isTrue);
    expect(list.single.previewUrl, 'https://cdn.example.com/a2.png');

    await repo.createAvatar(uploadId: 'u1', name: 'Studio');
    expect(jsonDecode(seen.last.body), <String, dynamic>{
      'uploadId': 'u1',
      'name': 'Studio',
      'consent': true,
    });
  });

  test('nothing is uploaded without consent', () async {
    final (AppState state, _Engine engine) = await _signedIn(<Avatar>[]);
    final Avatar? created =
        await state.createAvatar(<int>[1, 2, 3], name: 'Me', consented: false);
    expect(created, isNull);
    expect(engine.uploads, isEmpty);
    expect(state.avatars, isEmpty);
    expect(state.lastError?.message, contains('Confirm the photo is you'));
  });

  test('the upload says what the bytes are', () async {
    final (AppState state, _Engine engine) = await _signedIn(<Avatar>[]);
    await state.createAvatar(
      <int>[1, 2, 3],
      name: 'Me',
      consented: true,
      fileName: 'me.jpg',
      mimeType: 'image/jpeg',
    );
    expect(engine.uploads.single, 'me.jpg image/jpeg');
  });

  group('refreshAvatars', () {
    test('a finished render turns ready, without a full reload', () async {
      final (AppState state, _Engine engine) =
          await _signedIn(<Avatar>[_training]);
      expect(state.avatarsTraining, isTrue);

      engine.list = <Avatar>[_ready];
      await state.refreshAvatars();
      expect(engine.reads, 1);
      expect(state.avatars.single.ready, isTrue);
      expect(state.avatarsTraining, isFalse);
    });

    test('generating as an avatar that is gone falls back to none', () async {
      final (AppState state, _Engine engine) =
          await _signedIn(<Avatar>[_ready]);
      state.setActiveAvatar('a2');
      engine.list = <Avatar>[];
      await state.refreshAvatars();
      expect(state.activeAvatarId, isNull);
    });

    test('the seeded catalogue never asks: nothing trains it', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final AppState state =
          await AppState.load(tokenStore: MemoryTokenStore());
      expect(state.seededDemo, isTrue);
      final List<Avatar> before = state.avatars;
      await state.refreshAvatars();
      expect(state.avatars, same(before));
    });
  });

  testWidgets(
      'the gallery re-reads while one trains, and stops once it is ready',
      (WidgetTester tester) async {
    final (AppState state, _Engine engine) =
        await _signedIn(<Avatar>[_training]);
    await _openSettings(tester, state);

    expect(find.text('Training…'), findsOneWidget);
    // Once straight away, on opening the gallery.
    expect(engine.reads, 1);

    await tester.pump(const Duration(seconds: 15));
    expect(engine.reads, 2);

    // No picture: the test binding answers every network image with 400.
    engine.list = <Avatar>[
      const Avatar(
          id: 'a2', name: 'Studio lighting', status: AvatarStatus.ready),
    ];
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(find.text('Training…'), findsNothing);
    expect(find.text('Ready'), findsOneWidget);

    // Nothing training: no more asking.
    final int settled = engine.reads;
    await tester.pump(const Duration(minutes: 1));
    expect(engine.reads, settled);
  });

  testWidgets('a failed avatar says why', (WidgetTester tester) async {
    final (AppState state, _) = await _signedIn(<Avatar>[
      const Avatar(
        id: 'a3',
        name: 'Hat',
        status: AvatarStatus.failed,
        failureReason: 'The face was covered.',
      ),
    ]);
    await _openSettings(tester, state);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('The face was covered.'), findsOneWidget);
  });

  group('the photo', () {
    testWidgets('too small to train from is refused with the size',
        (WidgetTester tester) async {
      final PreparedPhoto p = (await tester.runAsync(() async =>
          prepareAvatarPhoto(await _png(120, 300),
              fileName: 'tiny.png', mimeType: 'image/png')))!;
      expect(p.bytes, isNull);
      expect(p.problem, contains('120 × 300'));
    });

    testWidgets('a sensible size goes up as it is, typed by what it is',
        (WidgetTester tester) async {
      final Uint8List source = (await tester.runAsync(() => _png(600, 800)))!;
      final PreparedPhoto p = (await tester.runAsync(() => prepareAvatarPhoto(
          source,
          fileName: 'me.png',
          mimeType: 'application/octet-stream')))!;
      expect(p.bytes, same(source));
      expect(p.mimeType, 'image/png');
      expect(p.fileName, 'me.png');
    });

    testWidgets('a huge one is scaled to 2048 and re-typed as PNG',
        (WidgetTester tester) async {
      final PreparedPhoto p = (await tester.runAsync(() async =>
          prepareAvatarPhoto(await _png(4000, 1000),
              fileName: 'big.jpg', mimeType: 'image/jpeg')))!;
      expect(p.mimeType, 'image/png');
      expect(p.fileName, 'big.png');
      final ui.Image decoded = (await tester.runAsync(() async {
        final ui.Codec codec = await ui.instantiateImageCodec(p.bytes!);
        return (await codec.getNextFrame()).image;
      }))!;
      expect(decoded.width, kAvatarMaxSide);
      expect(decoded.height, 512);
    });

    testWidgets('something that is not a picture says so',
        (WidgetTester tester) async {
      final PreparedPhoto p = (await tester.runAsync(() => prepareAvatarPhoto(
          Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'notes.txt',
          mimeType: 'text/plain')))!;
      expect(p.bytes, isNull);
      expect(p.problem, contains('Could not read notes.txt'));
    });
  });

  group('the built-in avatar', () {
    test('ships with the app, ready, and is nobody\'s own', () async {
      const Avatar builtIn = BuiltInAvatars.shiftai;
      expect(builtIn.ready, isTrue);
      expect(builtIn.personal, isFalse);
      expect(builtIn.asset, 'assets/avatars/shiftai-default.jpg');

      // Not in the person's list, so never their profile picture or
      // leaderboard face: with no avatar of their own, that stays initials.
      final (AppState state, _) = await _signedIn(<Avatar>[]);
      expect(state.avatars, isEmpty);
      expect(state.personalAvatar, isNull);
    });

    testWidgets('the gallery shows her, built in, under your own',
        (WidgetTester tester) async {
      final (AppState state, _) = await _signedIn(<Avatar>[]);
      await _openSettings(tester, state);
      expect(find.text('No avatars yet'), findsOneWidget);
      expect(find.text('ShiftAi default'), findsOneWidget);
      expect(find.textContaining('generates as her until you pick'),
          findsOneWidget);
      expect(
        find.byWidgetPredicate((Widget w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName ==
                'assets/avatars/shiftai-default.jpg'),
        findsOneWidget,
      );
    });

    testWidgets(
        '"Generate as" offers her first; choosing her sends no avatarId, '
        'choosing yours sends its id', (WidgetTester tester) async {
      final (AppState state, _Engine engine) = await _signedIn(<Avatar>[
        const Avatar(id: 'a2', name: 'Everyday', status: AvatarStatus.ready),
      ]);
      await tester.pumpWidget(ShiftApp(state: state));
      await tester.pumpAndSettle();
      final Finder close = find.byTooltip('Close');
      if (close.evaluate().isNotEmpty) {
        await tester.tap(close.first);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byTooltip('Generating as ShiftAi default'));
      await tester.pumpAndSettle();
      expect(find.text('ShiftAi default'), findsOneWidget);
      expect(find.text('Built in'), findsOneWidget);
      expect(find.text('Everyday'), findsOneWidget);
      // She is above your own, and ticked while nothing else is chosen.
      expect(
        tester.getTopLeft(find.text('ShiftAi default')).dy,
        lessThan(tester.getTopLeft(find.text('Everyday')).dy),
      );
      expect(
        find.descendant(
          of: find.ancestor(
              of: find.text('ShiftAi default'),
              matching: find.byType(ListTile)),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('ShiftAi default'));
      await tester.pumpAndSettle();
      expect(state.sendMessage('Make an intro'), isTrue);
      await tester.pumpAndSettle();
      expect(engine.sentAs.last, isNull);

      await tester.tap(find.byTooltip('Generating as ShiftAi default'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Everyday'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Generating as Everyday'), findsOneWidget);
      state.sendMessage('Another');
      await tester.pumpAndSettle();
      expect(engine.sentAs.last, 'a2');
    });
  });
}
