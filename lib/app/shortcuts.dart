import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_state.dart';
import 'modes.dart';

/// Keyboard shortcuts for a hardware keyboard: the web on a desktop, an
/// iPad with a keyboard, or a laptop.
///
/// - ⌘K / Ctrl+K: a new chat.
/// - ⌘1 to ⌘7: the sections, in sidebar order. Numbers follow what is
///   switched on, so none of them lands on a hidden section.
/// - ⌘, : Settings, as on a Mac.
/// - Esc: close whatever is on top, whether a pushed page, a sheet or
///   the vault's detail panel.
///
/// Both ⌘ and Ctrl are bound, so the same keys work on a Mac and on
/// Windows or Linux. These sit above the navigator, so they work from a
/// page pushed over the shell as well as from the shell itself.
class ShiftShortcuts extends StatelessWidget {
  const ShiftShortcuts({
    required this.state,
    required this.navigator,
    required this.child,
    super.key,
  });

  final AppState state;
  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  /// The sidebar's order: modes, then the workspace.
  List<VoidCallback> _sections() => <VoidCallback>[
        for (final ShiftMode m in state.visibleModes) () => state.setMode(m),
        for (final Surface s in state.visibleWorkspace)
          () => state.setSurface(s),
      ];

  void _toShell() => navigator.currentState?.popUntil((Route<dynamic> r) {
        return r.isFirst;
      });

  void _escape() {
    final NavigatorState? nav = navigator.currentState;
    if (nav != null && nav.canPop()) {
      nav.maybePop();
    } else if (state.selectedVaultId != null) {
      state.selectVaultItem(null);
    }
  }

  static Iterable<SingleActivator> _both(LogicalKeyboardKey key) =>
      <SingleActivator>[
        SingleActivator(key, meta: true),
        SingleActivator(key, control: true),
      ];

  static const List<LogicalKeyboardKey> _digits = <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  @override
  Widget build(BuildContext context) {
    if (!state.signedIn) return child;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        for (final SingleActivator a in _both(LogicalKeyboardKey.keyK))
          a: () {
            _toShell();
            state.clearThread();
            state.setMode(ShiftMode.suite);
          },
        for (final SingleActivator a in _both(LogicalKeyboardKey.comma))
          a: () {
            _toShell();
            state.setSurface(Surface.settings);
          },
        for (int i = 0; i < _digits.length; i++)
          for (final SingleActivator a in _both(_digits[i]))
            a: () {
              final List<VoidCallback> sections = _sections();
              if (i >= sections.length) return;
              _toShell();
              sections[i]();
            },
        const SingleActivator(LogicalKeyboardKey.escape): _escape,
      },
      // Something has to hold focus for the shortcuts to hear a key when
      // nothing else on screen is focused.
      child: Focus(autofocus: true, child: child),
    );
  }
}
