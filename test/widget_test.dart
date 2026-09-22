import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/app/shell.dart';
import 'package:shift_ai/data/seed.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/theme/tokens.dart';
import 'package:shift_ai/util/file_pick.dart';
import 'package:shift_ai/util/prompt.dart';

Future<AppState> _freshState() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  // Never the real keychain: there is no platform channel under the test
  // binding, and a test that reaches for one hangs rather than fails.
  return AppState.load(tokenStore: MemoryTokenStore());
}

/// The rings screen opens on its own the moment `ShiftShell` mounts — see
/// `ShiftShell._showRings` — so every test that then wants to tap
/// something underneath closes it first, the same way a person would.
/// Settling first is what actually lets the pushed route finish
/// building — the push is requested from a post-frame callback, so it
/// needs a frame of its own before its close button exists to find.
Future<void> _dismissRingsSheet(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final Finder close = find.byTooltip('Close');
  if (close.evaluate().isEmpty) return;
  await tester.tap(close.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the shell opens on Create and reaches every surface',
      (WidgetTester tester) async {
    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pump();
    await _dismissRingsSheet(tester);

    expect(find.byType(ShiftShell), findsOneWidget);
    expect(state.surface, Surface.suite);
    // The greeting rotates, so the test asks the state which line is
    // showing rather than pinning one sentence — see `Greetings`.
    expect(find.text(state.greeting), findsOneWidget);

    for (final Surface surface in Surface.values) {
      state.setSurface(surface);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'on ${surface.name}');
    }
  });

  testWidgets('the sidebar starts closed and the hamburger opens it',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pump();
    await _dismissRingsSheet(tester);

    expect(state.sidebarCollapsed, isTrue);
    expect(find.byType(SidebarNav), findsNothing);

    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(SidebarNav), findsOneWidget);
  });

  testWidgets('below the breakpoint the sidebar is a drawer',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pump();
    await _dismissRingsSheet(tester);

    final ScaffoldState scaffold =
        tester.state<ScaffoldState>(find.byType(Scaffold).last);
    expect(scaffold.hasDrawer, isTrue);
    expect(find.byType(SidebarNav), findsNothing);
  });

  test('the retro pair sits on opposite grounds', () {
    expect(ShiftThemeId.values.length, 4);
    expect(ShiftColors.retro.isDarkGround, isTrue);
    expect(ShiftColors.retroLight.isDarkGround, isFalse);
    // Both retro themes are the same identity: pink ink, cyan support.
    expect(ShiftColors.retroLight.accent.r, greaterThan(0.5));
    expect(ShiftColors.retroLight.accent.g, lessThan(0.2));
    // Ink on paper has to carry body text, so it is far from the ground.
    expect(ShiftColors.retroLight.text.computeLuminance(), lessThan(0.05));
    expect(ShiftColors.retroLight.bg.computeLuminance(), greaterThan(0.8));
  });

  test('tier colours darken on a light ground', () {
    for (final TrophyTier tier in TrophyTier.values) {
      final Color onDark = tier.colorOn(ShiftColors.dark);
      final Color onPaper = tier.colorOn(ShiftColors.retroLight);
      expect(onDark, tier.color, reason: '${tier.name} on dark');
      // Silver and gold are the ones that vanish on paper; every tier is
      // brought below the ground it sits on.
      expect(
        onPaper.computeLuminance(),
        lessThan(ShiftColors.retroLight.bg.computeLuminance() - 0.3),
        reason: '${tier.name} on paper',
      );
    }
    expect(
      TrophyTier.gold.colorOn(ShiftColors.light),
      TrophyTier.gold.colorOn(ShiftColors.retroLight),
    );
  });

  testWidgets('every theme builds and carries its tokens',
      (WidgetTester tester) async {
    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await _dismissRingsSheet(tester);

    for (final ShiftThemeId id in ShiftThemeId.values) {
      state.setTheme(id);
      // MaterialApp animates a theme change, so settle before reading it.
      await tester.pumpAndSettle();
      final BuildContext context = tester.element(find.byType(ShiftShell));
      expect(ShiftColors.of(context).accent, ShiftColors.forTheme(id).accent);
      expect(tester.takeException(), isNull, reason: 'on ${id.name}');
    }
  });

  testWidgets('a sent message brings back an answer',
      (WidgetTester tester) async {
    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pump();
    await _dismissRingsSheet(tester);

    state.sendMessage('Cut a 20 second vertical promo');
    await tester.pump();

    expect(find.text(state.greeting), findsNothing);
    expect(find.text('Cut a 20 second vertical promo'), findsOneWidget);
    // The answer lands a beat later, after the working indicator.
    expect(state.thinking, isTrue);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(state.thinking, isFalse);

    // The answer carries the artifact card and then the plan-check failure,
    // which sit below the fold at test size.
    expect(
      state.messages.any((ChatMessage m) => m.attachment != null),
      isTrue,
    );
    expect(state.messages.any((ChatMessage m) => m.failure != null), isTrue);
    expect(tester.takeException(), isNull);
  });

  test('the mode menu is the four modes, and each lands on its surface',
      () async {
    final AppState state = await _freshState();
    expect(
      ShiftMode.values.map((ShiftMode m) => m.label).toList(),
      <String>['Suite', 'Agents', 'Design', 'Notes'],
    );
    for (final ShiftMode mode in ShiftMode.values) {
      state.setMode(mode);
      expect(state.surface, mode.surface, reason: 'on ${mode.name}');
    }
    expect(
      kWorkspaceSurfaces,
      <Surface>[Surface.earnings, Surface.trophies, Surface.vault],
    );
  });

  test('the board resolves you, your target and your chaser', () async {
    final AppState state = await _freshState();
    expect(state.you!.isYou, isTrue);
    expect(state.you!.rank, 13);
    expect(state.target!.rank, state.you!.rank - 1);
    expect(state.chaser!.rank, state.you!.rank + 1);
    expect(state.podium.length, 3);
  });

  testWidgets(
      'the leaderboard opens on Local, and Global switches to the whole board',
      (WidgetTester tester) async {
    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pump();
    await _dismissRingsSheet(tester);
    state.setSurface(Surface.earnings);
    await tester.pump();

    // Local by default: the seeded league's own region shows.
    expect(find.text(Seed.league.regionLabel), findsOneWidget);

    await tester.tap(find.text('GLOBAL'));
    await tester.pump();
    expect(find.text(Seed.league.regionLabel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('the local league arrives already placed in the seeded demo',
      () async {
    final AppState state = await _freshState();
    expect(state.league, isNotNull);
    expect(state.league!.regionLabel, Seed.league.regionLabel);
    expect(state.league!.you, isNotNull);
    expect(state.league!.you!.isYou, isTrue);
  });

  test('the trophy shelf adds up', () async {
    final AppState state = await _freshState();
    expect(state.trophies.length, 18);
    expect(state.trophiesEarned, 4);
    expect(state.trophyPoints, 55);

    final int total =
        state.trophies.fold(0, (int sum, Trophy t) => sum + t.points);
    expect(total, 610);

    for (final TrophyTier tier in TrophyTier.values) {
      final int inTier =
          state.trophies.where((Trophy t) => t.tier == tier).length;
      expect(inTier, greaterThan(0), reason: 'no ${tier.name} trophies');
    }
  });

  testWidgets('the sparkle polishes what is in the bar, in place',
      (WidgetTester tester) async {
    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pump();
    await _dismissRingsSheet(tester);

    await tester.enterText(
      find.byType(TextField).last,
      'can you make me a promo video',
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Nothing was sent: the polished text goes back in the bar to read.
    expect(state.messages, isEmpty);
    final TextField field = tester.widget<TextField>(
      find.byType(TextField).last,
    );
    final String text = field.controller!.text;
    expect(text, contains('promo video'));
    expect(text, contains('Deliver:'));
    expect(text, isNot(contains('can you make me')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the avatars gallery shows what the engine has, and creating one '
      'needs a photo first', (WidgetTester tester) async {
    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pump();
    await _dismissRingsSheet(tester);

    // Not pumpAndSettle: the training tile's spinner never settles. Pump
    // past the surface-switch fade (180ms) instead, so the old surface's
    // widgets are actually gone rather than mid-transition. A kick pump
    // first, then the jump — a single big jump does not reliably run the
    // AnimatedSwitcher's exit callback that unmounts the old child.
    state.setSurface(Surface.settings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Everyday'), findsOneWidget);
    expect(find.text('PERSONAL'), findsOneWidget);
    expect(find.text('Studio lighting'), findsOneWidget);
    expect(find.text('TRAINING…'), findsOneWidget);

    await tester.ensureVisible(find.text('Create an avatar'));
    await tester.pump();
    await tester.tap(find.text('Create an avatar'));
    await tester.pump();

    expect(find.text('Choose a photo or clip'), findsOneWidget);
    final FilledButton create = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'CREATE'),
    );
    expect(create.onPressed, isNull, reason: 'nothing to upload yet');
    expect(tester.takeException(), isNull);
  });

  test('polishing is idempotent and leaves nothing to polish alone', () {
    const String ask = 'write a launch post';
    final String once = Prompt.polish(ask);
    expect(Prompt.polish(once), once);
    expect(Prompt.polish('   '), '   '.trim());
    expect(Prompt.isPolished(once), isTrue);
  });

  test('every kind of file is accepted, not just media', () {
    PickedKind kindOf(String mime) => PickedFile(
          name: 'x',
          bytes: Uint8List(0),
          mimeType: mime,
        ).kind;

    expect(kindOf('image/png'), PickedKind.image);
    expect(kindOf('video/mp4'), PickedKind.video);
    expect(kindOf('audio/wav'), PickedKind.audio);
    expect(kindOf('application/pdf'), PickedKind.file);
    expect(kindOf('application/zip'), PickedKind.file);
    expect(kindOf(''), PickedKind.file);

    expect(
      PickedFile(name: 'x', bytes: Uint8List(2048), mimeType: '').sizeLabel,
      '2 KB',
    );
  });

  testWidgets('notes can be added, edited and removed',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pump();
    await _dismissRingsSheet(tester);

    final int before = state.notes.length;
    final Note made =
        (await state.addNote(title: 'Rehearsal', body: 'Six o\'clock'))!;
    expect(state.notes.length, before + 1);
    expect(state.notes.first.id, made.id);

    await state.saveNote(made.id, title: '', body: 'Moved to seven');
    final Note after = state.notes.firstWhere((Note n) => n.id == made.id);
    expect(after.title, 'Untitled');
    expect(after.body, 'Moved to seven');

    await state.deleteNote(made.id);
    expect(state.notes.length, before);
  });

  test('a design duplicates next to itself and deletes cleanly', () async {
    final AppState state = await _freshState();
    final DesignDoc first = state.designs.first;
    final int before = state.designs.length;

    await state.duplicateDesign(first.id);
    expect(state.designs.length, before + 1);
    expect(state.designs[1].title, '${first.title} copy');
    expect(state.designs[1].versions, 1);
    expect(state.designs.first.id, first.id);

    await state.deleteDesign(state.designs[1].id);
    expect(state.designs.length, before);
  });

  test('retry and edit have the last ask to work from', () async {
    final AppState state = await _freshState();
    expect(state.lastAsk, isNull);
    state.sendMessage('Cut a 20 second vertical promo');
    expect(state.lastAsk, 'Cut a 20 second vertical promo');
    state.clearThread();
    expect(state.lastAsk, isNull);
  });

  testWidgets('the composer controls sit on the centre of the pill',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pumpAndSettle();
    await _dismissRingsSheet(tester);

    final Rect pill = tester.getRect(
      find.byKey(const ValueKey<String>('composer-pill')),
    );
    expect(pill.height, 56, reason: 'the pill is drawn at 56 at rest');

    for (final String tip in <String>[
      'Attach a file — any kind',
      'Polish my prompt',
      'Send',
    ]) {
      final Rect control = tester.getRect(find.byTooltip(tip).first);
      expect(
        control.center.dy,
        closeTo(pill.center.dy, 0.5),
        reason: '$tip is off the centre line',
      );
    }

    // Once the text wraps, the pill grows and the controls go with the
    // last line rather than staying put in the middle.
    await tester.enterText(
      find.byType(TextField).last,
      List<String>.filled(40, 'wrap').join(' '),
    );
    await tester.pumpAndSettle();

    final Rect grown = tester.getRect(
      find.byKey(const ValueKey<String>('composer-pill')),
    );
    expect(grown.height, greaterThan(pill.height));

    // A full-size control sits on the 6px inset; the send circle is 40 in
    // a 44 slot, so it clears the floor by 6 + 2.
    final Rect attach =
        tester.getRect(find.byTooltip('Attach a file — any kind').first);
    expect(
      grown.bottom - attach.bottom,
      closeTo(6, 0.5),
      reason: 'a control should sit 6 above the pill floor',
    );
    final Rect send = tester.getRect(find.byTooltip('Send').first);
    expect(
      grown.bottom - send.bottom,
      closeTo(8, 0.5),
      reason: 'the send circle should sit 8 above the pill floor',
    );
  });

  testWidgets('the rings screen can be swiped away as well as tapped away',
      (WidgetTester tester) async {
    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    // The screen opens itself, so no tap is needed to get onto it.
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsOneWidget);

    // A drag down anywhere on the page, not on a handle: the whole body is
    // the target, which is why the scroll view is stretched to fill it.
    await tester.drag(find.text('Create'), const Offset(0, 260));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsNothing);
    expect(find.byType(ShiftShell), findsOneWidget);
  });

  testWidgets('a short drag keeps the rings screen up',
      (WidgetTester tester) async {
    final AppState state = await _freshState();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pumpAndSettle();

    // Under the threshold the page bounces back rather than leaving —
    // otherwise the top of a genuine scroll would throw people out.
    await tester.drag(find.text('Create'), const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close'), findsOneWidget);
  });

  test('private chat content never reaches storage', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppState state = await AppState.load(tokenStore: MemoryTokenStore());
    state.togglePrivateChat();
    state.sendMessage('something private');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String blob = prefs.getString(StoreKeys.app) ?? '';
    expect(blob.contains('something private'), isFalse);
  });
}
