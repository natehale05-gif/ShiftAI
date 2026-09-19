import 'package:flutter/material.dart';

import '../features/auth/sign_in_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'shell.dart';

class ShiftApp extends StatefulWidget {
  const ShiftApp({required this.state, super.key});

  final AppState state;

  @override
  State<ShiftApp> createState() => _ShiftAppState();
}

class _ShiftAppState extends State<ShiftApp> {
  @override
  void dispose() {
    widget.state.dispose();
    super.dispose();
  }

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
