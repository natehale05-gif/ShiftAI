import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/data/api/api_client.dart';
import 'package:shift_ai/data/api/http_repository.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/repository.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/util/prompt.dart';

/// An engine whose polisher answers whatever the test says: a rewrite, or
/// a refusal.
class _Engine extends SeedRepository {
  String Function(String prompt)? rewrite;
  ShiftApiException? refuse;
  Completer<void>? gate;
  final List<String> asked = <String>[];

  @override
  Future<String> polish(String prompt) async {
    asked.add(prompt);
    await gate?.future;
    if (refuse != null) throw refuse!;
    return rewrite?.call(prompt) ?? super.polish(prompt);
  }
}

class _StubAuth implements AuthService {
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

/// A chat answer from the engine, as /v1/messages sends one.
http.Response _reply(String body) => http.Response(
      jsonEncode(<Map<String, String>>[
        <String, String>{'id': 'p1', 'author': 'shift', 'body': body},
      ]),
      200,
    );

HttpRepository _over(http.Response Function(http.Request) route) =>
    HttpRepository(ApiClient(
      baseUrl: 'https://api.example.com',
      client: _Client(route),
    ));

Future<void> _dismissRingsSheet(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final Finder close = find.byTooltip('Close');
  if (close.evaluate().isEmpty) return;
  await tester.tap(close.first);
  await tester.pumpAndSettle();
}

Finder get _field => find.byType(TextField).last;

String _text(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!.text;

IconButton _sparkle(WidgetTester tester) => tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Polish my prompt'),
        matching: find.byType(IconButton),
      ),
    );

void main() {
  group('over HTTP', () {
    test('posts {prompt} to /v1/polish and uses the {prompt} it answers',
        () async {
      final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];
      final HttpRepository repo = _over((http.Request r) {
        expect(r.url.path, '/v1/polish');
        expect(r.method, 'POST');
        bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
        return http.Response('{"prompt":"A sharper brief."}', 200);
      });
      expect(await repo.polish('make a poster'), 'A sharper brief.');
      expect(bodies.single, <String, dynamic>{'prompt': 'make a poster'});
    });

    test(
        'an engine without a polisher: 404 and 405 are polished by the AI, '
        'privately, through the chat route', () async {
      for (final int status in <int>[404, 405]) {
        final List<Map<String, dynamic>> chats = <Map<String, dynamic>>[];
        final HttpRepository repo = _over((http.Request r) {
          if (r.url.path == '/v1/messages') {
            chats.add(jsonDecode(r.body) as Map<String, dynamic>);
            return _reply('Write a 20 second vertical promo video.');
          }
          return http.Response('{"message":"no route"}', status);
        });
        final String out = await repo.polish('make me a promo video');
        expect(out, 'Write a 20 second vertical promo video.',
            reason: '$status');
        // One private message, nothing before it, carrying the prompt and
        // the ask to reply with the rewrite alone.
        final Map<String, dynamic> sent = chats.single;
        expect(sent['private'], isTrue);
        expect(sent['history'], isEmpty);
        expect(sent['prompt'], contains('make me a promo video'));
        expect(sent['prompt'], contains('Reply with the rewritten prompt'));
      }
    });

    test(
        'an echo is no polish: "What time is it" coming back as itself goes '
        'to the AI, not to a template', () async {
      final HttpRepository repo = _over((http.Request r) {
        if (r.url.path == '/v1/messages') {
          return _reply('What time is it right now in my time zone?');
        }
        final String sent =
            (jsonDecode(r.body) as Map<String, dynamic>)['prompt'] as String;
        return http.Response(jsonEncode(<String, String>{'prompt': sent}), 200);
      });
      expect(await repo.polish('What time is it'),
          'What time is it right now in my time zone?');
    });

    test('the rewrite is found whatever it is called, and inside data',
        () async {
      for (final String body in <String>[
        '{"prompt":"make a poster","polished":"A bold poster."}',
        '{"prompt":"make a poster","polishedPrompt":"A bold poster."}',
        '{"data":{"prompt":"make a poster","polished_prompt":"A bold poster."}}',
        '{"data":{"prompt":"A bold poster."}}',
        '{"result":"A bold poster."}',
        '"A bold poster."',
      ]) {
        final HttpRepository repo = _over((_) => http.Response(body, 200));
        expect(await repo.polish('make a poster'), 'A bold poster.',
            reason: body);
      }
    });

    test('an answer with nothing usable in it goes to the AI too', () async {
      for (final String body in <String>['{}', '{"prompt":"  "}', '[]']) {
        final HttpRepository repo = _over((http.Request r) =>
            r.url.path == '/v1/messages'
                ? _reply('Write a caption for the ferry clip.')
                : http.Response(body, 200));
        expect(await repo.polish('write a caption'),
            'Write a caption for the ferry clip.',
            reason: body);
      }
    });

    test('the AI\'s preamble, quotes and fences are taken off the rewrite', () {
      for (final String raw in <String>[
        'Here is the polished prompt: Write a caption.',
        "Here's a rewritten version:\nWrite a caption.",
        'Polished prompt:\n"Write a caption."',
        '```\nWrite a caption.\n```',
        '\u201cWrite a caption.\u201d',
        'Sure! Here is your improved prompt: Write a caption.',
      ]) {
        expect(HttpRepository.cleanRewrite(raw), 'Write a caption.',
            reason: raw);
      }
      expect(HttpRepository.cleanRewrite('  '), isNull);
    });

    test(
        'when the AI refuses or sends nothing, the bar says so rather than '
        'showing a template', () async {
      final HttpRepository refused = _over((http.Request r) =>
          r.url.path == '/v1/messages'
              ? http.Response('{"message":"You are out of credits."}', 402)
              : http.Response('{"message":"no route"}', 404));
      await expectLater(
        refused.polish('write a caption'),
        throwsA(isA<ShiftApiException>().having(
            (ShiftApiException e) => e.message,
            'message',
            'You are out of credits.')),
      );

      final HttpRepository silent = _over((http.Request r) =>
          r.url.path == '/v1/messages'
              ? _reply('   ')
              : http.Response('{"message":"no route"}', 404));
      await expectLater(
        silent.polish('write a caption'),
        throwsA(isA<ShiftApiException>()),
      );
    });

    test('a real refusal is not hidden behind the local brief', () async {
      final HttpRepository repo =
          _over((_) => http.Response('{"message":"Out of credits."}', 402));
      await expectLater(
        repo.polish('write a caption'),
        throwsA(isA<ShiftApiException>().having(
            (ShiftApiException e) => e.message, 'message', 'Out of credits.')),
      );
    });
  });

  test(
      'polishing never touches lastError, which the board and the shelf '
      'read to say they did not load', () async {
    final (AppState state, _Engine engine) = await _signedIn();
    const ShiftApiException loadFailed =
        ShiftApiException(ShiftApiErrorKind.offline, 'Board did not load.');

    // A load error survives a polish that worked…
    state.lastError = loadFailed;
    final ({String text, ShiftApiException? error}) ok =
        await state.polishPrompt('write a caption');
    expect(ok.error, isNull);
    expect(Prompt.isPolished(ok.text), isTrue);
    expect(state.lastError, same(loadFailed));

    // …and a polish that failed does not invent one.
    state.lastError = null;
    engine.refuse =
        const ShiftApiException(ShiftApiErrorKind.server, 'Polisher down.');
    final ({String text, ShiftApiException? error}) failed =
        await state.polishPrompt('write a caption');
    expect(failed.text, 'write a caption');
    expect(failed.error?.message, 'Polisher down.');
    expect(state.lastError, isNull);
  });

  testWidgets('the sparkle is off until there is something to polish',
      (WidgetTester tester) async {
    final (AppState state, _Engine engine) = await _signedIn();
    await tester.pumpWidget(ShiftApp(state: state));
    await _dismissRingsSheet(tester);

    expect(_sparkle(tester).onPressed, isNull);
    await tester.enterText(_field, '   ');
    await tester.pump();
    expect(_sparkle(tester).onPressed, isNull);

    await tester.enterText(_field, 'make a poster');
    await tester.pump();
    expect(_sparkle(tester).onPressed, isNotNull);
    expect(engine.asked, isEmpty);
  });

  testWidgets('a polish says so, and Undo puts back what you typed',
      (WidgetTester tester) async {
    final (AppState state, _Engine engine) = await _signedIn();
    engine.rewrite = (String p) =>
        'Brief: $p.\nAudience: passers-by.\nTone: bold.\nDeliver: one image.';
    await tester.pumpWidget(ShiftApp(state: state));
    await _dismissRingsSheet(tester);

    await tester.enterText(_field, 'make a poster ');
    await tester.pump();
    await tester.tap(find.byTooltip('Polish my prompt'));
    await tester.pumpAndSettle();

    // Sent trimmed; nothing went out as a message.
    expect(engine.asked.single, 'make a poster');
    expect(state.messages, isEmpty);
    expect(_text(tester),
        'Brief: make a poster.\nAudience: passers-by.\nTone: bold.\nDeliver: one image.');
    expect(
        find.text('Polished. Read it over before you send.'), findsOneWidget);
    // Above the pill, not over it: over it, it hid Send and the end of the
    // brief it asks you to read.
    expect(
      tester
          .getRect(find.text('Polished. Read it over before you send.'))
          .bottom,
      lessThanOrEqualTo(tester
          .getRect(find.byKey(const ValueKey<String>('composer-pill')))
          .top),
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(_text(tester), 'make a poster ');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Undo leaves the brief alone once you have edited it',
      (WidgetTester tester) async {
    final (AppState state, _Engine engine) = await _signedIn();
    engine.rewrite = (String p) => 'Brief: $p.';
    await tester.pumpWidget(ShiftApp(state: state));
    await _dismissRingsSheet(tester);

    await tester.enterText(_field, 'make a poster');
    await tester.pump();
    await tester.tap(find.byTooltip('Polish my prompt'));
    await tester.pumpAndSettle();

    await tester.enterText(_field, 'Brief: make a poster. In teal.');
    await tester.pump();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(_text(tester), 'Brief: make a poster. In teal.');
  });

  testWidgets('a refusal keeps what you typed and says why',
      (WidgetTester tester) async {
    final (AppState state, _Engine engine) = await _signedIn();
    engine.refuse =
        const ShiftApiException(ShiftApiErrorKind.server, 'Polisher down.');
    await tester.pumpWidget(ShiftApp(state: state));
    await _dismissRingsSheet(tester);

    await tester.enterText(_field, 'make a poster');
    await tester.pump();
    await tester.tap(find.byTooltip('Polish my prompt'));
    await tester.pumpAndSettle();

    expect(_text(tester), 'make a poster');
    expect(find.text('Could not polish it: Polisher down.'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(state.lastError, isNull);
  });

  testWidgets('a brief that is already polished is left alone, and says so',
      (WidgetTester tester) async {
    final (AppState state, _) = await _signedIn();
    await tester.pumpWidget(ShiftApp(state: state));
    await _dismissRingsSheet(tester);

    final String brief = Prompt.polish('make a poster');
    await tester.enterText(_field, brief);
    await tester.pump();
    await tester.tap(find.byTooltip('Polish my prompt'));
    await tester.pumpAndSettle();

    expect(_text(tester), brief);
    expect(find.text('That is already a full brief.'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets(
      'while it polishes the bar is read-only and enter does not send the '
      'unpolished text', (WidgetTester tester) async {
    final (AppState state, _Engine engine) = await _signedIn();
    await tester.pumpWidget(ShiftApp(state: state));
    await _dismissRingsSheet(tester);
    engine.gate = Completer<void>();

    await tester.enterText(_field, 'make a poster');
    await tester.pump();
    await tester.tap(find.byTooltip('Polish my prompt'));
    await tester.pump();
    // The polish has started and not yet landed.
    expect(tester.widget<TextField>(_field).readOnly, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(state.messages, isEmpty);

    engine.gate!.complete();
    await tester.pumpAndSettle();

    expect(state.messages, isEmpty);
    expect(Prompt.isPolished(_text(tester)), isTrue);
    expect(tester.widget<TextField>(_field).readOnly, isFalse);
    expect(engine.asked, hasLength(1));
  });

  test('the demo\'s own brief keeps a question a question', () {
    final String out = Prompt.polish('What time is it');
    // It used to be "What time is it." with an audience and a tone.
    expect(out, startsWith('What time is it?'));
    expect(out, isNot(contains('Audience:')));
    expect(Prompt.isPolished(out), isTrue);
    expect(Prompt.polish(out), out);
    // A request is still a brief.
    expect(Prompt.polish('make me a promo video'), contains('Audience:'));
    expect(Prompt.polish('Make a poster!'), startsWith('Make a poster!\n'));
  });
}
