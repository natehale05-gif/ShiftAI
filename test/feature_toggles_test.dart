import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shift_ai/app/modes.dart';
import 'package:shift_ai/data/auth/token_store.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/theme/tokens.dart';

Future<AppState> _fresh() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return AppState.load(tokenStore: MemoryTokenStore());
}

/// A hand-written blob, as a previous version of the app would have left
/// it. The version stamp has to match AppState's private _blobVersion or
/// the loader discards the whole blob as an older shape — which is what
/// makes a wrong number here look like a feature that does not persist.
const int _blobVersion = 2;

Future<AppState> _withBlob(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    StoreKeys.app: jsonEncode(<String, dynamic>{'v': _blobVersion, ...blob}),
  });
  return AppState.load(tokenStore: MemoryTokenStore());
}

/// Writes through the real save path and reads it back, so the round trip
/// is tested rather than a blob shape assumed.
Future<AppState> _reload(void Function(AppState) change) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final AppState first = await AppState.load(tokenStore: MemoryTokenStore());
  change(first);
  // The store debounces at 400ms.
  await Future<void>.delayed(const Duration(milliseconds: 600));
  return AppState.load(tokenStore: MemoryTokenStore());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('defaults', () {
    test('a new account opens on retro neon', () async {
      final AppState state = await _fresh();
      expect(state.themeId, ShiftThemeId.retro);
    });

    test('an account that chose a theme keeps it', () async {
      // The default changing must not move anyone who already picked.
      final AppState state = await _withBlob(<String, dynamic>{
        'theme': 'light',
      });
      expect(state.themeId, ShiftThemeId.light);
    });

    test('every section is on', () async {
      final AppState state = await _fresh();
      for (final ShiftFeature f in ShiftFeature.values) {
        expect(state.isEnabled(f), isTrue, reason: f.name);
      }
      expect(state.visibleModes, ShiftMode.values);
      expect(state.visibleWorkspace, kWorkspaceSurfaces);
    });
  });

  group('switching a section off', () {
    test('drops its mode row', () async {
      final AppState state = await _fresh();
      state.setFeatureEnabled(ShiftFeature.agents, false);
      expect(state.visibleModes, isNot(contains(ShiftMode.agents)));
      expect(state.visibleModes, contains(ShiftMode.suite));
    });

    test('drops its workspace row', () async {
      final AppState state = await _fresh();
      state.setFeatureEnabled(ShiftFeature.trophies, false);
      expect(state.visibleWorkspace, isNot(contains(Surface.trophies)));
      expect(state.visibleWorkspace, contains(Surface.vault));
    });

    test('the workspace group can empty completely', () async {
      final AppState state = await _fresh();
      state
        ..setFeatureEnabled(ShiftFeature.leaderboard, false)
        ..setFeatureEnabled(ShiftFeature.trophies, false)
        ..setFeatureEnabled(ShiftFeature.vault, false);
      expect(state.visibleWorkspace, isEmpty);
    });

    test('moves you off it if you are standing on it', () async {
      // Switching off the screen you are looking at must not leave it up
      // with its way back gone.
      final AppState state = await _fresh();
      state.setSurface(Surface.vault);
      expect(state.surface, Surface.vault);

      state.setFeatureEnabled(ShiftFeature.vault, false);
      expect(state.surface, Surface.suite);
    });

    test('resets the mode too, not just the surface', () async {
      final AppState state = await _fresh();
      state.setMode(ShiftMode.notes);
      expect(state.mode, ShiftMode.notes);

      state.setFeatureEnabled(ShiftFeature.notes, false);
      expect(state.mode, ShiftMode.suite);
      expect(state.surface, Surface.suite);
    });

    test('a switched-off surface is not navigable', () async {
      final AppState state = await _fresh();
      state.setFeatureEnabled(ShiftFeature.design, false);

      state.setSurface(Surface.design);
      expect(state.surface, Surface.suite);

      state.setMode(ShiftMode.design);
      expect(state.mode, ShiftMode.suite);
      expect(state.surface, Surface.suite);
    });

    test('switching back on restores the row', () async {
      final AppState state = await _fresh();
      state.setFeatureEnabled(ShiftFeature.vault, false);
      expect(state.visibleWorkspace, isNot(contains(Surface.vault)));

      state.setFeatureEnabled(ShiftFeature.vault, true);
      expect(state.visibleWorkspace, contains(Surface.vault));
      state.setSurface(Surface.vault);
      expect(state.surface, Surface.vault);
    });
  });

  group('persistence', () {
    test('a section switched off survives a reload', () async {
      final AppState state = await _reload(
        (AppState s) => s.setFeatureEnabled(ShiftFeature.agents, false),
      );
      expect(state.isEnabled(ShiftFeature.agents), isFalse);
      expect(state.visibleModes, isNot(contains(ShiftMode.agents)));
      expect(state.isEnabled(ShiftFeature.vault), isTrue);
    });

    test('switching one back on survives a reload too', () async {
      final AppState state = await _reload((AppState s) {
        s
          ..setFeatureEnabled(ShiftFeature.vault, false)
          ..setFeatureEnabled(ShiftFeature.vault, true);
      });
      expect(state.isEnabled(ShiftFeature.vault), isTrue);
    });

    test('a stored disabled section comes back disabled', () async {
      final AppState state = await _withBlob(<String, dynamic>{
        'disabledFeatures': <String>['agents', 'connectors'],
      });
      expect(state.isEnabled(ShiftFeature.agents), isFalse);
      expect(state.isEnabled(ShiftFeature.connectors), isFalse);
      expect(state.isEnabled(ShiftFeature.vault), isTrue);
    });

    test('a section this build does not know is ignored, not applied',
        () async {
      // A blob from a newer version naming a feature that does not exist
      // here must not switch something off at random.
      final AppState state = await _withBlob(<String, dynamic>{
        'disabledFeatures': <String>['agents', 'somethingFromTheFuture'],
      });
      expect(state.isEnabled(ShiftFeature.agents), isFalse);
      for (final ShiftFeature f in ShiftFeature.values) {
        if (f == ShiftFeature.agents) continue;
        expect(state.isEnabled(f), isTrue, reason: f.name);
      }
    });

    test('an older blob with no list has everything on', () async {
      // Forward compatibility the other way: the key predates nobody, so
      // its absence means "nothing was switched off".
      final AppState state = await _withBlob(<String, dynamic>{
        'theme': 'dark',
        'surface': 'vault',
      });
      for (final ShiftFeature f in ShiftFeature.values) {
        expect(state.isEnabled(f), isTrue, reason: f.name);
      }
      expect(state.surface, Surface.vault);
    });

    test('a stored surface whose section is off falls back to Suite',
        () async {
      // Otherwise the app opens on a screen with no row in the sidebar.
      final AppState state = await _withBlob(<String, dynamic>{
        'surface': 'trophies',
        'mode': 'notes',
        'disabledFeatures': <String>['trophies', 'notes'],
      });
      expect(state.surface, Surface.suite);
      expect(state.mode, ShiftMode.suite);
    });
  });

  test('Suite and Settings cannot be switched off', () async {
    // Nothing in the enum maps to them, which is what keeps the app
    // navigable however the switches are set.
    expect(Surface.suite.feature, isNull);
    expect(Surface.settings.feature, isNull);
    expect(ShiftMode.suite.feature, isNull);

    final AppState state = await _fresh();
    for (final ShiftFeature f in ShiftFeature.values) {
      state.setFeatureEnabled(f, false);
    }
    expect(state.surface, Surface.suite);
    expect(state.visibleModes, <ShiftMode>[ShiftMode.suite]);
    expect(state.isEnabled(Surface.settings.feature), isTrue);
  });
}
