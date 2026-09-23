import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/theme/tokens.dart';

/// The real faces, not the test font. The test font draws every glyph as
/// a full em square, about twice Manrope's width, so it reports overflows
/// a phone would never show and hides the ones it would.
Future<void> _loadRealFonts() async {
  for (final (String family, String file) in <(String, String)>[
    ('Outfit', 'assets/fonts/Outfit-Variable.ttf'),
    ('Manrope', 'assets/fonts/Manrope-Variable.ttf'),
  ]) {
    await (FontLoader(family)
          ..addFont(Future<ByteData>.value(
            ByteData.sublistView(File(file).readAsBytesSync()),
          )))
        .load();
  }
}

/// A phone-width app on [theme], with the rings screen closed.
///
/// [height] is a phone's unless a check needs every row on screen at once:
/// the guidelines only look at what is visible, and scrolling instead
/// leaves rows cut off at the edges, which they measure as the sliver
/// that shows. The Sections switches in Settings failed below the fold
/// and were never looked at.
Future<AppState> _pumpApp(
  WidgetTester tester,
  ShiftThemeId theme, {
  double height = 915,
}) async {
  tester.view.physicalSize = Size(412 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppState state = await AppState.load(tokenStore: MemoryTokenStore());
  state.setTheme(theme);
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
  setUpAll(_loadRealFonts);

  // Tap targets and labels do not change with the theme, so they are
  // checked once. Apple's 44-point minimum, which the whole app is built
  // to; Android's 48dp recommendation is not the target here.
  testWidgets('every control is labelled and at least 44 points',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final AppState state =
        await _pumpApp(tester, ShiftThemeId.retro, height: 5000);
    for (final Surface surface in Surface.values) {
      state.setSurface(surface);
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline),
          reason: surface.name);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline),
          reason: surface.name);
    }
    semantics.dispose();
  });

  for (final ShiftThemeId theme in ShiftThemeId.values) {
    testWidgets('text reads against its ground on ${theme.name}',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final AppState state = await _pumpApp(tester, theme, height: 5000);
      for (final Surface surface in Surface.values) {
        state.setSurface(surface);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline),
            reason: surface.name);
      }
      semantics.dispose();
    });
  }

  for (final double scale in <double>[1.5, 2.0]) {
    testWidgets('nothing overflows at ${scale}x text',
        (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final AppState state = await _pumpApp(tester, ShiftThemeId.retro);
      for (final Surface surface in Surface.values) {
        state.setSurface(surface);
        await tester.pumpAndSettle();
        // Scroll each screen through, so rows below the fold lay out too.
        final Finder scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          for (int i = 0; i < 12; i++) {
            await tester.drag(scrollable.first, const Offset(0, -500),
                warnIfMissed: false);
            await tester.pump();
          }
        }
        expect(tester.takeException(), isNull, reason: surface.name);
      }
    });
  }

  testWidgets('the leaderboard reads one person at a time, podium in order',
      (WidgetTester tester) async {
    // It reached VoiceOver as one long run of text: the podium in the order
    // the steps stand, second, first, third, and every face's initials
    // spelled out as letters.
    final SemanticsHandle semantics = tester.ensureSemantics();
    final AppState state = await _pumpApp(tester, ShiftThemeId.retro);
    state.setSurface(Surface.earnings);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(r'1st place, Jodie Marsh, $412.80'),
        findsOneWidget);
    expect(find.bySemanticsLabel(r'4th, you, $301.25, up 2'), findsOneWidget);
    expect(find.bySemanticsLabel(r'5th, Priya Nair, $288.90, down 1'),
        findsOneWidget);
    expect(
      find.bySemanticsLabel(r'You are 4th, $301.25 this week, up 2'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Standings')),
      containsSemantics(label: 'Standings', isHeader: true),
    );

    // The podium steps carry their rank as their reading order.
    SemanticsSortKey? keyOf(String label) =>
        tester.getSemantics(find.bySemanticsLabel(label)).sortKey;
    final SemanticsSortKey? first = keyOf(r'1st place, Jodie Marsh, $412.80');
    final SemanticsSortKey? second = keyOf(r'2nd place, Reese Cantu, $388.15');
    expect(first, isNotNull);
    expect(first!.compareTo(second!), lessThan(0));
    semantics.dispose();
  });
}
