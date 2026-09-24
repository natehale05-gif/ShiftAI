import 'package:flutter/material.dart';

/// The four themes SHIFT ships. `dark` is the default and `light` is the
/// alternate; the two retro themes carry the older SHIFT identity for
/// branded surfaces and campaign moments, on black and on paper.
enum ShiftThemeId { dark, light, retro, retroLight }

extension ShiftThemeIdLabel on ShiftThemeId {
  String get label => switch (this) {
        ShiftThemeId.dark => 'Dark',
        ShiftThemeId.light => 'Light',
        ShiftThemeId.retro => 'Retro neon',
        ShiftThemeId.retroLight => 'Retro light',
      };

  String get storageValue => name;

  /// The retro pair, or the house pair.
  bool get isRetro =>
      this == ShiftThemeId.retro || this == ShiftThemeId.retroLight;

  /// This theme's partner for [brightness], within its own pair: Retro
  /// neon and Retro light, or Dark and Light. Following the system keeps
  /// the style someone picked and only changes day for night.
  ShiftThemeId forBrightness(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    if (isRetro) return dark ? ShiftThemeId.retro : ShiftThemeId.retroLight;
    return dark ? ShiftThemeId.dark : ShiftThemeId.light;
  }

  /// Retro neon is the default a new account opens on. An account that
  /// has already chosen a theme keeps it: its name is in the blob and is
  /// matched here, so this fallback only applies when nothing was stored.
  static ShiftThemeId parse(String? value) {
    return ShiftThemeId.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ShiftThemeId.retro,
    );
  }
}

/// Every colour token in the SHIFT design system, carried on ThemeData so a
/// widget reads `ShiftColors.of(context).accent` and never a literal hex.
@immutable
class ShiftColors extends ThemeExtension<ShiftColors> {
  const ShiftColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.onAccent,
    required this.sky,
    required this.success,
    required this.warning,
    required this.danger,
    required this.onStatus,
  });

  final Color bg;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color onAccent;
  final Color sky;
  final Color success;
  final Color warning;
  final Color danger;
  final Color onStatus;

  static ShiftColors of(BuildContext context) =>
      Theme.of(context).extension<ShiftColors>() ?? dark;

  static const ShiftColors dark = ShiftColors(
    bg: Color(0xFF0E1628),
    surface: Color(0xFF16203A),
    surfaceRaised: Color(0xFF1E2A48),
    border: Color(0xFF2A3A5E),
    borderStrong: Color(0xFF5E74A6),
    text: Color(0xFFF2F5FA),
    textMuted: Color(0xFFA7B4CC),
    accent: Color(0xFF5B8CFF),
    accentHover: Color(0xFF7BA2FF),
    accentSoft: Color(0xFF17254A),
    onAccent: Color(0xFF0E1628),
    sky: Color(0xFF56CCF8),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    onStatus: Color(0xFF0E1628),
  );

  static const ShiftColors light = ShiftColors(
    bg: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEAEEF6),
    border: Color(0xFFD6DEEC),
    borderStrong: Color(0xFF6B7A96),
    text: Color(0xFF0E1628),
    textMuted: Color(0xFF4A5872),
    accent: Color(0xFF1F5AE6),
    accentHover: Color(0xFF1848BE),
    accentSoft: Color(0xFFE4ECFF),
    onAccent: Color(0xFFFFFFFF),
    sky: Color(0xFF096A8A),
    success: Color(0xFF13702F),
    warning: Color(0xFFB45309),
    danger: Color(0xFFCE2020),
    onStatus: Color(0xFFFFFFFF),
  );

  static const ShiftColors retro = ShiftColors(
    bg: Color(0xFF0A0A0F),
    surface: Color(0xFF14141A),
    surfaceRaised: Color(0xFF1F1F26),
    border: Color(0xFF2A2A31),
    borderStrong: Color(0xFFBFBFBF),
    text: Color(0xFFFFFFFF),
    textMuted: Color(0xFFBFBFBF),
    accent: Color(0xFFFF1A8C),
    // Hover is the accent moved toward the ground's opposite, not a
    // different hue: the purple it used to be could not carry the dark
    // label a filled button puts on it.
    accentHover: Color(0xFFFF54A8),
    accentSoft: Color(0xFF2A0A1C),
    onAccent: Color(0xFF0A0A0F),
    sky: Color(0xFF00E5FF),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    onStatus: Color(0xFF0A0A0F),
  );

  /// The retro identity on white rather than on black: the same hot pink
  /// and cyan, printed. The pink is taken down far enough to carry white
  /// text.
  ///
  /// White, not cream. The warm ground this had (`#FCF4E8`, with beige
  /// surfaces and brown text to match) read as aged paper rather than as
  /// the light half of the retro pair.
  ///
  /// The page is a hair off white rather than `#FFFFFF` because a card has
  /// to sit above the page it is on, and on a light ground that means
  /// *lighter* — there is nothing above pure white to raise a card to.
  /// `theme_contrast_test.dart` holds that ordering for every theme, and
  /// it is why the plain Light theme's page is `#F4F6FA` rather than white.
  static const ShiftColors retroLight = ShiftColors(
    bg: Color(0xFFF7F7F8),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEDEDEF),
    border: Color(0xFFD8D8DC),
    borderStrong: Color(0xFF55555C),
    // Retro neon's own ground, inverted onto white, so the pair reads as
    // one identity in two directions.
    text: Color(0xFF0A0A0F),
    textMuted: Color(0xFF5F5F67),
    accent: Color(0xFFC4005F),
    accentHover: Color(0xFF99004A),
    accentSoft: Color(0xFFFFE1EE),
    onAccent: Color(0xFFFFFFFF),
    sky: Color(0xFF0A6E88),
    success: Color(0xFF15642F),
    warning: Color(0xFF965700),
    danger: Color(0xFFBC241D),
    onStatus: Color(0xFFFFFFFF),
  );

  static ShiftColors forTheme(ShiftThemeId id) => switch (id) {
        ShiftThemeId.dark => dark,
        ShiftThemeId.light => light,
        ShiftThemeId.retro => retro,
        ShiftThemeId.retroLight => retroLight,
      };

  /// True where the ground is dark enough to need light chrome.
  bool get isDarkGround =>
      ThemeData.estimateBrightnessForColor(bg) == Brightness.dark;

  @override
  ShiftColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? accentHover,
    Color? accentSoft,
    Color? onAccent,
    Color? sky,
    Color? success,
    Color? warning,
    Color? danger,
    Color? onStatus,
  }) {
    return ShiftColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      sky: sky ?? this.sky,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      onStatus: onStatus ?? this.onStatus,
    );
  }

  @override
  ShiftColors lerp(ThemeExtension<ShiftColors>? other, double t) {
    if (other is! ShiftColors) return this;
    return ShiftColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onStatus: Color.lerp(onStatus, other.onStatus, t)!,
    );
  }
}

/// The `space-*` and `radius-*` scales. Layout code uses these, not bare
/// numbers, so a change to the system lands everywhere at once.
/// The brand's own colours: the ones that are the mark rather than a
/// theme's choice.
///
/// The neon sweep is the logo badge's gradient, sampled off the brand
/// artwork, and it is the same in all four themes for the same reason the
/// badge is — repainting it would be repainting the logo. Everything that
/// is a theme's to choose lives in [ShiftColors] instead.
abstract final class ShiftBrand {
  const ShiftBrand._();

  /// The two ends of the badge's tube, and of anything else drawn to
  /// carry the mark. `assets/brand/shift-ai-lockup.svg` holds the same
  /// pair; `test/lockup_test.dart` fails if the two drift apart.
  static const Color neonStart = Color(0xFFEC01E7);
  static const Color neonEnd = Color(0xFF0061F1);

  /// A point along the sweep: 0 is [neonStart], 1 is [neonEnd].
  static Color neonAt(double t) => Color.lerp(neonStart, neonEnd, t)!;
}

abstract final class Space {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 24;
  static const double x6 = 32;
  static const double x7 = 48;
  static const double x8 = 64;
  static const double maxContentWidth = 1200;
}

/// Trophy and leaderboard tiers. These are the one place the product uses
/// colour outside the token set: a tier has to be legible at a glance, and
/// four ranks cannot all be the accent.
abstract final class TierColors {
  static const Color bronze = Color(0xFFD9853D);
  static const Color silver = Color(0xFFC9D2E0);
  static const Color gold = Color(0xFFFBBF24);
  static const Color platinum = Color(0xFF56CCF8);

  /// The same four ranks, taken down for a light ground. Pale silver and
  /// bright gold are unreadable on paper, and a tier nobody can read is
  /// not a tier.
  // Copper, not brown. At 0xFF9A5520 it sat 15° of hue from gold's
  // 0xFF946400 at the same darkness, and on the light themes the two read
  // as one colour. 5.6:1 on the light ground.
  static const Color bronzeOnLight = Color(0xFFA3461C);
  static const Color silverOnLight = Color(0xFF64707F);
  static const Color goldOnLight = Color(0xFF946400);
  static const Color platinumOnLight = Color(0xFF0A6E88);
}

abstract final class Radii {
  static const Radius sm = Radius.circular(6);
  static const Radius md = Radius.circular(10);
  static const Radius lg = Radius.circular(16);
  static const Radius pill = Radius.circular(999);

  static const BorderRadius smAll = BorderRadius.all(sm);
  static const BorderRadius mdAll = BorderRadius.all(md);
  static const BorderRadius lgAll = BorderRadius.all(lg);
  static const BorderRadius pillAll = BorderRadius.all(pill);
}

/// Ink over photos and video: the play controls, the scrim behind them,
/// the spinner while a clip loads. The same in every theme, because what
/// is under it is the picture, not the ground — white on a light theme's
/// paper would vanish, but white on a video never does.
abstract final class MediaInk {
  /// Text and glyphs drawn on media.
  static const Color onMedia = Color(0xFFFFFFFF);

  /// The dark wash under them, used at an alpha.
  static const Color scrim = Color(0xFF000000);
}

/// The colour of a drop shadow, at an alpha: black under every theme, as
/// on iOS, with the strength chosen per ground at the call site.
abstract final class ShiftShadow {
  static const Color color = Color(0xFF000000);
}
