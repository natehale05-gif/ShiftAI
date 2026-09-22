import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/modes.dart';
import '../../app/shell.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/format.dart';
import '../../util/geo.dart';
import '../../util/week.dart';
import '../../widgets/common.dart';

/// Local defaults to on: a fair fight against people near you in both rank
/// and location beats the whole board for most people, most weeks. Global
/// is one tap away for whoever still wants to see the very top.
enum _Board { local, global }

/// The weekly board: what is left on the clock, who is on the podium, where
/// you are, who you can catch and who is catching you — or, on the Local
/// tab, the smaller cohort the engine matched you into.
class LeaderboardSurface extends StatefulWidget {
  const LeaderboardSurface({super.key});

  @override
  State<LeaderboardSurface> createState() => _LeaderboardSurfaceState();
}

class _LeaderboardSurfaceState extends State<LeaderboardSurface> {
  _Board _board = _Board.local;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

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
                  title: 'Leaderboard',
                  onBack: () => state.setSurface(Surface.suite),
                ),
                const SizedBox(height: Space.x5),
                const _ClockRow(),
                const SizedBox(height: Space.x5),
                _BoardToggle(
                  board: _board,
                  onChanged: (_Board next) => setState(() => _board = next),
                ),
                const SizedBox(height: Space.x6),
                if (_board == _Board.local)
                  const _LocalLeagueSection()
                else
                  const _GlobalBoard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BoardToggle extends StatelessWidget {
  const _BoardToggle({required this.board, required this.onChanged});

  final _Board board;
  final ValueChanged<_Board> onChanged;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: Radii.pillAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: _BoardTab(
            label: 'Local',
            selected: board == _Board.local,
            onTap: () => onChanged(_Board.local),
          )),
          Expanded(child: _BoardTab(
            label: 'Global',
            selected: board == _Board.global,
            onTap: () => onChanged(_Board.global),
          )),
        ],
      ),
    );
  }
}

class _BoardTab extends StatelessWidget {
  const _BoardTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.pillAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: Space.x2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.accent : Colors.transparent,
          borderRadius: Radii.pillAll,
        ),
        child: Text(
          label.toUpperCase(),
          style: ShiftType.labelSm(selected ? c.onAccent : c.textMuted),
        ),
      ),
    );
  }
}

/// The global weekly board — everyone, ranked by earnings. What
/// `LeaderboardSurface` showed before Local existed.
class _GlobalBoard extends StatelessWidget {
  const _GlobalBoard();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    return _StandingsBoard(rows: state.standings);
  }
}

/// Podium, your row, the rival on either side of it, then the rest — the
/// same handful of pieces on both boards, because a second, differently
/// shaped board would just be a second thing to learn. Local and Global
/// differ in whose rows these are, never in how they are shown.
class _StandingsBoard extends StatelessWidget {
  const _StandingsBoard({required this.rows});

  final List<StandingRow> rows;

  @override
  Widget build(BuildContext context) {
    final StandingRow? you =
        rows.where((StandingRow r) => r.isYou).firstOrNull;

    // A board arrives from the engine, so before the first week scores —
    // or before a league has placed this account — there is nothing to
    // rank. Saying that is better than a podium of three blanks.
    if (you == null) return const _NoBoardYet();

    final List<StandingRow> podium =
        rows.where((StandingRow r) => r.rank <= 3).toList();
    final List<StandingRow> rest =
        rows.where((StandingRow r) => r.rank > 3).toList();
    final StandingRow? target = you.rank <= 1
        ? null
        : rows.where((StandingRow r) => r.rank == you.rank - 1).firstOrNull;
    final StandingRow? chaser =
        rows.where((StandingRow r) => r.rank == you.rank + 1).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (podium.length == 3) ...<Widget>[
          _Podium(rows: podium),
          const SizedBox(height: Space.x5),
        ],
        _YouCard(you: you),
        const SizedBox(height: Space.x4),
        _RivalRow(target: target, chaser: chaser, you: you),
        const SizedBox(height: Space.x6),
        // Your own row appears again below, tinted. That is not a repeat:
        // the cards above are the highlights, this is the board itself,
        // and a board with a hole where you should be is a worse thing to
        // read. Saying which is which is what the heading is for.
        const Eyebrow('THE BOARD'),
        const SizedBox(height: Space.x3),
        ...rest.map((StandingRow row) => _Row(row: row)),
      ],
    );
  }
}

/// The clock runs. It is computed from the real week rather than held at a
/// number, so the board is never wrong about how long is left.
/// Before the engine has a row for you: no podium, no invented rank, and
/// a line that says which it is — a week that has not scored yet, or a
/// board that could not be reached.
class _NoBoardYet extends StatelessWidget {
  const _NoBoardYet();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final bool failed = state.lastError != null;

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            failed ? Icons.cloud_off_rounded : Icons.bar_chart_rounded,
            size: 28,
            color: c.textMuted,
          ),
          const SizedBox(height: Space.x4),
          Text(
            failed ? 'The board did not load' : 'No board yet',
            style: ShiftType.subheading(c.text),
          ),
          const SizedBox(height: Space.x2),
          Text(
            failed
                ? state.lastError!.message
                : 'Publish something this week and you are on it. Standings '
                    'settle when the week closes.',
            style: ShiftType.bodySm(c.textMuted),
          ),
          if (failed) ...<Widget>[
            const SizedBox(height: Space.x4),
            OutlinedButton(
              onPressed: state.refreshing ? null : state.refresh,
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Turns a device fix into a placement, and carries whichever of the two
/// failure states (permission refused, or the engine refused the write)
/// the last attempt landed on.
class _LocalLeagueSection extends StatefulWidget {
  const _LocalLeagueSection();

  @override
  State<_LocalLeagueSection> createState() => _LocalLeagueSectionState();
}

class _LocalLeagueSectionState extends State<_LocalLeagueSection> {
  bool _requesting = false;
  String? _problem;

  Future<void> _share(AppState state) async {
    setState(() {
      _requesting = true;
      _problem = null;
    });
    final GeoFix? fix = await Geo.currentFix();
    if (fix == null) {
      if (!mounted) return;
      setState(() {
        _requesting = false;
        _problem = 'Turn on location access for SHIFT AI to see who is '
            'near you.';
      });
      return;
    }
    final bool ok = await state.shareLocation(fix.lat, fix.lng);
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _problem = ok ? null : (state.lastError?.message ?? 'Could not place '
          'you locally right now.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final League? league = state.league;
    if (league == null) {
      return _NoLeagueYet(
        requesting: _requesting,
        problem: _problem,
        onShare: () => _share(state),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _LeagueHeader(league: league),
        const SizedBox(height: Space.x5),
        _StandingsBoard(rows: league.rows),
      ],
    );
  }
}

class _NoLeagueYet extends StatelessWidget {
  const _NoLeagueYet({
    required this.requesting,
    required this.problem,
    required this.onShare,
  });

  final bool requesting;
  final String? problem;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.near_me_outlined, size: 28, color: c.textMuted),
          const SizedBox(height: Space.x4),
          Text('See how you stack up locally', style: ShiftType.subheading(c.text)),
          const SizedBox(height: Space.x2),
          Text(
            'A smaller board of people near you in both rank and location — '
            'a fairer fight than the whole board, and one you can actually '
            'move up in.',
            style: ShiftType.bodySm(c.textMuted),
          ),
          if (problem != null) ...<Widget>[
            const SizedBox(height: Space.x3),
            Text(problem!, style: ShiftType.bodySm(c.danger)),
          ],
          const SizedBox(height: Space.x4),
          FilledButton(
            onPressed: requesting ? null : onShare,
            child: Text(requesting ? 'Finding you…' : 'Use my location'),
          ),
        ],
      ),
    );
  }
}

class _LeagueHeader extends StatelessWidget {
  const _LeagueHeader({required this.league});

  final League league;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x3,
            vertical: Space.x1,
          ),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: Radii.pillAll,
            border: Border.all(color: league.division.colorOn(c)),
          ),
          child: Text(
            league.division.label.toUpperCase(),
            style: ShiftType.labelSm(league.division.colorOn(c)),
          ),
        ),
        const SizedBox(width: Space.x3),
        Expanded(
          child: Text(
            league.regionLabel,
            style: ShiftType.subheading(c.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ClockRow extends StatefulWidget {
  const _ClockRow();

  @override
  State<_ClockRow> createState() => _ClockRowState();
}

class _ClockRowState extends State<_ClockRow> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final AppState state = AppScope.of(context);
    final WeekClock clock = WeekClock();

    return Wrap(
      spacing: Space.x5,
      runSpacing: Space.x2,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              'WEEK ${clock.weekNumber} LOCKS IN',
              style: ShiftType.labelSm(c.accent),
            ),
            const SizedBox(width: Space.x3),
            Text(
              Fmt.countdown(clock.remaining),
              style: ShiftType.mono(c.text, size: 19),
            ),
          ],
        ),
        // The pool and the payout line are the engine's, not the
        // catalogue's. A week with nothing in it says nothing rather than
        // announcing a pool of zero.
        if (state.weekPool > 0)
          Text(
            '\$${Fmt.grouped(state.weekPool)} POOL · ${state.payoutLine}',
            style: ShiftType.labelSm(c.textMuted),
          )
        else if (state.payoutLine.isNotEmpty)
          Text(
            state.payoutLine.toUpperCase(),
            style: ShiftType.labelSm(c.textMuted),
          ),
      ],
    );
  }
}

/// A stranger's face is not worth fetching, so every row but your own goes
/// by initials on a tier-coloured ring. Your own row can carry
/// [StandingRow.avatarUrl] — your personal avatar, hosted by the server —
/// and that is worth drawing.
class _Face extends StatelessWidget {
  const _Face({required this.row, required this.size});

  final StandingRow row;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final Color ring = row.tier?.colorOn(c) ?? c.border;
    final String? url = row.avatarUrl;

    Widget initials() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: size >= 56 ? 2 : 1),
          ),
          child: Text(
            row.initials,
            style: ShiftType.mono(c.textMuted, size: size >= 56 ? 16 : 12),
          ),
        );

    if (url == null || url.isEmpty) return initials();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: size >= 56 ? 2 : 1),
      ),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (BuildContext context, Object _, StackTrace? __) =>
            initials(),
      ),
    );
  }
}

/// Second on the left, first in the middle, third on the right — standing
/// on pedestals of three different heights, because that is the one shape
/// everybody already reads as a podium. Three circles in a row with
/// numbers under them is a ranked list wearing a podium's clothes.
class _Podium extends StatelessWidget {
  const _Podium({required this.rows});

  final List<StandingRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.length < 3) return const SizedBox.shrink();
    final List<StandingRow> sorted = List<StandingRow>.of(rows)
      ..sort((StandingRow a, StandingRow b) => a.rank.compareTo(b.rank));

    // Capped and centred: the board is 950 wide on a desktop, and three
    // faces spread across all of it stop reading as a podium and start
    // reading as three unrelated columns.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: _PodiumSpot(row: sorted[1], height: 56)),
            Expanded(child: _PodiumSpot(row: sorted[0], height: 78)),
            Expanded(child: _PodiumSpot(row: sorted[2], height: 40)),
          ],
        ),
      ),
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  const _PodiumSpot({required this.row, required this.height});

  final StandingRow row;

  /// The pedestal, not the whole spot. First is tallest.
  final double height;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool lead = row.rank == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The cup is the one piece of gold on the board, and it is the
        // only thing marking first place besides the extra height.
        SizedBox(
          height: 22,
          child: lead
              ? Icon(Icons.emoji_events_rounded, size: 20, color: c.warning)
              : null,
        ),
        Center(child: _Face(row: row, size: lead ? 64 : 52)),
        const SizedBox(height: Space.x3),
        Text(
          row.name,
          maxLines: 1,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: ShiftType.bodySm(c.text),
        ),
        const SizedBox(height: 2),
        Text(
          Fmt.money(row.earnings),
          textAlign: TextAlign.center,
          style: ShiftType.mono(c.textMuted, size: 13),
        ),
        const SizedBox(height: Space.x3),
        // Pedestals meet in the middle with no gap, so the three read as
        // one block of steps rather than three floating tiles.
        Container(
          height: height,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: Space.x2),
          decoration: BoxDecoration(
            color: lead ? c.accentSoft : c.surfaceRaised,
            borderRadius: const BorderRadius.vertical(top: Radii.sm),
          ),
          child: Text(
            '${row.rank}',
            style: ShiftType.subheading(lead ? c.accent : c.textMuted)
                .copyWith(fontSize: lead ? 22 : 18),
          ),
        ),
      ],
    );
  }
}

class _YouCard extends StatelessWidget {
  const _YouCard({required this.you});

  final StandingRow you;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool up = you.movement > 0;
    final bool flat = you.movement == 0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // On a phone the money and the rank move matter; "this week" is
        // the part that goes, rather than either of them truncating.
        final bool roomForWeek = constraints.maxWidth >= 420;
        return _buildCard(context, c, up: up, flat: flat, week: roomForWeek);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    ShiftColors c, {
    required bool up,
    required bool flat,
    required bool week,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x5,
        vertical: Space.x4,
      ),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: Radii.lgAll,
        border: Border.all(color: c.accent),
      ),
      child: Row(
        children: <Widget>[
          Text(
            '${you.rank}',
            style: ShiftType.displayL(c.text).copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: Space.x5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('You', style: ShiftType.bodyStrong(c.text)),
                if (!flat) ...<Widget>[
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      Icon(
                        up
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: up ? c.success : c.danger,
                      ),
                      Flexible(
                        child: Text(
                          '${you.movement.abs()} ${up ? 'UP' : 'DOWN'}'
                          '${week ? ' THIS WEEK' : ''}',
                          style: ShiftType.labelSm(up ? c.success : c.danger),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.x3),
          Text(
            Fmt.money(you.earnings),
            style: ShiftType.mono(c.success, size: 24),
          ),
        ],
      ),
    );
  }
}

/// The two people either side of you, in one card rather than two.
///
/// They were a green-outlined box and a red-outlined box stacked under a
/// pink-filled one — three different chrome treatments in a column, which
/// is what made this screen feel busy. One card, one hairline between the
/// halves, and the only colour is the arrow and the gap itself.
class _RivalRow extends StatelessWidget {
  const _RivalRow({
    required this.target,
    required this.chaser,
    required this.you,
  });

  final StandingRow? target;
  final StandingRow? chaser;
  final StandingRow you;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    final List<Widget> halves = <Widget>[
      if (target != null)
        _GapLine(
          row: target!,
          label: 'TO CATCH #${target!.rank}',
          gap: '${Fmt.money(target!.earnings - you.earnings)} ahead',
          tone: c.success,
          icon: Icons.arrow_upward_rounded,
        ),
      if (chaser != null)
        _GapLine(
          row: chaser!,
          label: '#${chaser!.rank} ON YOUR TAIL',
          gap: '${Fmt.money(you.earnings - chaser!.earnings)} behind',
          tone: c.danger,
          icon: Icons.arrow_downward_rounded,
        ),
    ];

    if (halves.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: Radii.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < halves.length; i++) ...<Widget>[
            if (i > 0) Divider(height: 1, color: c.border),
            halves[i],
          ],
        ],
      ),
    );
  }
}

class _GapLine extends StatelessWidget {
  const _GapLine({
    required this.row,
    required this.label,
    required this.gap,
    required this.tone,
    required this.icon,
  });

  final StandingRow row;
  final String label;
  final String gap;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x3,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: Space.x3),
          _Face(row: row, size: 28),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(label, style: ShiftType.labelSm(c.textMuted)),
                const SizedBox(height: 1),
                Text(
                  row.name,
                  style: ShiftType.bodySm(c.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.x3),
          Text(gap, style: ShiftType.mono(tone, size: 13)),
        ],
      ),
    );
  }
}

/// One line of the board.
///
/// Amounts are plain text rather than money-green. Ten green figures in a
/// column is ten things shouting at once, and then nothing on the screen
/// stands out — the only colour left here is the rank move, which is the
/// part that actually changes.
class _Row extends StatelessWidget {
  const _Row({required this.row});

  final StandingRow row;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool up = row.movement > 0;
    final bool flat = row.movement == 0;
    final bool mine = row.isYou;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool roomForTier = constraints.maxWidth >= 520;
        return Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x3,
            vertical: Space.x2,
          ),
          decoration: BoxDecoration(
            // Your own row is tinted rather than ruled off, so scrolling
            // the board lands on it without hunting for the number.
            color: mine ? c.accentSoft : null,
            borderRadius: Radii.mdAll,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: Text(
                  '${row.rank}',
                  textAlign: TextAlign.right,
                  style: ShiftType.mono(
                    mine ? c.accent : c.textMuted,
                    size: 14,
                  ),
                ),
              ),
              // Beside the rank, not beside the money: a variable-width
              // thing in the middle of the row is what was eating the
              // names, and the move belongs with the number it moved.
              SizedBox(
                width: 22,
                child: flat
                    ? null
                    : Icon(
                        up
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: up ? c.success : c.danger,
                      ),
              ),
              _Face(row: row, size: 30),
              const SizedBox(width: Space.x3),
              // Expanded, not Flexible beside a Spacer: those two split
              // the leftover width between them, so the name gave up half
              // the row to empty space and then ellipsised — which is why
              // half the board read 'Leo Font…' with a gap beside it.
              Expanded(
                child: Text(
                  mine ? 'You' : row.name,
                  style: mine
                      ? ShiftType.bodyStrong(c.text)
                      : ShiftType.body(c.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (row.tier != null && roomForTier) ...<Widget>[
                const SizedBox(width: Space.x3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.x2,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    borderRadius: Radii.smAll,
                  ),
                  child: Text(
                    row.tier!.label.toUpperCase(),
                    style: ShiftType.labelSm(row.tier!.colorOn(c)),
                  ),
                ),
              ],
              const SizedBox(width: Space.x3),
              Text(
                Fmt.money(row.earnings),
                style: ShiftType.mono(c.text, size: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}
