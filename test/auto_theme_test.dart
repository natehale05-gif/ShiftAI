import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/app.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/theme/tokens.dart';

Future<AppState> _load([Map<String, Object>? blob]) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (blob != null) StoreKeys.app: jsonEncode(blob),
  });
  return AppState.load(tokenStore: MemoryTokenStore());
}

void main() {
  test('each theme pairs with its own day or night', () {
    expect(ShiftThemeId.retro.forBrightness(Brightness.light),
        ShiftThemeId.retroLight);
    expect(ShiftThemeId.retroLight.forBrightness(Brightness.dark),
        ShiftThemeId.retro);
    expect(
        ShiftThemeId.dark.forBrightness(Brightness.light), ShiftThemeId.light);
    expect(
        ShiftThemeId.light.forBrightness(Brightness.dark), ShiftThemeId.dark);
  });

  test('a new account follows the system; a chosen theme is kept', () async {
    final AppState fresh = await _load();
    addTearDown(fresh.dispose);
    expect(fresh.followSystem, isTrue);
    expect(fresh.themeId, ShiftThemeId.retro);

    // Someone who picked Retro light before this existed has no themeAuto
    // in their blob, and must not start switching at night.
    final AppState chosen =
        await _load(<String, Object>{'v': 2, 'theme': 'retroLight'});
    addTearDown(chosen.dispose);
    expect(chosen.followSystem, isFalse);
    expect(chosen.activeTheme, ShiftThemeId.retroLight);
  });

  test('picking a swatch overrides; switching off keeps what is showing',
      () async {
    final AppState state = await _load();
    addTearDown(state.dispose);
    state.setSystemBrightness(Brightness.light);
    expect(state.activeTheme, ShiftThemeId.retroLight);

    state.setFollowSystem(false);
    expect(state.activeTheme, ShiftThemeId.retroLight,
        reason: 'turning it off must not jump back to Retro neon');

    state.setFollowSystem(true);
    state.setTheme(ShiftThemeId.dark);
    expect(state.followSystem, isFalse);
    state.setSystemBrightness(Brightness.dark);
    state.setSystemBrightness(Brightness.light);
    expect(state.activeTheme, ShiftThemeId.dark);
  });

  testWidgets('the app follows the device from light to dark while open',
      (WidgetTester tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final AppState state = await _load();
    await tester.pumpWidget(ShiftApp(state: state));
    await tester.pump();

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();
    expect(state.activeTheme, ShiftThemeId.retroLight);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    expect(state.activeTheme, ShiftThemeId.retro);
  });
}
