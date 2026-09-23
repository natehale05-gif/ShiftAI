import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_ai/models/models.dart';
import 'package:shift_ai/theme/app_theme.dart';
import 'package:shift_ai/theme/tokens.dart';

/// WCAG relative luminance, then the contrast ratio between two colours.
/// The themes are the design system; this is the arithmetic that says
/// whether a palette actually holds up, rather than whether it looks nice
/// in the one screenshot somebody checked.
double _luminance(Color c) => c.computeLuminance();

double _ratio(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  final double hi = math.max(la, lb);
  final double lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// What each kind of pairing has to clear.
const double kText = 4.5; // body and small text
const double kLarge = 3.0; // 19px+, bold 15px+, and icons
const double kControl = 3.0; // an edge that carries meaning
const double kHairline = 1.25; // a line that only separates

typedef Pair = ({
  Color Function(ShiftColors) fg,
  Color Function(ShiftColors) bg,
  double min,
  String what,
});

final List<Pair> _pairs = <Pair>[
  (
    fg: (ShiftColors c) => c.text,
    bg: (ShiftColors c) => c.bg,
    min: kText,
    what: 'body on the page'
  ),
  (
    fg: (ShiftColors c) => c.text,
    bg: (ShiftColors c) => c.surface,
    min: kText,
    what: 'body on a card'
  ),
  (
    fg: (ShiftColors c) => c.text,
    bg: (ShiftColors c) => c.surfaceRaised,
    min: kText,
    what: 'body on a raised block'
  ),
  (
    fg: (ShiftColors c) => c.text,
    bg: (ShiftColors c) => c.accentSoft,
    min: kText,
    what: 'body on the highlighted row'
  ),
  (
    fg: (ShiftColors c) => c.textMuted,
    bg: (ShiftColors c) => c.bg,
    min: kText,
    what: 'muted on the page'
  ),
  (
    fg: (ShiftColors c) => c.textMuted,
    bg: (ShiftColors c) => c.surface,
    min: kText,
    what: 'muted on a card'
  ),
  (
    fg: (ShiftColors c) => c.textMuted,
    bg: (ShiftColors c) => c.surfaceRaised,
    min: kText,
    what: 'muted on a raised block'
  ),
  (
    fg: (ShiftColors c) => c.accent,
    bg: (ShiftColors c) => c.bg,
    min: kText,
    what: 'accent text on the page'
  ),
  (
    fg: (ShiftColors c) => c.accent,
    bg: (ShiftColors c) => c.surface,
    min: kText,
    what: 'accent text on a card'
  ),
  (
    fg: (ShiftColors c) => c.accent,
    bg: (ShiftColors c) => c.accentSoft,
    min: kText,
    what: 'accent text on its own tint'
  ),
  (
    fg: (ShiftColors c) => c.accent,
    bg: (ShiftColors c) => c.surfaceRaised,
    min: kLarge,
    what: 'accent glyph on a raised block'
  ),
  (
    fg: (ShiftColors c) => c.onAccent,
    bg: (ShiftColors c) => c.accent,
    min: kText,
    what: 'label on a filled button'
  ),
  (
    fg: (ShiftColors c) => c.onAccent,
    bg: (ShiftColors c) => c.accentHover,
    min: kText,
    what: 'label on a hovered button'
  ),
  (
    fg: (ShiftColors c) => c.success,
    bg: (ShiftColors c) => c.bg,
    min: kText,
    what: 'money on the page'
  ),
  (
    fg: (ShiftColors c) => c.success,
    bg: (ShiftColors c) => c.surface,
    min: kText,
    what: 'money on a card'
  ),
  (
    fg: (ShiftColors c) => c.success,
    bg: (ShiftColors c) => c.accentSoft,
    min: kText,
    what: 'money on the you-row'
  ),
  (
    fg: (ShiftColors c) => c.danger,
    bg: (ShiftColors c) => c.bg,
    min: kText,
    what: 'danger text on the page'
  ),
  (
    fg: (ShiftColors c) => c.danger,
    bg: (ShiftColors c) => c.surface,
    min: kText,
    what: 'danger text on a card'
  ),
  (
    fg: (ShiftColors c) => c.warning,
    bg: (ShiftColors c) => c.surface,
    min: kLarge,
    what: 'the warning glyph on a card'
  ),
  (
    fg: (ShiftColors c) => c.sky,
    bg: (ShiftColors c) => c.surface,
    min: kText,
    what: 'sky text on a card'
  ),
  (
    fg: (ShiftColors c) => c.sky,
    bg: (ShiftColors c) => c.surfaceRaised,
    min: kText,
    what: 'the VIDEO tag'
  ),
  (
    fg: (ShiftColors c) => c.onStatus,
    bg: (ShiftColors c) => c.success,
    min: kText,
    what: 'label on success'
  ),
  (
    fg: (ShiftColors c) => c.onStatus,
    bg: (ShiftColors c) => c.danger,
    min: kText,
    what: 'label on danger'
  ),
  (
    fg: (ShiftColors c) => c.onStatus,
    bg: (ShiftColors c) => c.warning,
    min: kText,
    what: 'label on warning'
  ),
  (
    fg: (ShiftColors c) => c.borderStrong,
    bg: (ShiftColors c) => c.surface,
    min: kControl,
    what: 'a strong edge on a card'
  ),
  (
    fg: (ShiftColors c) => c.border,
    bg: (ShiftColors c) => c.bg,
    min: kHairline,
    what: 'a hairline on the page'
  ),
  (
    fg: (ShiftColors c) => c.border,
    bg: (ShiftColors c) => c.surface,
    min: kHairline,
    what: 'a hairline on a card'
  ),
];

void main() {
  test('the medal colours read on paper and apart from one another', () {
    const List<Color> onLight = <Color>[
      TierColors.bronzeOnLight,
      TierColors.silverOnLight,
      TierColors.goldOnLight,
      TierColors.platinumOnLight,
    ];
    for (final ShiftThemeId id in <ShiftThemeId>[
      ShiftThemeId.light,
      ShiftThemeId.retroLight,
    ]) {
      final Color ground = ShiftColors.forTheme(id).bg;
      for (final Color tier in onLight) {
        expect(_ratio(tier, ground), greaterThanOrEqualTo(4.5),
            reason: '$tier on ${id.name}');
      }
    }
    // Bronze and gold were 15° of hue apart at the same darkness, and on
    // the light themes they read as one colour.
    final double bronze = HSLColor.fromColor(TierColors.bronzeOnLight).hue;
    final double gold = HSLColor.fromColor(TierColors.goldOnLight).hue;
    expect((gold - bronze).abs(), greaterThanOrEqualTo(20));
  });

  for (final ShiftThemeId id in ShiftThemeId.values) {
    test('${id.name} carries every pairing the app draws', () {
      final ShiftColors c = ShiftColors.forTheme(id);
      final List<String> failures = <String>[];

      for (final Pair pair in _pairs) {
        final double r = _ratio(pair.fg(c), pair.bg(c));
        if (r < pair.min) {
          failures.add(
            '${pair.what}: ${r.toStringAsFixed(2)} '
            '(needs ${pair.min})',
          );
        }
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('${id.name} ranks its tiers against its own ground', () {
      final ShiftColors c = ShiftColors.forTheme(id);
      for (final TrophyTier tier in TrophyTier.values) {
        // A tier badge is small uppercase text, so it is held to text
        // contrast rather than the looser glyph bar.
        expect(
          _ratio(tier.colorOn(c), c.bg),
          greaterThanOrEqualTo(kLarge),
          reason: '${tier.name} on ${id.name}',
        );
      }
    });

    test('${id.name} is internally ordered', () {
      final ShiftColors c = ShiftColors.forTheme(id);
      final bool dark = c.isDarkGround;
      // Raised blocks sit above cards, which sit above the page — in the
      // direction the ground implies, never the other way.
      if (dark) {
        expect(_luminance(c.surface), greaterThan(_luminance(c.bg)));
        expect(
          _luminance(c.surfaceRaised),
          greaterThan(_luminance(c.surface)),
        );
      } else {
        expect(_luminance(c.surface), greaterThan(_luminance(c.bg)));
        expect(_luminance(c.surfaceRaised), lessThan(_luminance(c.surface)));
      }
      // The strong edge is stronger than the hairline, always.
      expect(
        _ratio(c.borderStrong, c.surface),
        greaterThan(_ratio(c.border, c.surface)),
      );
      // Muted text is quieter than body text, but still text.
      expect(
        _ratio(c.textMuted, c.bg),
        lessThan(_ratio(c.text, c.bg)),
      );
    });
  }

  for (final ShiftThemeId id in ShiftThemeId.values) {
    test('${id.name} leaves no Material colour unclaimed', () {
      final ShiftColors c = ShiftColors.forTheme(id);
      final ColorScheme s = ShiftTheme.build(id).colorScheme;

      // Every colour Material can reach for has to be one of ours. A role
      // left at its default is how a widget nobody themed ends up drawing
      // in Material's baseline purple.
      final Set<Color> ours = <Color>{
        c.bg,
        c.surface,
        c.surfaceRaised,
        c.border,
        c.borderStrong,
        c.text,
        c.textMuted,
        c.accent,
        c.accentHover,
        c.accentSoft,
        c.onAccent,
        c.sky,
        c.success,
        c.warning,
        c.danger,
        c.onStatus,
        Colors.transparent,
      };

      final Map<String, Color> roles = <String, Color>{
        'primary': s.primary,
        'onPrimary': s.onPrimary,
        'primaryContainer': s.primaryContainer,
        'onPrimaryContainer': s.onPrimaryContainer,
        'secondary': s.secondary,
        'onSecondary': s.onSecondary,
        'secondaryContainer': s.secondaryContainer,
        'onSecondaryContainer': s.onSecondaryContainer,
        'tertiary': s.tertiary,
        'onTertiary': s.onTertiary,
        'tertiaryContainer': s.tertiaryContainer,
        'onTertiaryContainer': s.onTertiaryContainer,
        'error': s.error,
        'onError': s.onError,
        'errorContainer': s.errorContainer,
        'onErrorContainer': s.onErrorContainer,
        'surface': s.surface,
        'onSurface': s.onSurface,
        'surfaceDim': s.surfaceDim,
        'surfaceBright': s.surfaceBright,
        'surfaceContainerLowest': s.surfaceContainerLowest,
        'surfaceContainerLow': s.surfaceContainerLow,
        'surfaceContainer': s.surfaceContainer,
        'surfaceContainerHigh': s.surfaceContainerHigh,
        'surfaceContainerHighest': s.surfaceContainerHighest,
        'onSurfaceVariant': s.onSurfaceVariant,
        'outline': s.outline,
        'outlineVariant': s.outlineVariant,
        'inverseSurface': s.inverseSurface,
        'onInverseSurface': s.onInverseSurface,
        'inversePrimary': s.inversePrimary,
        'surfaceTint': s.surfaceTint,
      };

      final List<String> strays = <String>[];
      roles.forEach((String name, Color value) {
        if (!ours.contains(value)) strays.add(name);
      });
      expect(strays, isEmpty, reason: 'off-system roles: ${strays.join(', ')}');
    });

    test('${id.name} states every component the app draws', () {
      final ShiftColors c = ShiftColors.forTheme(id);
      final ThemeData t = ShiftTheme.build(id);

      expect(t.dialogTheme.backgroundColor, c.surface);
      expect(t.bottomSheetTheme.backgroundColor, c.surface);
      expect(t.sliderTheme.activeTrackColor, c.accent);
      expect(t.sliderTheme.inactiveTrackColor, c.surfaceRaised);
      expect(t.progressIndicatorTheme.color, c.accent);
      expect(t.listTileTheme.textColor, c.text);
      expect(t.tabBarTheme.indicatorColor, c.accent);
      expect(t.floatingActionButtonTheme.backgroundColor, c.accent);
      expect(t.textSelectionTheme.cursorColor, c.accent);
      expect(t.snackBarTheme.backgroundColor, c.surfaceRaised);
      expect(t.scaffoldBackgroundColor, c.bg);
      // The elevation tint is what quietly drifts raised surfaces toward
      // the accent; it stays off.
      expect(t.colorScheme.surfaceTint, Colors.transparent);
    });
  }

  test('every theme defines every token', () {
    for (final ShiftThemeId id in ShiftThemeId.values) {
      final ShiftColors c = ShiftColors.forTheme(id);
      final List<Color> tokens = <Color>[
        c.bg,
        c.surface,
        c.surfaceRaised,
        c.border,
        c.borderStrong,
        c.text,
        c.textMuted,
        c.accent,
        c.accentHover,
        c.accentSoft,
        c.onAccent,
        c.sky,
        c.success,
        c.warning,
        c.danger,
        c.onStatus,
      ];
      expect(tokens.length, 16, reason: 'on ${id.name}');
      // A palette that repeats a value has a token doing nothing.
      expect(
        tokens.toSet().length,
        greaterThanOrEqualTo(13),
        reason: '${id.name} reuses too many values',
      );
    }
  });

  // A run's status is read off a five-pixel dot. If two statuses share a
  // colour on any theme, the dot stops carrying information — which is
  // what happened when "in review" used the accent and the retro themes
  // made the accent pink, a hair from danger.
  test('no two run statuses wear the same colour', () {
    for (final ShiftThemeId id in ShiftThemeId.values) {
      final ShiftColors c = ShiftColors.forTheme(id);
      final List<Color> byStatus = <Color>[
        c.accent, // working
        c.warning, // needs you
        c.sky, // in review
        c.success, // done
        c.danger, // failed
      ];
      expect(
        byStatus.toSet().length,
        byStatus.length,
        reason: '${id.name} gives two statuses the same dot',
      );

      // And each has to be visible against the ground it is drawn on.
      for (final Color status in byStatus) {
        expect(
          _ratio(status, c.bg),
          greaterThanOrEqualTo(3),
          reason: '${id.name}: a status dot is too faint on the background',
        );
      }
    }
  });
}
