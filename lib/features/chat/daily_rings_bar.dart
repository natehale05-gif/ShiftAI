import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../state/daily_rings.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';

/// Three rings for three ways a day in SHIFT counts as productive: made
/// something, put work in front of people, checked where you stand.
/// Apple Fitness's Move/Exercise/Stand, redrawn for a creator suite instead
/// of a watch — always visible above the composer, closed the moment the
/// matching action lands (see the `_closeRing` calls in `AppState`), never
/// something to check a box on by hand.
class DailyRingsBar extends StatelessWidget {
  const DailyRingsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final DailyRings rings = state.rings;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.x5, Space.x4, Space.x5, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: Space.x3,
            ),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: Radii.lgAll,
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 40,
                  height: 40,
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
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: Space.x3,
                        runSpacing: 2,
                        children: <Widget>[
                          _RingLabel(
                            label: 'Create',
                            closed: rings.create,
                            color: c.danger,
                          ),
                          _RingLabel(
                            label: 'Publish',
                            closed: rings.publish,
                            color: c.success,
                          ),
                          _RingLabel(
                            label: 'Compete',
                            closed: rings.compete,
                            color: c.sky,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (rings.streak > 0) ...<Widget>[
                  const SizedBox(width: Space.x3),
                  Icon(Icons.local_fire_department_rounded,
                      size: 18, color: c.warning),
                  const SizedBox(width: 2),
                  Text('${rings.streak}', style: ShiftType.mono(c.warning, size: 16)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingLabel extends StatelessWidget {
  const _RingLabel({
    required this.label,
    required this.closed,
    required this.color,
  });

  final String label;
  final bool closed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: closed ? color : Colors.transparent,
            border: Border.all(color: closed ? color : c.border),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: ShiftType.caption(closed ? c.text : c.textMuted)),
      ],
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
      final double radius =
          outerRadius - i * (thickness + gap) - thickness / 2;
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
    if (track != oldDelegate.track || rings.length != oldDelegate.rings.length) {
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
