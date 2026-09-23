import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/auth/sign_in_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../util/system_bars.dart';
import 'shell.dart';

class ShiftApp extends StatefulWidget {
  const ShiftApp({required this.state, super.key});

  final AppState state;

  @override
  State<ShiftApp> createState() => _ShiftAppState();
}

class _ShiftAppState extends State<ShiftApp> {
  @override
  void initState() {
    super.initState();
    // The browser's own chrome is not part of the widget tree, so it has
    // to be told about a theme change rather than rebuilt into one.
    _barsTheme = widget.state.themeId;
    widget.state.addListener(_syncBrowserChrome);
    _syncBrowserChrome();
    watchBrowserInsets();
  }

  /// The theme the system bars were last painted for.
  late ShiftThemeId _barsTheme;

  @override
  void dispose() {
    widget.state.removeListener(_syncBrowserChrome);
    widget.state.dispose();
    super.dispose();
  }

  void _syncBrowserChrome() {
    final ShiftThemeId theme = widget.state.themeId;
    applyBrowserChrome(ShiftColors.forTheme(theme).bg, theme: theme.name);
    if (theme == _barsTheme) return;
    _barsTheme = theme;
    // An iPhone home-screen app only recolours its status bar on launch
    // (see barsNeedRelaunchForTheme). Save first: the write is debounced,
    // and a reload inside that window would come back on the old theme.
    if (barsNeedRelaunchForTheme) {
      unawaited(widget.state.flush().then((_) => relaunchForTheme()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: widget.state,
      child: AnimatedBuilder(
        animation: widget.state,
        builder: (BuildContext context, _) {
          final ShiftColors c = ShiftColors.forTheme(widget.state.themeId);
          return MaterialApp(
            title: 'SHIFT AI',
            debugShowCheckedModeBanner: false,
            theme: ShiftTheme.build(widget.state.themeId),
            // The native builds' own status and navigation bars, set from
            // the theme showing on every rebuild. Nothing set them before,
            // so they kept whatever the platform launched with, whichever
            // theme was showing. Both bars are transparent over the app,
            // which draws edge to edge (main.dart), so only the icons
            // change with the theme. The web ignores all of this;
            // applyBrowserChrome covers it there.
            builder: (BuildContext context, Widget? child) =>
                ValueListenableBuilder<double>(
              valueListenable: browserBottomInset,
              builder: (BuildContext context, double inset, _) => MediaQuery(
                data: _withBottomInset(MediaQuery.of(context), inset),
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: _barsFor(c),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
            home: widget.state.signedIn
                ? const ShiftShell()
                : const SignInScreen(),
          );
        },
      ),
    );
  }
}

SystemUiOverlayStyle _barsFor(ShiftColors c) {
  final Brightness icons = c.isDarkGround ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    // iOS names the ground rather than the icons, so it is the reverse.
    statusBarBrightness: c.isDarkGround ? Brightness.dark : Brightness.light,
    // Transparent, so the app's own ground shows through behind the pill.
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    // No grey scrim laid over the gesture pill on top of the theme's
    // ground.
    systemNavigationBarContrastEnforced: false,
  );
}

/// The web's bottom inset (see watchBrowserInsets) folded into MediaQuery,
/// so SafeArea works there as it does natively. `padding` drops to zero
/// behind an open keyboard, which covers the bar anyway, the same way
/// the engine reports it on a phone.
MediaQueryData _withBottomInset(MediaQueryData mq, double inset) {
  if (inset <= 0) return mq;
  final double viewPadding = math.max(mq.viewPadding.bottom, inset);
  return mq.copyWith(
    viewPadding: mq.viewPadding.copyWith(bottom: viewPadding),
    padding: mq.padding.copyWith(
      bottom: math.max(0, viewPadding - mq.viewInsets.bottom),
    ),
  );
}
