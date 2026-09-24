import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'type.dart';

/// One palette across every mode: the Code mode's near-black token set from
/// the old prototype is deliberately not used.
abstract final class ShiftTheme {
  static ThemeData build(ShiftThemeId id) {
    final c = ShiftColors.forTheme(id);
    final brightness = c.isDarkGround ? Brightness.dark : Brightness.light;

    // Every role is filled. A role left out falls back to Material's own
    // baseline palette, which is how an un-themed widget ends up drawing
    // in a colour this product does not own.
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accent,
      secondary: c.sky,
      onSecondary: c.onStatus,
      secondaryContainer: c.surfaceRaised,
      onSecondaryContainer: c.text,
      tertiary: c.success,
      onTertiary: c.onStatus,
      tertiaryContainer: c.surfaceRaised,
      onTertiaryContainer: c.text,
      error: c.danger,
      onError: c.onStatus,
      errorContainer: c.surfaceRaised,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.text,
      surfaceDim: c.bg,
      surfaceBright: c.surfaceRaised,
      surfaceContainerLowest: c.bg,
      surfaceContainerLow: c.bg,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surface,
      surfaceContainerHighest: c.surfaceRaised,
      onSurfaceVariant: c.textMuted,
      outline: c.borderStrong,
      outlineVariant: c.border,
      inverseSurface: c.text,
      onInverseSurface: c.bg,
      inversePrimary: c.accentHover,
      // Material tints raised surfaces with the primary colour as they
      // rise. SHIFT states its own surfaces, so the tint is switched off
      // rather than drifting every card toward the accent.
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      // iOS behaviour on every platform, the Pixel's web app included:
      // screens slide in from the right and swipe back from the edge,
      // lists bounce at their ends, text selection uses iOS handles, and
      // every .adaptive widget draws its Cupertino self. Without this
      // the app read as iOS-styled Android: Material page fades, a glow
      // at the end of a list, the ripple below.
      platform: TargetPlatform.iOS,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
        },
      ),
      // The Cupertino widgets (alerts, switches, the activity indicator)
      // take the accent and the ground from this product's tokens rather
      // than system blue.
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: c.accent,
        primaryContrastingColor: c.onAccent,
        scaffoldBackgroundColor: c.bg,
        barBackgroundColor: c.surface,
      ),
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      // Buttons keep the 44px minimum set below rather than Material's own
      // 48px tap padding, so a control is exactly as tall as it is drawn.
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      dividerColor: c.border,
      extensions: <ThemeExtension<dynamic>>[c],
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      // Pointer feedback, once, in the theme: every row and card gets the
      // same lift on hover and the same quiet press. A press dims, the
      // way a row does on iOS; there is no ripple spreading from the
      // finger, which is Android's and nowhere in Apple's software.
      hoverColor: c.surfaceRaised.withValues(alpha: 0.55),
      splashColor: Colors.transparent,
      highlightColor: c.surfaceRaised.withValues(alpha: 0.6),
      textTheme: TextTheme(
        displayLarge: ShiftType.displayXl(c.text),
        displayMedium: ShiftType.displayL(c.text),
        headlineMedium: ShiftType.heading(c.text),
        titleLarge: ShiftType.subheading(c.text),
        bodyLarge: ShiftType.body(c.text),
        bodyMedium: ShiftType.bodySm(c.text),
        bodySmall: ShiftType.caption(c.textMuted),
        // Material reaches for labelLarge on dialog actions, chips and
        // tabs it builds itself; set in the copy face, not tracked mono.
        labelLarge: ShiftType.copy(c.text, size: 15, weight: 600),
        labelSmall: ShiftType.caption(c.textMuted),
      ),
      iconTheme: IconThemeData(color: c.textMuted, size: 20),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll<Color>(c.border),
        radius: Radii.pill,
        thickness: const WidgetStatePropertyAll<double>(6),
      ),
      splashFactory: NoSplash.splashFactory,
      // iOS navigation bars: flat, the ground colour, the title centred
      // in the headline weight, and no shadow when content scrolls under.
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: ShiftType.headline(c.text),
        iconTheme: IconThemeData(color: c.text, size: 22),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: Space.x4),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          // Sentence case in the copy face. Tracked uppercase mono made
          // every primary action read like a terminal command.
          textStyle: ShiftType.copy(c.onAccent, size: 15, weight: 600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: Space.x4),
          side: BorderSide(color: c.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
          textStyle: ShiftType.bodyStrong(c.text),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          minimumSize: const Size(0, 44),
          textStyle: ShiftType.bodyStrong(c.accent),
        ),
      ),
      // A filled field with no outline until it has focus, rather than a
      // box drawn round every input on the page.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceRaised,
        hintStyle: ShiftType.bodySm(c.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        border: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.mdAll,
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceRaised,
        contentTextStyle: ShiftType.bodySm(c.text),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.mdAll),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: Radii.smAll,
          border: Border.all(color: c.border),
        ),
        textStyle: ShiftType.caption(c.text),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        titleTextStyle: ShiftType.subheading(c.text),
        contentTextStyle: ShiftType.bodySm(c.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radii.lg),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.surfaceRaised,
        thumbColor: c.accent,
        overlayColor: c.accentSoft,
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceRaised,
        circularTrackColor: c.surfaceRaised,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textMuted,
        textColor: c.text,
        selectedColor: c.accent,
        tileColor: Colors.transparent,
        selectedTileColor: c.accentSoft,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: c.text,
        unselectedLabelColor: c.textMuted,
        indicatorColor: c.accent,
        dividerColor: c.border,
        labelStyle: ShiftType.bodyStrong(c.text),
        unselectedLabelStyle: ShiftType.body(c.textMuted),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: c.textMuted),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accentSoft,
        selectionHandleColor: c.accent,
      ),
    );
  }
}
