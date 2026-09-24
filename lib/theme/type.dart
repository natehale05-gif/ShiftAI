import 'package:flutter/material.dart';

/// The ShiftAi type scale: Outfit for display, Manrope for copy, and
/// Manrope's tabular figures wherever numbers line up.
///
/// IBM Plex Mono used to set labels, buttons and tabs in tracked uppercase.
/// The Apple pass retired that, and its last use (a failure's details)
/// moved to tabular figures, so the face is no longer bundled. It was
/// 134 KB of every first load on the web.
///
/// The faces are bundled in `assets/fonts/`, so the app draws its own type
/// with no network call. Outfit and Manrope are variable, hence the
/// `fontVariations` alongside `fontWeight`.
abstract final class ShiftType {
  static const String _display = 'Outfit';
  static const String _body = 'Manrope';

  static const List<String> _displayFallback = <String>[
    'Helvetica Neue',
    'Arial',
  ];
  static const List<String> _bodyFallback = <String>[
    'Helvetica Neue',
    'Arial',
  ];

  static TextStyle _outfit({
    required double size,
    required double lineHeight,
    required int weight,
    double? letterSpacing,
    required Color color,
  }) {
    return TextStyle(
      fontFamily: _display,
      fontFamilyFallback: _displayFallback,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle _manrope({
    required double size,
    required double lineHeight,
    required int weight,
    required Color color,
  }) {
    return TextStyle(
      fontFamily: _body,
      fontFamilyFallback: _bodyFallback,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: FontWeight.values[(weight ~/ 100) - 1],
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
      color: color,
    );
  }

  static TextStyle displayXl(Color color) => _outfit(
        size: 56,
        lineHeight: 60,
        weight: 300,
        letterSpacing: -0.56,
        color: color,
      );

  static TextStyle displayL(Color color) => _outfit(
        size: 40,
        lineHeight: 46,
        weight: 300,
        letterSpacing: -0.4,
        color: color,
      );

  static TextStyle heading(Color color) =>
      _outfit(size: 28, lineHeight: 34, weight: 500, color: color);

  static TextStyle subheading(Color color) =>
      _outfit(size: 20, lineHeight: 28, weight: 500, color: color);

  static TextStyle body(Color color) =>
      _manrope(size: 17, lineHeight: 28, weight: 400, color: color);

  static TextStyle bodySm(Color color) =>
      _manrope(size: 15, lineHeight: 24, weight: 400, color: color);

  static TextStyle bodyStrong(Color color) =>
      _manrope(size: 15, lineHeight: 24, weight: 600, color: color);

  static TextStyle caption(Color color) =>
      _manrope(size: 13, lineHeight: 20, weight: 500, color: color);

  // Apple's text ramp, by its names, for the sizes that had been set by
  // hand with copyWith(fontSize: …): 26, 18 and 16 were on no ramp at all.
  // body (17), bodySm (15, subheadline), caption (13, footnote),
  // subheading (20, title 3) and heading (28, title 1) above already are.

  /// Headline: 17 semibold. A row's own name, a bar's title.
  static TextStyle headline(Color color) =>
      _manrope(size: 17, lineHeight: 24, weight: 600, color: color);

  /// Callout: 16. A list row's text where 17 is too loud and 15 too quiet.
  static TextStyle callout(Color color) =>
      _manrope(size: 16, lineHeight: 22, weight: 400, color: color);

  /// Title 2: 22. A figure or name that leads a card.
  static TextStyle title2(Color color) =>
      _outfit(size: 22, lineHeight: 28, weight: 600, color: color);

  /// Title 1: 28, bold. A document's own title in its editor.
  static TextStyle title1(Color color) => _outfit(
        size: 28,
        lineHeight: 34,
        weight: 700,
        letterSpacing: -0.2,
        color: color,
      );

  /// A screen's own title, under its back link — the large title a
  /// navigation stack opens on.
  static TextStyle largeTitle(Color color) => _outfit(
        size: 32,
        lineHeight: 38,
        weight: 700,
        letterSpacing: -0.3,
        color: color,
      );

  /// A section's own heading — "Bronze", "Standings" — set like a title,
  /// in sentence case, where an uppercase mono eyebrow used to go.
  static TextStyle sectionTitle(Color color) =>
      _outfit(size: 20, lineHeight: 26, weight: 600, color: color);

  /// Numbers that line up in a column — money, ranks, counts, the clock —
  /// in the copy face rather than a mono one. Tabular figures give the
  /// alignment mono was being used for, without setting every figure like
  /// a terminal readout.
  ///
  /// [weight] goes through the `wght` axis. These faces are variable, so a
  /// `copyWith(fontWeight:)` on any style here changes nothing visible —
  /// the variation wins — and a weight has to be asked for up front.
  static TextStyle figures(
    Color color, {
    double size = 15,
    int weight = 600,
  }) =>
      _manrope(
        size: size,
        lineHeight: size * 1.35,
        weight: weight,
        color: color,
      ).copyWith(
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      );

  /// Copy at a chosen size and weight, for the few places the fixed scale
  /// has no step — through the `wght` axis, for the reason [figures] gives.
  static TextStyle copy(
    Color color, {
    required double size,
    int weight = 400,
    double? lineHeight,
  }) =>
      _manrope(
        size: size,
        lineHeight: lineHeight ?? size * 1.35,
        weight: weight,
        color: color,
      );
}
