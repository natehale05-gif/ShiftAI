import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/state/app_state.dart';
import 'package:shift_ai/theme/tokens.dart';

/// An installed web app on Android colours its navigation bar from the
/// manifest, not from the live theme-color tag, so there is a manifest
/// per theme and the page links the one showing. These hold the three
/// copies of each theme's ground (tokens.dart, the manifests, and the
/// hosted page's boot script) to one another.
String _hex(ShiftThemeId id) {
  final int argb = ShiftColors.forTheme(id).bg.toARGB32();
  return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('every theme has a manifest in its own ground', () {
    for (final ShiftThemeId id in ShiftThemeId.values) {
      final Map<String, dynamic> m = _read('web/manifest-${id.name}.json');
      expect(m['theme_color'], _hex(id), reason: id.name);
      expect(m['background_color'], _hex(id), reason: id.name);
    }
  });

  test('the manifests are one app: only the colours differ', () {
    // A different start_url, scope or id would make Chrome treat a theme
    // change as a different app rather than an update to this one.
    Map<String, dynamic> withoutColours(Map<String, dynamic> m) =>
        Map<String, dynamic>.of(m)
          ..remove('theme_color')
          ..remove('background_color');
    final Map<String, dynamic> base = _read('web/manifest.json');
    for (final ShiftThemeId id in ShiftThemeId.values) {
      expect(
        withoutColours(_read('web/manifest-${id.name}.json')),
        withoutColours(base),
        reason: id.name,
      );
    }
    // The page links manifest.json until a script swaps it, so the plain
    // one is the theme a new account opens on.
    expect(base['theme_color'], _hex(ShiftThemeIdLabel.parse(null)));
  });

  test('the hosted page boots in the same colours', () {
    final String script = File('tool/build_web_hosted.sh').readAsStringSync();
    for (final ShiftThemeId id in ShiftThemeId.values) {
      expect(
        RegExp("${id.name}: '${_hex(id)}'").hasMatch(script),
        isTrue,
        reason: '${id.name} should boot on ${_hex(id)}',
      );
    }
    // The key the boot script reads the saved theme from.
    // shared_preferences on the web prefixes every key with "flutter.".
    expect(script, contains("'flutter.${StoreKeys.app}'"));
  });

  test('both pages opt in to drawing under the gesture bar', () {
    // Chrome draws the page under Android's gesture bar, in place of a
    // solid bar, only with viewport-fit=cover and CSS that uses the
    // bottom inset. Flutter's canvas never would, so the probe does.
    for (final String path in <String>[
      'tool/build_web_hosted.sh',
      'web/index.html',
    ]) {
      final String page = File(path).readAsStringSync();
      expect(page, contains('viewport-fit=cover'), reason: path);
      expect(page, contains('env(safe-area-inset-bottom'), reason: path);
      expect(page, contains('<div id="shift-safe-area"></div>'), reason: path);
    }
  });
}
