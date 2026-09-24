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
import 'package:shift_ai/util/choices.dart';

ChatMessage _reply(
  String body, {
  List<String> bullets = const <String>[],
  List<ChatChoice> choices = const <ChatChoice>[],
  bool multi = false,
}) =>
    ChatMessage(
      id: 'r',
      author: MessageAuthor.shift,
      body: body,
      bullets: bullets,
      choices: choices,
      multiSelect: multi,
    );

List<String> _labels(OfferedChoices? o) =>
    o!.choices.map((ChatChoice c) => c.label).toList();

/// An engine that answers each message with the next scripted reply and
/// records what it was sent.
class _Engine extends SeedRepository {
  _Engine(this.replies);

  final List<ChatMessage> replies;
  final List<({String prompt, List<ChatTurn> history})> sent =
      <({String prompt, List<ChatTurn> history})>[];

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
    sent.add((prompt: prompt, history: history));
    return <ChatMessage>[
      if (replies.isNotEmpty)
        replies.removeAt(0)
      else
        const ChatMessage(
            id: 'done', author: MessageAuthor.shift, body: 'On it.'),
    ];
  }
}

class _StubAuth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<(AppState, _Engine)> _signedIn(List<ChatMessage> replies) async {
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
  final _Engine engine = _Engine(replies);
  final AppState state = await AppState.load(
    engine: Backend(repository: engine, auth: auth, seeded: false),
  );
  return (state, engine);
}

Future<void> _open(WidgetTester tester, AppState state) async {
  await tester.pumpWidget(ShiftApp(state: state));
  await tester.pumpAndSettle();
  final Finder close = find.byTooltip('Close');
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close.first);
    await tester.pumpAndSettle();
  }
}

const ChatMessage _feel = ChatMessage(
  id: 'q1',
  author: MessageAuthor.shift,
  body: 'What should it feel like?',
  choices: <ChatChoice>[
    ChatChoice('Cinematic', description: 'Slow drone shots, golden hour'),
    ChatChoice('High energy'),
    ChatChoice('Calm'),
  ],
);

const ChatMessage _where = ChatMessage(
  id: 'q2',
  author: MessageAuthor.shift,
  body: 'Where will it go? Pick any that fit.',
  choices: <ChatChoice>[
    ChatChoice('Reels'),
    ChatChoice('TikTok'),
    ChatChoice('YouTube'),
  ],
  multiSelect: true,
);

void main() {
  group('reading them off the reply', () {
    test('choices the server sends are used as they are', () {
      final OfferedChoices? o = OfferedChoices.of(_feel);
      expect(_labels(o), <String>['Cinematic', 'High energy', 'Calm']);
      expect(o!.choices.first.description, 'Slow drone shots, golden hour');
      expect(o.multiSelect, isFalse);
      expect(o.body, 'What should it feel like?');
    });

    test('from JSON: `choices`, or a `question` like AskUserQuestion', () {
      final ChatMessage a = ChatMessage.fromJson(const <String, dynamic>{
        'id': 'm1',
        'author': 'shift',
        'body': 'Which?',
        'choices': <Object>[
          'Plain',
          <String, String>{'label': 'Rich', 'description': 'More detail'},
          '  ',
        ],
      });
      expect(a.choices, const <ChatChoice>[
        ChatChoice('Plain'),
        ChatChoice('Rich', description: 'More detail'),
      ]);

      final ChatMessage b = ChatMessage.fromJson(const <String, dynamic>{
        'id': 'm2',
        'author': 'shift',
        'body': 'Which platforms?',
        'question': <String, Object>{
          'options': <Map<String, String>>[
            <String, String>{'label': 'TikTok'},
            <String, String>{'label': 'YouTube'},
          ],
          'multiSelect': true,
        },
      });
      expect(b.choices.map((ChatChoice c) => c.label),
          <String>['TikTok', 'YouTube']);
      expect(b.multiSelect, isTrue);
      // And back out, for the device's copy of the thread.
      expect(ChatMessage.fromJson(b.toJson()).choices, b.choices);
    });

    test('a question written out as a numbered list becomes buttons', () {
      final OfferedChoices? o = OfferedChoices.of(_reply(
        'Happy to. Which feel are you going for?\n'
        '1. **Cinematic** — slow drone shots at sunset\n'
        '2. Nightlife\n'
        '3. Beach day',
      ));
      expect(_labels(o), <String>['Cinematic', 'Nightlife', 'Beach day']);
      expect(o!.choices.first.description, 'slow drone shots at sunset');
      // The listed lines move into the buttons, not shown twice.
      expect(o.body, 'Happy to. Which feel are you going for?');
    });

    test('options first and the question last works too', () {
      final OfferedChoices? o = OfferedChoices.of(_reply(
        'I can go two ways:\n- Short and punchy\n- Long and moody\n\n'
        'Which one?',
      ));
      expect(_labels(o), <String>['Short and punchy', 'Long and moody']);
      expect(o!.body, 'I can go two ways:\n\nWhich one?');
    });

    test('bullets under a question become the buttons', () {
      final OfferedChoices? o = OfferedChoices.of(_reply(
        'Which length?',
        bullets: <String>['15 seconds', '30 seconds'],
      ));
      expect(_labels(o), <String>['15 seconds', '30 seconds']);
      expect(o!.hideBullets, isTrue);
    });

    test('"pick any" and "all that apply" take several', () {
      expect(
        OfferedChoices.of(_reply('Which platforms? Pick any.\n- A\n- B'))!
            .multiSelect,
        isTrue,
      );
      expect(
        OfferedChoices.of(_reply('Which do you want?\n- A\n- B'))!.multiSelect,
        isFalse,
      );
    });

    test('lists that are not a question to answer stay text', () {
      for (final ChatMessage m in <ChatMessage>[
        // Steps, no question.
        _reply('Here is the plan:\n1. Shoot the skyline\n2. Cut to beat'),
        // A question, but the reply goes on after the list.
        _reply('Which?\n1. A\n2. B\nEither way I will start now.'),
        // Only one option.
        _reply('Want me to go ahead?\n- Yes'),
        // Too many to be a question.
        _reply(
            'Pick one?\n${List<String>.generate(9, (int i) => '- $i').join('\n')}'),
        // A paragraph, not an answer.
        _reply('Which?\n- ${'word ' * 30}\n- short'),
        // Bullets under a statement.
        _reply('Done.', bullets: <String>['One', 'Two']),
        // Your own message.
        const ChatMessage(
            id: 'y', author: MessageAuthor.you, body: 'Which?\n- A\n- B'),
      ]) {
        expect(OfferedChoices.of(m), isNull, reason: m.body);
      }
    });

    test('several picked are sent in the order they were offered', () {
      final OfferedChoices o = OfferedChoices.of(_where)!;
      expect(
        o.answer(
            const <ChatChoice>[ChatChoice('YouTube'), ChatChoice('Reels')]),
        'Reels and YouTube',
      );
      expect(o.answer(o.choices), 'Reels, TikTok and YouTube');
    });
  });

  test(
      'the offered answers travel in history, so "the second one" means '
      'something to the next model', () async {
    final (AppState state, _Engine engine) =
        await _signedIn(<ChatMessage>[_feel]);
    state.sendMessage('Plan a trip to Miami');
    await Future<void>.delayed(Duration.zero);
    state.sendMessage('the second one');
    await Future<void>.delayed(Duration.zero);
    expect(
      engine.sent.last.history.last.body,
      'What should it feel like?\n'
      '- Cinematic: Slow drone shots, golden hour\n'
      '- High energy\n'
      '- Calm',
    );
  });

  testWidgets('one tap sends that answer, and the buttons go',
      (WidgetTester tester) async {
    final (AppState state, _Engine engine) =
        await _signedIn(<ChatMessage>[_feel]);
    await _open(tester, state);
    state.sendMessage('Plan a trip to Miami');
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceButtons), findsOneWidget);
    expect(find.text('Slow drone shots, golden hour'), findsOneWidget);
    expect(find.text('Or type your own answer below.'), findsOneWidget);

    await tester.tap(find.text('High energy'));
    await tester.pumpAndSettle();

    expect(engine.sent.last.prompt, 'High energy');
    expect(
        state.messages.map((ChatMessage m) => m.body), contains('High energy'));
    // Answered: the question reads as it was written, with no buttons.
    expect(find.byType(ChoiceButtons), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pick several, then Send sends them together',
      (WidgetTester tester) async {
    final (AppState state, _Engine engine) =
        await _signedIn(<ChatMessage>[_where]);
    await _open(tester, state);
    state.sendMessage('Plan the launch');
    await tester.pumpAndSettle();

    final Finder send = find.widgetWithText(FilledButton, 'Send');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tester.tap(find.text('YouTube'));
    await tester.tap(find.text('Reels'));
    await tester.pumpAndSettle();
    // Ticking does not send.
    expect(engine.sent, hasLength(1));

    await tester.tap(find.widgetWithText(FilledButton, 'Send 2'));
    await tester.pumpAndSettle();
    // Sent, though "Reels" reads like a request for a video: a tapped
    // answer goes back to the model that asked.
    expect(engine.sent.last.prompt, 'Reels and YouTube');
    expect(state.messages.any((ChatMessage m) => m.failure != null), isFalse);
  });

  testWidgets('a question written out gets buttons, lines not shown twice',
      (WidgetTester tester) async {
    final (AppState state, _Engine engine) = await _signedIn(<ChatMessage>[
      _reply('Which length?\n1. 15 seconds — a quick hook\n2. 30 seconds'),
    ]);
    await _open(tester, state);
    state.sendMessage('ask me');
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceButtons), findsOneWidget);
    expect(find.text('Which length?'), findsOneWidget);
    expect(find.textContaining('1. 15 seconds'), findsNothing);
    await tester.tap(find.text('15 seconds'));
    await tester.pumpAndSettle();
    expect(engine.sent.last.prompt, '15 seconds');
  });
}
