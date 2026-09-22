import 'package:flutter/material.dart';

import 'app/app.dart';
import 'state/app_state.dart';
import 'theme/tokens.dart';
import 'theme/type.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShiftBoot());
}

/// Loading used to happen before the first frame, which is fine against a
/// catalogue held in memory and a blank screen against a server on the
/// other side of a network. The app now starts immediately and fills in.
class ShiftBoot extends StatefulWidget {
  const ShiftBoot({super.key});

  @override
  State<ShiftBoot> createState() => _ShiftBootState();
}

class _ShiftBootState extends State<ShiftBoot> {
  late final Future<AppState> _state = _boot();

  /// The lockup is recoloured to the live theme, so its artwork has to be
  /// in hand before the first frame — otherwise the top bar draws the
  /// unrecoloured file and then swaps. Started alongside the store rather
  /// than before it, because neither waits on the other.
  Future<AppState> _boot() async {
    final Future<void> artwork = ShiftLockup.preload();
    final AppState state = await AppState.load();
    await artwork;
    return state;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _state,
      builder: (BuildContext context, AsyncSnapshot<AppState> snap) {
        if (snap.hasData) return ShiftApp(state: snap.data!);
        // load() answers even when the engine refuses, so an error here is
        // the store itself failing — a corrupt preferences file, say.
        return _BootScreen(error: snap.error);
      },
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    // Deliberately not themed: the theme lives in the state being loaded.
    // These are ShiftColors.retro, which is both the theme a new account
    // opens on and the colour the page behind the app is painted, so the
    // hand-off either side of this screen is invisible. They have to move
    // together with that default.
    const Color bg = Color(0xFF0A0A0F);
    const Color muted = Color(0xFFBFBFBF);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: bg,
        body: Center(
          child: error == null
              // A quiet spinner, not a line of tracked capitals: the fonts
              // may not have loaded yet, and the app is usually up before
              // anyone could read one.
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: muted,
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(Space.x6),
                  child: Text(
                    'SHIFT AI could not start.\n\n$error',
                    textAlign: TextAlign.center,
                    style: ShiftType.bodySm(muted),
                  ),
                ),
        ),
      ),
    );
  }
}
