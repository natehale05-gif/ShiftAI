import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/theme/tokens.dart';
import 'package:shift_ai/widgets/common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the artwork still carries the ink the recolour looks for', () async {
    // The swap is a string replace. If the brand file is redrawn with a
    // different ink it would quietly do nothing and the lockup would stay
    // on one fixed colour whatever theme is showing.
    await ShiftLockup.preload();
    expect(
      ShiftLockup.forInk(const Color(0xFF123456)),
      isNotNull,
      reason: 'preload rejected the artwork: its ink has changed',
    );
  });

  test('each theme gets its own text colour into the artwork', () async {
    await ShiftLockup.preload();

    String hex(Color x) {
      String ch(double v) =>
          (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
      return '#${ch(x.r)}${ch(x.g)}${ch(x.b)}'.toUpperCase();
    }

    for (final ShiftThemeId id in ShiftThemeId.values) {
      final ShiftColors c = ShiftColors.forTheme(id);
      final String svg = ShiftLockup.forInk(c.text)!;
      expect(svg, contains(hex(c.text)), reason: '${id.name} ink');
      // Nothing is left holding the stand-in value — except where a
      // theme's own text happens to be that value, which the dark
      // theme's is, since the artwork was drawn in it.
      if (hex(c.text) != '#F2F5FA') {
        expect(svg, isNot(contains('#F2F5FA')),
            reason: '${id.name} still carries the artwork ink');
      }
    }
  });

  test('the neon gradient is the brand and no theme overwrites it', () async {
    // That magenta-to-blue is the mark. A theme getting to repaint it is
    // the bug this guards.
    await ShiftLockup.preload();

    String hex(Color x) {
      String ch(double v) =>
          (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
      return '#${ch(x.r)}${ch(x.g)}${ch(x.b)}'.toUpperCase();
    }

    for (final ShiftThemeId id in ShiftThemeId.values) {
      final ShiftColors c = ShiftColors.forTheme(id);
      final String svg = ShiftLockup.forInk(c.text)!;
      // Sampled off the brand artwork's own glow, not chosen here — and
      // asserted through ShiftBrand rather than as literals, so the
      // tokens and the artwork cannot drift apart. The daily rings are
      // drawn from the same pair.
      expect(svg, contains(hex(ShiftBrand.neonStart)),
          reason: '${id.name} lost the magenta');
      expect(svg, contains(hex(ShiftBrand.neonEnd)),
          reason: '${id.name} lost the blue');
    }
  });

  test('the drawn ratio is the artwork\'s own, not a guess', () async {
    await ShiftLockup.preload();
    final String svg = ShiftLockup.forInk(const Color(0xFFFFFFFF))!;
    final RegExpMatch? box =
        RegExp(r'viewBox="([-\d. ]+)"').firstMatch(svg);
    expect(box, isNotNull, reason: 'the artwork has no viewBox');
    final List<double> v = box!
        .group(1)!
        .trim()
        .split(RegExp(r'\s+'))
        .map(double.parse)
        .toList();
    expect(ShiftLockup.ratio, closeTo(v[2] / v[3], 0.001));
  });
}
