import 'package:flutter/material.dart';

/// The SHIFT type scale. Outfit for display, Manrope for copy, IBM Plex Mono
/// for labels — mono is the accent of the typography, so it is used in short
/// bursts only (buttons, tabs, eyebrows, tags).
///
/// The faces are bundled in `assets/fonts/`, so the app draws its own type
/// with no network call. Outfit and Manrope are variable, hence the
/// `fontVariations` alongside `fontWeight`.
abstract final class ShiftType {
  static const String _display = 'Outfit';
  static const String _body = 'Manrope';
  static const String _mono = 'IBMPlexMono';

  static const List<String> _displayFallback = <String>[
    'Helvetica Neue',
    'Arial',
  ];
  static const List<String> _bodyFallback = <String>[
    'Helvetica Neue',
    'Arial',
  ];
  static const List<String> _monoFallback = <String>[
    'SF Mono',
    'Menlo',
    'Consolas',
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

  static TextStyle _plex({
    required double size,
    required double lineHeight,
    double? letterSpacing,
    required Color color,
  }) {
    return TextStyle(
      fontFamily: _mono,
      fontFamilyFallback: _monoFallback,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: FontWeight.w500,
      letterSpacing: letterSpacing,
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

  /// Uppercase mono, for buttons, tabs and eyebrows.
  static TextStyle label(Color color) => _plex(
        size: 12,
        lineHeight: 16,
        letterSpacing: 12 * 0.18,
        color: color,
      );

  /// Uppercase mono, for tags, badges and table headers.
  static TextStyle labelSm(Color color) => _plex(
        size: 11,
        lineHeight: 14,
        letterSpacing: 11 * 0.16,
        color: color,
      );

  /// Plain mono, for figures that should line up in a column.
  static TextStyle mono(Color color, {double size = 13}) =>
      _plex(size: size, lineHeight: 20, color: color);

  /// A section's own heading — "Bronze", "Standings" — set like a title,
  /// in sentence case, where an uppercase mono eyebrow used to go.
  static TextStyle sectionTitle(Color color) =>
      _outfit(size: 20, lineHeight: 26, weight: 600, color: color);

  /// Numbers that line up in a column — money, ranks, counts, the clock —
  /// in the copy face rather than the mono one. Tabular figures give the
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
