import 'package:flutter/material.dart';

import '../../app/modes.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';

/// One plain sentence, a Details disclosure, and a Sign in action.
///
/// The 503 behind this is `shift.within_ceiling` being unreachable
/// (migration 0011) — it is not a verdict on the plan, so the card says so
/// and offers Settings rather than pushing an upgrade.
class FailureCard extends StatefulWidget {
  const FailureCard({required this.failure, super.key});

  final FailureInfo failure;

  @override
  State<FailureCard> createState() => _FailureCardState();
}

class _FailureCardState extends State<FailureCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    return Container(
      padding: const EdgeInsets.all(Space.x5),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: c.warning,
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.failure.sentence,
                      // Callout, emphasised.
                      style: ShiftType.copy(c.text, size: 16, weight: 600),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      widget.failure.reassurance,
                      style: ShiftType.bodySm(c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(
                _open
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.chevron_right_rounded,
                size: 16,
                color: c.textMuted,
              ),
              label: Text('Details', style: ShiftType.caption(c.textMuted)),
              style: TextButton.styleFrom(
                foregroundColor: c.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: Space.x2),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
          if (_open) ...<Widget>[
            const SizedBox(height: Space.x2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Space.x3),
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                borderRadius: Radii.mdAll,
              ),
              child: SelectableText(
                widget.failure.details,
                style: ShiftType.figures(c.textMuted, size: 13, weight: 400),
              ),
            ),
          ],
          if (widget.failure.offersAccount) ...<Widget>[
            const SizedBox(height: Space.x4),
            Wrap(
              spacing: Space.x3,
              runSpacing: Space.x2,
              children: <Widget>[
                FilledButton(
                  onPressed: state.signOut,
                  child: const Text('Sign in'),
                ),
                OutlinedButton(
                  onPressed: () => state.setSurface(Surface.settings),
                  child: Text('Settings',
                      style: ShiftType.copy(c.text, size: 15, weight: 600)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
