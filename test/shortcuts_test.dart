import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/state/app_state.dart';

Future<AppState> _app(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppState state = await AppState.load(tokenStore: MemoryTokenStore());
  await tester.pumpWidget(ShiftApp(state: state));
  await tester.pumpAndSettle();
  final Finder close = find.byTooltip('Close');
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close.first);
    await tester.pumpAndSettle();
  }
  return state;
}

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  LogicalKeyboardKey? modifier,
}) async {
  if (modifier != null) await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  if (modifier != null) await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'number keys go to the sections in sidebar order, with '
      'either modifier', (WidgetTester tester) async {
    final AppState state = await _app(tester);

    await _press(tester, LogicalKeyboardKey.digit2,
        modifier: LogicalKeyboardKey.metaLeft);
    expect(state.surface, Surface.agents);
    await _press(tester, LogicalKeyboardKey.digit3,
        modifier: LogicalKeyboardKey.controlLeft);
    expect(state.surface, Surface.design);
    await _press(tester, LogicalKeyboardKey.digit7,
        modifier: LogicalKeyboardKey.metaLeft);
    expect(state.surface, Surface.vault);
    await _press(tester, LogicalKeyboardKey.comma,
        modifier: LogicalKeyboardKey.metaLeft);
    expect(state.surface, Surface.settings);

    // Switching a section off shifts the numbers up, so none lands on a
    // hidden section.
    state.setFeatureEnabled(ShiftFeature.agents, false);
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.digit2,
        modifier: LogicalKeyboardKey.metaLeft);
    expect(state.surface, Surface.design);
  });

  testWidgets('command K starts a new chat from anywhere',
      (WidgetTester tester) async {
    final AppState state = await _app(tester);
    state.setSurface(Surface.trophies);
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.keyK,
        modifier: LogicalKeyboardKey.metaLeft);
    expect(state.surface, Surface.suite);
    expect(state.mode, ShiftMode.suite);
  });

  testWidgets('escape closes the vault detail, then a pushed page',
      (WidgetTester tester) async {
    final AppState state = await _app(tester);
    state.setSurface(Surface.vault);
    state.selectVaultItem(state.vault.first.id);
    await tester.pumpAndSettle();
    expect(state.selectedVaultId, isNotNull);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(state.selectedVaultId, isNull);

    // A note's editor is a page pushed over the shell.
    state.setSurface(Surface.notes);
    await tester.pumpAndSettle();
    final Note first = state.notes.first;
    await tester.tap(find.text(first.title));
    await tester.pumpAndSettle();
    expect(find.text('Write it down'), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(find.text('Write it down'), findsNothing);
  });
}
