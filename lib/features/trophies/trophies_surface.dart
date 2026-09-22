import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/modes.dart';
import '../../app/shell.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';

/// Points first, then the shelf. A trophy is worth what its tier is worth,
/// and every card says how far along you are and how rare it is.
class TrophiesSurface extends StatelessWidget {
  const TrophiesSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.x5,
            Space.x5,
            Space.x5,
            Space.x6,
          ),
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ScreenBreadcrumb(
                      parent: 'Create',
                      title: 'Trophies',
                      onBack: () => state.setSurface(Surface.suite),
                    ),
                    const SizedBox(height: Space.x5),
                    const EngineBanner(),
                    if (state.trophies.isEmpty)
                      const _NoShelfYet()
                    else ...<Widget>[
                      const _PointsCard(),
                      // One shelf per tier, cheapest first — the order they
                      // are usually earned in, so the eye starts on what is
                      // already won and walks up to what is left.
                      for (final TrophyTier tier in TrophyTier.values)
                        if (state.trophies.any((Trophy t) => t.tier == tier))
                          _TierShelf(
                            tier: tier,
                            trophies: state.trophies
                                .where((Trophy t) => t.tier == tier)
                                .toList(growable: false),
                          ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The shelf, its progress and its tiers all come from the engine, so
/// with nothing back there is no shelf to draw — not a shelf of zeroes.
class _NoShelfYet extends StatelessWidget {
  const _NoShelfYet();

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool failed = AppScope.of(context).lastError != null;
    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.emoji_events_outlined, size: 28, color: c.textMuted),
          const SizedBox(height: Space.x4),
          Text(
            failed ? 'The shelf did not load' : 'Nothing on the shelf yet',
            style: ShiftType.subheading(c.text),
          ),
          const SizedBox(height: Space.x2),
          Text(
            failed
                ? 'Trophies live on the engine. Once it answers they are '
                    'here, earned ones and all.'
                : 'Make your first piece and the first one is yours.',
            style: ShiftType.bodySm(c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    final List<Trophy> all = state.trophies;
    final List<Trophy> earned =
        all.where((Trophy t) => t.earned).toList(growable: false);
    final int points = earned.fold(0, (int sum, Trophy t) => sum + t.points);
    final int total = all.fold(0, (int sum, Trophy t) => sum + t.points);
    final int percent =
        all.isEmpty ? 0 : ((earned.length / all.length) * 100).round();

    final Trophy? nextUp = all
        .where((Trophy t) => !t.earned)
        .fold<Trophy?>(null, (Trophy? best, Trophy t) {
      if (best == null || t.progress > best.progress) return t;
      return best;
    });

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget left = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Eyebrow('Trophy points'),
                  const SizedBox(height: Space.x2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text('$points', style: ShiftType.displayXl(c.accent)),
                      const SizedBox(width: Space.x3),
                      Text(
                        'of $total',
                        style: ShiftType.mono(c.textMuted, size: 17),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.x1),
                  Text(
                    '${earned.length} OF ${all.length} EARNED · $percent%',
                    style: ShiftType.labelSm(c.textMuted),
                  ),
                ],
              );

              // The per-tier counts used to sit here too. Each tier's shelf
              // now opens with its own, so saying it twice was just noise.
              return left;
            },
          ),
          const SizedBox(height: Space.x4),
          ClipRRect(
            borderRadius: Radii.pillAll,
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : points / total,
              minHeight: 6,
              backgroundColor: c.surfaceRaised,
              valueColor: AlwaysStoppedAnimation<Color>(c.accent),
            ),
          ),
          if (nextUp != null) ...<Widget>[
            const SizedBox(height: Space.x4),
            Row(
              children: <Widget>[
                Icon(Icons.flag_outlined, size: 18, color: c.accent),
                const SizedBox(width: Space.x3),
                Flexible(
                  child: Text(
                    'Next up: ${nextUp.name} — '
                    '${nextUp.requirement.toLowerCase()}',
                    style: ShiftType.body(c.text),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One tier's trophies: a heading with how many are won, then a row of
/// medallions.
class _TierShelf extends StatelessWidget {
  const _TierShelf({required this.tier, required this.trophies});

  final TrophyTier tier;
  final List<Trophy> trophies;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final Color tint = tier.colorOn(c);
    final int won = trophies.where((Trophy t) => t.earned).length;

    return Padding(
      padding: const EdgeInsets.only(top: Space.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: Space.x2),
              Text(tier.label.toUpperCase(), style: ShiftType.label(tint)),
              const SizedBox(width: Space.x3),
              Expanded(child: Divider(height: 1, color: c.border)),
              const SizedBox(width: Space.x3),
              Text(
                '$won / ${trophies.length}',
                style: ShiftType.mono(c.textMuted, size: 12),
              ),
            ],
          ),
          const SizedBox(height: Space.x4),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              // As many medallions as fit at a comfortable size, never
              // fewer than three: two across on a phone read as cards
              // again, which is what this replaced.
              final int columns = (box.maxWidth / 128).floor().clamp(3, 7);
              final double width =
                  (box.maxWidth - Space.x3 * (columns - 1)) / columns;
              return Wrap(
                spacing: Space.x3,
                runSpacing: Space.x4,
                children: trophies
                    .map((Trophy t) => SizedBox(
                          width: width,
                          child: _Medallion(trophy: t),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A trophy as a medal on a shelf.
///
/// These were full-width cards, eighteen of them, each 150 tall, where the
/// only difference between won and not was the colour of a hairline — a
/// long scroll of near-identical boxes. A medallion says both at a glance:
/// a won one is struck in its tier's metal, and one still to win is a dim
/// outline with an arc for how far along it is.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.trophy});

  final Trophy trophy;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool won = trophy.earned;
    final Color tint = trophy.tier.colorOn(c);

    // The medallion clips the requirement entirely, so a tap opens the
    // whole thing rather than leaving it unreadable.
    return InkWell(
      borderRadius: Radii.lgAll,
      onTap: () => _showTrophy(context, trophy),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Medal(trophy: trophy, size: 64),
            const SizedBox(height: Space.x3),
            Text(
              trophy.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ShiftType.bodySm(won ? c.text : c.textMuted)
                  .copyWith(fontWeight: FontWeight.w600, height: 1.2),
            ),
            const SizedBox(height: 2),
            Text(
              won
                  ? '${trophy.points} PTS'
                  : (trophy.progressLabel.isNotEmpty
                      ? trophy.progressLabel
                      : '${trophy.points} PTS'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ShiftType.labelSm(won ? tint : c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The disc itself, shared by the shelf and the detail sheet so a trophy
/// looks the same in both.
class _Medal extends StatelessWidget {
  const _Medal({required this.trophy, required this.size});

  final Trophy trophy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool won = trophy.earned;
    final Color tint = trophy.tier.colorOn(c);

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MedalPainter(
          won: won,
          progress: trophy.progress,
          tint: tint,
          track: c.border,
          ground: c.surfaceRaised,
        ),
        child: Center(
          child: Icon(
            trophy.glyph,
            size: size * 0.40,
            color: won ? tint : c.textMuted,
          ),
        ),
      ),
    );
  }
}

class _MedalPainter extends CustomPainter {
  const _MedalPainter({
    required this.won,
    required this.progress,
    required this.tint,
    required this.track,
    required this.ground,
  });

  final bool won;
  final double progress;
  final Color tint;
  final Color track;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    const double stroke = 3;
    final Rect ring = Rect.fromCircle(
      center: centre,
      radius: radius - stroke / 2,
    );

    if (won) {
      // Struck in its metal: a wash that is brightest top-left, like a
      // face catching the light, a rim, and a finer inner rim.
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 1.1,
            colors: <Color>[
              tint.withValues(alpha: 0.42),
              tint.withValues(alpha: 0.10),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
      canvas.drawCircle(
        centre,
        radius - stroke / 2,
        Paint()
          ..color = tint
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      canvas.drawCircle(
        centre,
        radius - stroke - 4,
        Paint()
          ..color = tint.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      return;
    }

    // Still to win: a plain disc, a track, and an arc for the way there.
    canvas.drawCircle(centre, radius, Paint()..color = ground);
    canvas.drawCircle(
      centre,
      radius - stroke / 2,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final double sweep = progress.clamp(0.0, 1.0) * 2 * math.pi;
    if (sweep > 0) {
      canvas.drawArc(
        ring,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = tint.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_MedalPainter old) =>
      old.won != won ||
      old.progress != progress ||
      old.tint != tint ||
      old.track != track ||
      old.ground != ground;
}

/// Everything the tile has to clip: the full requirement, the tier, how
/// rare it is, and when it was earned.
Future<void> _showTrophy(BuildContext context, Trophy trophy) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ShiftColors.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radii.lg),
    ),
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      final Color tint = trophy.tier.colorOn(c);
      final DateTime? earnedOn = trophy.earnedOn;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _Medal(trophy: trophy, size: 52),
                  const SizedBox(width: Space.x4),
                  Expanded(
                    child: Text(
                      trophy.name,
                      style: ShiftType.subheading(c.text),
                    ),
                  ),
                  Text(
                    '${trophy.points} pts',
                    style: ShiftType.mono(tint, size: 13),
                  ),
                ],
              ),
              const SizedBox(height: Space.x4),
              Text(trophy.requirement, style: ShiftType.body(c.text)),
              const SizedBox(height: Space.x4),
              ClipRRect(
                borderRadius: Radii.pillAll,
                child: LinearProgressIndicator(
                  value: trophy.progress,
                  minHeight: 4,
                  backgroundColor: c.surfaceRaised,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    trophy.earned ? tint : c.borderStrong,
                  ),
                ),
              ),
              const SizedBox(height: Space.x3),
              Text(
                <String>[
                  trophy.tier.label.toUpperCase(),
                  if (trophy.progressLabel.isNotEmpty) trophy.progressLabel,
                  if (trophy.memberPercent > 0)
                    '${Fmt.grouped(trophy.memberPercent)}% OF MEMBERS',
                  if (earnedOn != null)
                    'EARNED ${Fmt.date(earnedOn).toUpperCase()}',
                ].join(' \u00b7 '),
                style: ShiftType.labelSm(c.textMuted),
              ),
              const SizedBox(height: Space.x5),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CLOSE'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
