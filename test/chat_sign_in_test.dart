import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/data/auth/auth_service.dart';
import 'package:shift_ai/data/auth/session.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/data/backend.dart';
import 'package:shift_ai/data/seed_repository.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

const Creator _person = Creator(
  handle: 'rae',
  name: 'Rae Okonkwo',
  email: 'rae@example.com',
  initials: 'RO',
);

class _StubAuth implements AuthService {
  /// The only call these tests make. Everything else throwing keeps a new
  /// dependency on the auth service from slipping in unnoticed.
  @override
  Future<void> signOut(String refreshToken) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// The demo: no engine behind it, and nobody signed in to anything.
Future<AppState> _demo() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppState.load(
    repository: SeedRepository(replyDelay: Duration.zero),
    tokenStore: MemoryTokenStore(),
  );
}

/// An engine configured, with a session already in the keychain — a
/// returning person, which is the only case chat is meant to work in.
Future<AppState> _signedIn() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'shift-backend': 'https://api.example.com',
  });
  final TokenStore tokens = MemoryTokenStore();
  await tokens.write(Session(
    accessToken: 'access-1',
    refreshToken: 'refresh-1',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    creator: _person,
  ));
  final AuthController auth =
      AuthController(service: _StubAuth(), store: tokens);
  await auth.restore();
  return AppState.load(
    engine: Backend(
      repository: SeedRepository(replyDelay: Duration.zero),
      auth: auth,
      seeded: false,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chat asks for a sign-in rather than answering', () {
    test('the demo needs one', () async {
      // The seeded catalogue lets anyone through and answers with a
      // fixture. That fixture must not go back as though an engine had
      // written it.
      final AppState state = await _demo();
      expect(state.seededDemo, isTrue);
      expect(state.chatNeedsSignIn, isTrue);
    });

    test('sending is refused, and nothing lands in the thread', () async {
      final AppState state = await _demo();

      expect(state.sendMessage('make me a poster'), isFalse);
      expect(state.messages, isEmpty);
      expect(state.thinking, isFalse);
      // Retry and Edit work from this; a refused send must not arm them.
      expect(state.lastAsk, isNull);
    });

    test('no canned answer arrives a beat later either', () async {
      // The refusal has to be the end of it. The seeded reply lands after
      // a delay, so a guard that only skipped the first frame would still
      // deliver the fixture.
      final AppState state = await _demo();
      state.sendMessage('anything');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(state.messages, isEmpty);
    });

    test('a signed-in account can send', () async {
      final AppState state = await _signedIn();
      expect(state.chatNeedsSignIn, isFalse);

      expect(state.sendMessage('make me a poster'), isTrue);
      expect(state.messages, isNotEmpty);
      expect(state.messages.first.author, MessageAuthor.you);
      expect(state.messages.first.body, 'make me a poster');
    });

    test('signing out closes it again', () async {
      final AppState state = await _signedIn();
      expect(state.chatNeedsSignIn, isFalse);

      await state.signOut();
      expect(state.chatNeedsSignIn, isTrue);
      expect(state.sendMessage('still there?'), isFalse);
    });

    test('an empty message is still refused, not sent', () async {
      final AppState state = await _signedIn();
      expect(state.sendMessage('   '), isFalse);
      expect(state.messages, isEmpty);
    });

    testWidgets('the composer keeps what was typed when the send is refused',
        (WidgetTester tester) async {
      // Clearing the bar on a send that never happened throws the text
      // away and leaves nothing to show for it.
      final AppState state = await _demo();
      await tester.pumpWidget(ShiftApp(state: state));
      await tester.pumpAndSettle();
      // The rings open themselves over the Suite on launch.
      await tester.tap(find.byTooltip('Close').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'a promo please');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('a promo please'), findsOneWidget);
      expect(state.messages, isEmpty);
    });

    testWidgets('the notice stands above the bar before anything is typed',
        (WidgetTester tester) async {
      final AppState state = await _demo();
      await tester.pumpWidget(ShiftApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close').first);
      await tester.pumpAndSettle();

      expect(find.text('Sign in to use chat.'), findsOneWidget);
      // Above it, not instead of it: Vault's Re-run hands the bar a draft
      // and the sparkle rewrites what is in it, with nobody to send to.
      expect(find.byKey(const Key('composer-pill')), findsOneWidget);
    });
  });
}
