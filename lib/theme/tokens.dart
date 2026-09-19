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

  static ShiftThemeId parse(String? value) {
    return ShiftThemeId.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ShiftThemeId.dark,
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

  /// The retro identity on paper rather than on black: the same hot pink
  /// and cyan, printed. Ink is warm near-black, never pure grey, and the
  /// pink is taken down far enough to carry white text.
  static const ShiftColors retroLight = ShiftColors(
    bg: Color(0xFFFCF4E8),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF4E6D5),
    border: Color(0xFFE2CFB8),
    borderStrong: Color(0xFF6F5B49),
    text: Color(0xFF1A120C),
    textMuted: Color(0xFF6B5747),
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
  static const Color bronzeOnLight = Color(0xFF9A5520);
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
