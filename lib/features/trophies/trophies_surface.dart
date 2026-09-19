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
        final int columns = constraints.maxWidth >= 760 ? 2 : 1;

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
                      const SizedBox(height: Space.x5),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.trophies.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: Space.x4,
                          crossAxisSpacing: Space.x4,
                          mainAxisExtent: 150,
                        ),
                        itemBuilder: (BuildContext context, int i) =>
                            _TrophyCard(trophy: state.trophies[i]),
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

              final Widget right = Wrap(
                spacing: Space.x5,
                runSpacing: Space.x3,
                children: TrophyTier.values
                    .map((TrophyTier tier) => _TierCount(tier: tier))
                    .toList(),
              );

              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    left,
                    const SizedBox(height: Space.x4),
                    right,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[left, const Spacer(), right],
              );
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

class _TierCount extends StatelessWidget {
  const _TierCount({required this.tier});

  final TrophyTier tier;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final List<Trophy> inTier =
        state.trophies.where((Trophy t) => t.tier == tier).toList();
    final int earned = inTier.where((Trophy t) => t.earned).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.emoji_events_outlined, size: 22, color: tier.colorOn(c)),
        const SizedBox(height: Space.x2),
        Text(
          '$earned/${inTier.length}',
          style: ShiftType.mono(c.text, size: 13),
        ),
        const SizedBox(height: 2),
        Text(tier.label.toUpperCase(), style: ShiftType.labelSm(c.textMuted)),
      ],
    );
  }
}

class _TrophyCard extends StatelessWidget {
  const _TrophyCard({required this.trophy});

  final Trophy trophy;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool on = trophy.earned;
    final Color tint = trophy.tier.colorOn(c);

    // The card clips the requirement at two lines, so a tap opens the
    // whole thing rather than leaving it unreadable.
    return InkWell(
      borderRadius: Radii.lgAll,
      onTap: () => _showTrophy(context, trophy),
      child: Container(
        padding: const EdgeInsets.all(Space.x4),
        decoration: BoxDecoration(
          color: on ? c.surface : c.bg,
          borderRadius: Radii.lgAll,
          border: Border.all(color: on ? tint : c.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? tint : c.border, width: 1.5),
              ),
              child: Icon(
                trophy.glyph,
                size: 21,
                color: on ? tint : c.textMuted,
              ),
            ),
            const SizedBox(width: Space.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          trophy.name,
                          style: ShiftType.bodyStrong(on ? c.text : c.text)
                              .copyWith(fontSize: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Space.x3),
                      Text(
                        '${trophy.points} pts',
                        style: ShiftType.mono(
                          on ? tint : c.textMuted,
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trophy.requirement,
                    style: ShiftType.bodySm(c.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: Radii.pillAll,
                    child: LinearProgressIndicator(
                      value: trophy.progress,
                      minHeight: 3,
                      backgroundColor: c.surfaceRaised,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        on ? tint : c.borderStrong,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  // Progress and rarity both come from the engine. With
                  // nothing said about either, the line is simply absent
                  // rather than reading "0 OF 1 · 0% OF MEMBERS".
                  Text(
                    <String>[
                      if (trophy.progressLabel.isNotEmpty) trophy.progressLabel,
                      if (trophy.memberPercent > 0)
                        '${Fmt.grouped(trophy.memberPercent)}% OF MEMBERS',
                    ].join(' · '),
                    style: ShiftType.labelSm(c.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: trophy.earned ? tint : c.border,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      trophy.glyph,
                      size: 21,
                      color: trophy.earned ? tint : c.textMuted,
                    ),
                  ),
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
