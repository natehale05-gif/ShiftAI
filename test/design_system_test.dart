import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/theme/app_theme.dart';
import 'package:shift_ai/theme/tokens.dart';

/// Every Dart file under lib/, with its path, comments stripped so a note
/// about "the Material AlertDialog this replaced" does not count.
Map<String, String> _sources() {
  final Map<String, String> out = <String, String>{};
  for (final FileSystemEntity f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final String code = f.readAsLinesSync().map((String l) {
      final int at = l.indexOf('//');
      return at < 0 ? l : l.substring(0, at);
    }).join('\n');
    out[f.path.replaceAll(r'\', '/')] = code;
  }
  return out;
}

/// Files and lines matching [pattern], outside [allowed].
List<String> _uses(
  RegExp pattern, {
  Set<String> allowed = const <String>{},
}) {
  final List<String> hits = <String>[];
  _sources().forEach((String path, String code) {
    if (allowed.contains(path)) return;
    final List<String> lines = code.split('\n');
    for (int i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) hits.add('$path:${i + 1}');
    }
  });
  return hits;
}

void main() {
  group('the design system is the only source of', () {
    test('colour: no literal Color or Colors.* outside tokens.dart', () {
      expect(
        _uses(
          RegExp(r'Color\(0x|(?<![A-Za-z])Colors\.(?!transparent)'),
          allowed: <String>{'lib/theme/tokens.dart'},
        ),
        isEmpty,
        reason: 'use ShiftColors, MediaInk or ShiftShadow',
      );
    });

    test('type size: no copyWith(fontSize:) outside the type scale', () {
      expect(
        _uses(
          RegExp(r'fontSize:'),
          allowed: <String>{'lib/theme/type.dart'},
        ),
        isEmpty,
        reason: 'use a named ShiftType style on the ramp',
      );
    });
  });

  group('no Material-only look comes back', () {
    final Map<String, RegExp> banned = <String, RegExp>{
      'AlertDialog / showDialog (use showShiftAlert)':
          RegExp(r'(?<!Cupertino)AlertDialog\(|showDialog<|showDialog\('),
      'CircularProgressIndicator (use ShiftSpinner)':
          RegExp(r'CircularProgressIndicator'),
      'Checkbox / CheckboxListTile (use ShiftCheckRow)':
          RegExp(r'(?<!Cupertino)Checkbox(ListTile)?\('),
      'Material Slider (use CupertinoSlider)': RegExp(r'(?<![A-Za-z])Slider\('),
      'Material Switch (use CupertinoSwitch)': RegExp(r'(?<![A-Za-z])Switch\('),
      'Ink ripple / sparkle': RegExp(r'InkRipple|InkSparkle'),
    };
    banned.forEach((String what, RegExp pattern) {
      test(what, () => expect(_uses(pattern), isEmpty));
    });
  });

  test('every theme behaves like iOS and presses without a ripple', () {
    for (final ShiftThemeId id in ShiftThemeId.values) {
      final ThemeData t = ShiftTheme.build(id);
      expect(t.platform, TargetPlatform.iOS, reason: id.name);
      expect(t.splashFactory, NoSplash.splashFactory, reason: id.name);
      expect(t.appBarTheme.centerTitle, isTrue, reason: id.name);
      expect(
        t.pageTransitionsTheme.builders.values.every(
            (PageTransitionsBuilder b) => b is CupertinoPageTransitionsBuilder),
        isTrue,
        reason: id.name,
      );
    }
  });
}
