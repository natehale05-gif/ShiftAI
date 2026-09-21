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
/// Lives in the Suite app bar rather than a full-width card above the
/// composer: a glance at the glyph is enough most of the time, and the
/// breakdown is one tap away in a sheet rather than permanently on screen.
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
      onPressed: () => showDailyRingsSheet(context),
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

/// Opens today's rings in a sheet. Shared by [DailyRingsButton] and by the
/// app opening or coming back from the background — see
/// `ShiftShell._showRings` — so tapping the glyph and reopening the app
/// land on the exact same thing.
Future<void> showDailyRingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => const _RingsSheet(),
  );
}

class _RingsSheet extends StatelessWidget {
  const _RingsSheet();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final DailyRings rings = state.rings;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x5, 0, Space.x5, Space.x5),
        // A short window (a phone in landscape, a small test surface) can
        // leave less height than this content wants; scrolling is the
        // fallback rather than an overflow banner nobody asked to see.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  SizedBox(
                    width: 48,
                    height: 48,
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
                  const SizedBox(width: Space.x4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          rings.allClosed
                              ? 'All three closed today'
                              : '${rings.closedCount} of 3 closed today',
                          style: ShiftType.bodyStrong(c.text),
                        ),
                        if (rings.streak > 0) ...<Widget>[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.local_fire_department_rounded,
                                  size: 16, color: c.warning),
                              const SizedBox(width: 2),
                              Text(
                                '${rings.streak} day streak',
                                style: ShiftType.bodySm(c.warning),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x5),
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
