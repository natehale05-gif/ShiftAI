import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../state/daily_rings.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';

/// Three rings for three ways a day in SHIFT counts as productive: made
/// something, put work in front of people, checked where you stand. Apple
/// Fitness's Move/Exercise/Stand, redrawn for a creator suite instead of a
/// watch — closed the moment the matching action lands (see the
/// `_closeRing` calls in `AppState`), never something to check a box on by
/// hand.
///
/// Lives in the Suite app bar: a glance at the glyph is enough most of the
/// time, and the full breakdown is one tap away — the same fullscreen page
/// the app opens with, see [showDailyRingsFullScreen].
class DailyRingsButton extends StatelessWidget {
  const DailyRingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final DailyRings rings = state.rings;

    return IconButton(
      tooltip: rings.allClosed
          ? 'All three closed today'
          : '${rings.closedCount} of 3 closed today',
      onPressed: () => showDailyRingsFullScreen(context),
      icon: SizedBox(
        width: 26,
        height: 26,
        child: CustomPaint(
          painter: _RingsPainter(
            track: c.border,
            rings: <_Ring>[
              _Ring(rings.create, c.danger),
              _Ring(rings.publish, c.success),
              _Ring(rings.compete, c.sky),
            ],
          ),
        ),
      ),
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    );
  }
}

/// Opens today's rings full screen. Shared by [DailyRingsButton] and by the
/// app opening or coming back from the background — see
/// `ShiftShell._showRings` — so tapping the glyph and reopening the app
/// land on the exact same thing: this is what "open with the rings" means,
/// not a sheet that leaves the rest of the screen showing underneath.
Future<void> showDailyRingsFullScreen(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext routeContext) => const _RingsScreen(),
    ),
  );
}

/// Fullscreen, and fullscreen that the app throws up by itself every time
/// it comes back needs the way out people already try: dragging it down.
/// The X stays for anyone who does not.
class _RingsScreen extends StatefulWidget {
  const _RingsScreen();

  @override
  State<_RingsScreen> createState() => _RingsScreenState();
}

class _RingsScreenState extends State<_RingsScreen> {
  /// How far the page comes down before it leaves — far enough that the
  /// bounce at the top of a real scroll does not throw somebody out of the
  /// screen they were reading.
  static const double _dismissAt = 110;

  bool _leaving = false;

  /// The drag is the scroll view's own overscroll rather than a
  /// [GestureDetector] wrapped round it: a detector deep enough to catch
  /// the drag also wins the gesture arena outright, which would cost
  /// scrolling on a screen too short for the three rows. Bouncing physics
  /// gives the page its follow-the-finger travel for free, and a flick
  /// registers as well as a slow drag because the ballistic settle carries
  /// past the threshold too.
  bool _onScroll(ScrollNotification note) {
    if (_leaving || note.metrics.pixels > -_dismissAt) return false;
    _leaving = true;
    Navigator.of(context).maybePop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final DailyRings rings = state.rings;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          icon: Icon(Icons.close_rounded, color: c.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          // The scroll view is stretched to the whole body rather than
          // sized to the rings, so the drag is caught anywhere on the
          // page and not only on the few hundred pixels of content.
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: Space.x5),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: CustomPaint(
                              painter: _RingsPainter(
                                track: c.border,
                                rings: <_Ring>[
                                  _Ring(rings.create, c.danger),
                                  _Ring(rings.publish, c.success),
                                  _Ring(rings.compete, c.sky),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.x6),
                          Text(
                            rings.allClosed
                                ? 'All three closed today'
                                : '${rings.closedCount} of 3 closed today',
                            textAlign: TextAlign.center,
                            style: ShiftType.heading(c.text),
                          ),
                          if (rings.streak > 0) ...<Widget>[
                            const SizedBox(height: Space.x2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(Icons.local_fire_department_rounded,
                                    size: 18, color: c.warning),
                                const SizedBox(width: 4),
                                Text(
                                  '${rings.streak} day streak',
                                  style: ShiftType.body(c.warning),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: Space.x7),
                          _RingRow(
                            label: 'Create',
                            detail: 'Made something today',
                            closed: rings.create,
                            color: c.danger,
                          ),
                          _RingRow(
                            label: 'Publish',
                            detail: 'Published or hearted a piece',
                            closed: rings.publish,
                            color: c.success,
                          ),
                          _RingRow(
                            label: 'Compete',
                            detail: 'Checked where you stand — harder to '
                                'close the higher you are placed',
                            closed: rings.compete,
                            color: c.sky,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RingRow extends StatelessWidget {
  const _RingRow({
    required this.label,
    required this.detail,
    required this.closed,
    required this.color,
  });

  final String label;
  final String detail;
  final bool closed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.x2),
      child: Row(
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: closed ? color : Colors.transparent,
              border: Border.all(color: closed ? color : c.border, width: 1.5),
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: ShiftType.body(c.text)),
                Text(detail, style: ShiftType.caption(c.textMuted)),
              ],
            ),
          ),
          if (closed) Icon(Icons.check_rounded, color: color, size: 20),
        ],
      ),
    );
  }
}

class _Ring {
  const _Ring(this.closed, this.color);
  final bool closed;
  final Color color;
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.track, required this.rings});

  final Color track;
  final List<_Ring> rings;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double outerRadius = size.shortestSide / 2;
    final double thickness = outerRadius / (rings.length * 1.6);
    const double gap = 2;

    for (int i = 0; i < rings.length; i++) {
      final double radius = outerRadius - i * (thickness + gap) - thickness / 2;
      if (radius <= 0) continue;
      final Rect bounds = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        bounds,
        0,
        2 * math.pi,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness,
      );
      if (rings[i].closed) {
        canvas.drawArc(
          bounds,
          -math.pi / 2,
          // Just short of a full turn so the round start and end caps do
          // not overlap into a visible seam at the top.
          2 * math.pi * 0.998,
          false,
          Paint()
            ..color = rings[i].color
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) {
    if (track != oldDelegate.track ||
        rings.length != oldDelegate.rings.length) {
      return true;
    }
    for (int i = 0; i < rings.length; i++) {
      if (rings[i].closed != oldDelegate.rings[i].closed ||
          rings[i].color != oldDelegate.rings[i].color) {
        return true;
      }
    }
    return false;
  }
}
