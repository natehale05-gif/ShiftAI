import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/theme/tokens.dart';
import 'package:shift_ai/widgets/common.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the artwork still carries the fills the recolour looks for',
      () async {
    // The swap is a string replace. If the brand file is redrawn with a
    // different palette it would quietly do nothing and the lockup would
    // stay on the old blue over a pink app — which is the bug this whole
    // change exists to fix, returning by the back door.
    await ShiftLockup.preload();
    expect(
      ShiftLockup.forColors(const Color(0xFF123456), const Color(0xFF654321)),
      isNotNull,
      reason: 'preload rejected the artwork: its fills have changed',
    );
  });

  test('each theme gets its own text and accent into the artwork', () async {
    await ShiftLockup.preload();

    for (final ShiftThemeId id in ShiftThemeId.values) {
      final ShiftColors c = ShiftColors.forTheme(id);
      final String svg = ShiftLockup.forColors(c.text, c.accent)!;

      String hex(Color x) {
        String ch(double v) =>
            (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
        return '#${ch(x.r)}${ch(x.g)}${ch(x.b)}'.toUpperCase();
      }

      expect(svg, contains(hex(c.text)), reason: '${id.name} wordmark');
      expect(svg, contains(hex(c.accent)), reason: '${id.name} accent');
    }
  });

  test('the retro themes no longer draw the dark theme\'s blue', () async {
    // The reason this was raised: retro is the default, and the lockup's
    // "ai" was arriving in #5B8CFF next to a #FF1A8C app.
    await ShiftLockup.preload();

    for (final ShiftThemeId id in <ShiftThemeId>[
      ShiftThemeId.retro,
      ShiftThemeId.retroLight,
    ]) {
      final ShiftColors c = ShiftColors.forTheme(id);
      final String svg = ShiftLockup.forColors(c.text, c.accent)!;
      expect(svg, isNot(contains('#5B8CFF')), reason: id.name);
    }
  });
}
