import 'package:flutter/material.dart';

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
    widget.state.addListener(_syncBrowserChrome);
    _syncBrowserChrome();
  }

  @override
  void dispose() {
    widget.state.removeListener(_syncBrowserChrome);
    widget.state.dispose();
    super.dispose();
  }

  void _syncBrowserChrome() => applyBrowserChrome(
        ShiftColors.forTheme(widget.state.themeId).bg,
        theme: widget.state.themeId.name,
      );

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: widget.state,
      child: AnimatedBuilder(
        animation: widget.state,
        builder: (BuildContext context, _) {
          return MaterialApp(
            title: 'SHIFT AI',
            debugShowCheckedModeBanner: false,
            theme: ShiftTheme.build(widget.state.themeId),
            home: widget.state.signedIn
                ? const ShiftShell()
                : const SignInScreen(),
          );
        },
      ),
    );
  }
}
