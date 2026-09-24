import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../app/modes.dart';
import '../../app/shell.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/format.dart';
import '../../util/haptics.dart';
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

    return PullToRefresh(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  SegmentedPills<_Board>(
                    options: _Board.values,
                    labelOf: (_Board b) =>
                        b == _Board.local ? 'Local' : 'Global',
                    selected: _board,
                    onChanged: (_Board next) => setState(() => _board = next),
                    expand: true,
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
      ),
    );
  }
}

/// The global weekly board — everyone, ranked by earnings. What
/// `LeaderboardSurface` showed before Local existed.
class _GlobalBoard extends StatefulWidget {
  const _GlobalBoard();

  @override
  State<_GlobalBoard> createState() => _GlobalBoardState();
}

/// With the Suite's boards (`/v1/boards`), every one of them: CompetePay,
/// Window earnings, credits and the rest, labelled as the Suite labels
/// them, picked from a row of chips. Without them, `/v1/standings`, as
/// before.
class _GlobalBoardState extends State<_GlobalBoard> {
  SuiteBoard _picked = SuiteBoard.compete;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final SuiteBoards? boards = state.boards;
    if (boards == null || boards.isEmpty) {
      return _StandingsBoard(rows: state.standings);
    }
    final List<SuiteBoard> available = boards.available;
    final SuiteBoard board =
        available.contains(_picked) ? _picked : available.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _BoardChips(
          boards: available,
          selected: board,
          onChanged: (SuiteBoard next) {
            Haptics.selection();
            setState(() => _picked = next);
          },
        ),
        const SizedBox(height: Space.x5),
        _StandingsBoard(
          rows: boards.rows[board]!,
          // Not every member is ranked on every board; the board still
          // reads without a row of your own.
          requireYou: false,
          valueNote: board.label,
        ),
      ],
    );
  }
}

/// The Suite's boards as a row of chips that scrolls sideways: eight is
/// too many for a segmented control on a phone.
class _BoardChips extends StatelessWidget {
  const _BoardChips({
    required this.boards,
    required this.selected,
    required this.onChanged,
  });

  final List<SuiteBoard> boards;
  final SuiteBoard selected;
  final ValueChanged<SuiteBoard> onChanged;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final SuiteBoard b in boards) ...<Widget>[
            if (b != boards.first) const SizedBox(width: Space.x2),
            Semantics(
              button: true,
              selected: b == selected,
              child: Material(
                color: b == selected ? c.accentSoft : c.surface,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => onChanged(b),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                    alignment: Alignment.center,
                    child: Text(
                      b.label,
                      style: ShiftType.copy(
                        b == selected ? c.accent : c.text,
                        size: 14,
                        weight: b == selected ? 600 : 500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Podium, your row, the rival on either side of it, then the rest — the
/// same handful of pieces on both boards, because a second, differently
/// shaped board would just be a second thing to learn. Local and Global
/// differ in whose rows these are, never in how they are shown.
class _StandingsBoard extends StatelessWidget {
  const _StandingsBoard({
    required this.rows,
    this.requireYou = true,
    this.valueNote = 'this week',
  });

  final List<StandingRow> rows;

  /// Whether a board with no row for you is "no board yet". True for the
  /// weekly board, where you are always ranked once it scores; false for
  /// the Suite's boards, which a member can be missing from.
  final bool requireYou;

  /// What the number on your card is: "this week", or a Suite board's
  /// name, since Lifetime earnings are not this week's.
  final String valueNote;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final StandingRow? you = rows.where((StandingRow r) => r.isYou).firstOrNull;

    // A board arrives from the engine, so before the first week scores —
    // or before a league has placed this account — there is nothing to
    // rank. Saying that is better than a podium of three blanks.
    if (you == null && (requireYou || rows.isEmpty)) {
      return const _NoBoardYet();
    }

    final List<StandingRow> podium =
        rows.where((StandingRow r) => r.rank <= 3).toList();
    // Without a full podium the list starts at first place. It started at
    // fourth either way, so a board of one or two people drew nobody.
    final List<StandingRow> rest = podium.length == 3
        ? rows.where((StandingRow r) => r.rank > 3).toList()
        : rows;
    final StandingRow? target = you == null || you.rank <= 1
        ? null
        : rows.where((StandingRow r) => r.rank == you.rank - 1).firstOrNull;
    final StandingRow? chaser = you == null
        ? null
        : rows.where((StandingRow r) => r.rank == you.rank + 1).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (podium.length == 3) ...<Widget>[
          _Podium(rows: podium),
          const SizedBox(height: Space.x5),
        ],
        if (you != null) ...<Widget>[
          _YouCard(you: you, valueNote: valueNote),
          const SizedBox(height: Space.x4),
          _RivalRow(target: target, chaser: chaser, you: you),
          const SizedBox(height: Space.x6),
        ],
        // Your own row appears again below, tinted. That is not a repeat:
        // the cards above are the highlights, this is the board itself,
        // and a board with a hole where you should be is a worse thing to
        // read. Saying which is which is what the heading is for.
        Semantics(
          header: true,
          child: Text('Standings', style: ShiftType.sectionTitle(c.text)),
        ),
        const SizedBox(height: Space.x3),
        // One grouped list rather than loose rows, hairlines inset to the
        // names so the ranks and faces read as a single column.
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Radii.lgAll,
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < rest.length; i++) ...<Widget>[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 104),
                    child: Divider(height: 1, thickness: 0.5, color: c.border),
                  ),
                _Row(row: rest[i]),
              ],
            ],
          ),
        ),
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
    final bool failed = state.lastError != null;

    return failed
        ? EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'The board did not load',
            message: state.lastError!.message,
            actionLabel: 'Try again',
            onAction: state.refreshing ? null : state.refresh,
          )
        : const EmptyState(
            icon: Icons.leaderboard_rounded,
            title: 'No board yet',
            message: 'Publish something this week and you are on it. '
                'Standings settle when the week closes.',
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
        _problem = 'Turn on location access for ShiftAi to see who is '
            'near you.';
      });
      return;
    }
    final bool ok = await state.shareLocation(fix.lat, fix.lng);
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _problem = ok
          ? null
          : (state.lastError?.message ??
              'Could not place '
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
          Text('See how you stack up locally',
              style: ShiftType.subheading(c.text)),
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
    final String rule =
        league.promoteCount > 0 ? ' · top ${league.promoteCount} move up' : '';
    // Where, and what it is, in words — the division is named in the line
    // under the region, so it needs no coloured dot beside it.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            league.regionLabel,
            style: ShiftType.sectionTitle(c.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${league.division.label} league$rule',
          style: ShiftType.bodySm(c.textMuted),
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

    // Null once the week has closed — the formatter written for this
    // screen last time printed a negative day count instead.
    final String? countdown = Fmt.countdown(clock.remaining);

    // The pool and the payout line are the engine's, not the catalogue's.
    // A week with nothing in it says nothing rather than announcing a pool
    // of zero.
    final String detail = state.weekPool > 0
        ? '\$${Fmt.grouped(state.weekPool)} prize pool'
            '${state.payoutLine.isEmpty ? '' : ' · ${state.payoutLine}'}'
        : state.payoutLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                'Week ${clock.weekNumber}',
                style: ShiftType.sectionTitle(c.text),
              ),
            ),
            const SizedBox(width: Space.x3),
            // One paragraph that can wrap, not two fixed pieces: at a large
            // text size "Week 39" and "Ends in 5d 08:16:30" together ran
            // 52px off a phone's edge.
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: countdown == null
                      ? <InlineSpan>[
                          TextSpan(
                            text: 'Locked',
                            style: ShiftType.caption(c.textMuted),
                          ),
                        ]
                      : <InlineSpan>[
                          TextSpan(
                            text: 'Ends in ',
                            style: ShiftType.caption(c.textMuted),
                          ),
                          TextSpan(
                            text: countdown,
                            style: ShiftType.figures(c.text, size: 15),
                          ),
                        ],
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        if (detail.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(detail, style: ShiftType.bodySm(c.textMuted)),
        ],
      ],
    );
  }
}

/// A stranger's face is not worth fetching, so every row but your own goes
/// by initials on a tier-coloured ring. Your own row can carry
/// [StandingRow.avatarUrl] — your personal avatar, hosted by the server —
/// and that is worth drawing.
class _Face extends StatelessWidget {
  const _Face({required this.row, required this.size, this.ring});

  final StandingRow row;
  final double size;

  /// Overrides the tier ring — the podium rings each face in its medal.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final Color ring = this.ring ?? row.tier?.colorOn(c) ?? c.border;
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
            style: ShiftType.copy(
              c.textMuted,
              size: size >= 56 ? 17 : 12,
              weight: 600,
            ),
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

  /// Gold, silver, bronze — the tier colours, which already know how to
  /// darken for a light ground. First place used to be the accent pink
  /// and the other two plain grey, so nothing on the podium said which
  /// step was which except the height.
  Color _medal(ShiftColors c) => switch (row.rank) {
        1 => TrophyTier.gold.colorOn(c),
        2 => TrophyTier.silver.colorOn(c),
        _ => TrophyTier.bronze.colorOn(c),
      };

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool lead = row.rank == 1;
    final Color medal = _medal(c);

    return Semantics(
      container: true,
      // Read first, second, third, not in the order the steps stand.
      sortKey: OrdinalSortKey(row.rank.toDouble()),
      label: '${_place(row.rank)} place, ${_who(row)}, '
          '${Fmt.money(row.earnings)}',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 22,
            child: lead
                ? Icon(Icons.emoji_events_rounded, size: 20, color: medal)
                : null,
          ),
          Center(
            child: _Face(row: row, size: lead ? 64 : 52, ring: medal),
          ),
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
            style: ShiftType.figures(c.textMuted, size: 13, weight: 500),
          ),
          const SizedBox(height: Space.x3),
          // Pedestals meet in the middle with no gap, so the three read as
          // one block of steps rather than three floating tiles. Each is its
          // medal washed thin, lit along the top edge like a step catching
          // the light.
          //
          // The lit edge is its own strip rather than a top-only Border: a
          // borderRadius on a border that is not the same on every side is
          // an assertion in Flutter, not a style.
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radii.sm),
            child: SizedBox(
              height: height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ColoredBox(color: medal, child: const SizedBox(height: 2)),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            medal.withValues(alpha: 0.30),
                            medal.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: Space.x2 - 2),
                        child: Text(
                          '${row.rank}',
                          textAlign: TextAlign.center,
                          style: ShiftType.subheading(medal)
                              .copyWith(fontSize: lead ? 22 : 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YouCard extends StatelessWidget {
  const _YouCard({required this.you, this.valueNote = 'this week'});

  final StandingRow you;
  final String valueNote;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool up = you.movement > 0;
    final bool flat = you.movement == 0;

    return Semantics(
      container: true,
      label: 'You are ${_place(you.rank)}, '
          '${Fmt.money(you.earnings)} $valueNote'
          '${you.movementKnown ? ', ${_moved(you.movement)}' : ''}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // On a phone the money and the rank move matter; "this week" is
          // the part that goes, rather than either of them truncating.
          final bool roomForWeek = constraints.maxWidth >= 420;
          return _buildCard(context, c, up: up, flat: flat, week: roomForWeek);
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    ShiftColors c, {
    required bool up,
    required bool flat,
    required bool week,
  }) {
    // A soft fill and nothing else. It was a pink wash inside a pink
    // border with the money in green: three signals for one thing, and
    // the loudest object on the screen for the row that least needs
    // pointing out.
    final Color move = up ? c.success : c.danger;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x5,
        vertical: Space.x4,
      ),
      decoration: BoxDecoration(
        color: c.accentSoft,
        borderRadius: Radii.lgAll,
      ),
      child: Row(
        children: <Widget>[
          Text(
            '${you.rank}',
            style: ShiftType.displayL(c.accent),
          ),
          const SizedBox(width: Space.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('You', style: ShiftType.bodyStrong(c.text)),
                if (!flat)
                  Row(
                    children: <Widget>[
                      Icon(
                        up
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14,
                        color: move,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '${you.movement.abs()} '
                          '${up ? 'up' : 'down'}'
                          '${week ? ' this week' : ''}',
                          style: ShiftType.caption(move),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: Space.x3),
          Text(
            Fmt.money(you.earnings),
            style: ShiftType.figures(c.text, size: 22, weight: 700),
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
          label: 'To catch · #${target!.rank}',
          gap: '${Fmt.money(target!.earnings - you.earnings)} ahead',
          tone: c.success,
          icon: Icons.arrow_upward_rounded,
        ),
      if (chaser != null)
        _GapLine(
          row: chaser!,
          label: 'On your tail · #${chaser!.rank}',
          gap: '${Fmt.money(you.earnings - chaser!.earnings)} behind',
          tone: c.danger,
          icon: Icons.arrow_downward_rounded,
        ),
    ];

    if (halves.isEmpty) return const SizedBox.shrink();

    // Filled and borderless, with the hairline inset to where the text
    // starts — the grouped-list shape, not a box drawn round two lines.
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.lgAll,
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < halves.length; i++) ...<Widget>[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 88),
                child: Divider(height: 1, thickness: 0.5, color: c.border),
              ),
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

    return Semantics(
      container: true,
      label: '${label.split(' · ').first}: ${row.name}, '
          '${_place(row.rank)}, $gap',
      excludeSemantics: true,
      child: Padding(
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
                  Text(
                    row.name,
                    style: ShiftType.bodyStrong(c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(label, style: ShiftType.caption(c.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: Space.x3),
            Text(gap, style: ShiftType.figures(tone, size: 14)),
          ],
        ),
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

    return Semantics(
      container: true,
      label: '${_place(row.rank)}, ${_who(row)}, '
          '${Fmt.money(row.earnings)}'
          '${row.movementKnown ? ', ${_moved(row.movement)}' : ''}',
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool roomForTier = constraints.maxWidth >= 520;
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: 10,
            ),
            // Your own row is tinted rather than ruled off, so scrolling the
            // board lands on it without hunting for the number.
            color: mine ? c.accentSoft : null,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 24,
                  child: Text(
                    '${row.rank}',
                    textAlign: TextAlign.right,
                    style: ShiftType.figures(
                      mine ? c.accent : c.textMuted,
                      size: 15,
                      weight: mine ? 700 : 500,
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
                    // One size for every name, you included — the weight is
                    // the only difference. "You" was 15 against everyone
                    // else's 17, so the row meant to stand out looked
                    // smaller than its neighbours.
                    style: ShiftType.copy(
                      c.text,
                      size: 16,
                      weight: mine ? 600 : 400,
                    ),
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
                      row.tier!.label,
                      style: ShiftType.copy(
                        row.tier!.colorOn(c),
                        size: 12,
                        weight: 600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: Space.x3),
                Text(
                  Fmt.money(row.earnings),
                  style: ShiftType.figures(c.text, size: 15),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// What a screen reader says for a place: "1st", "2nd", "23rd".
///
/// The board used to reach VoiceOver as one long run of text, podium
/// steps in the order they stand (second, first, third) and every face's
/// initials spelled out as letters. Each person on it is now one line.
String _place(int rank) {
  final int lastTwo = rank % 100;
  final String suffix = lastTwo >= 11 && lastTwo <= 13
      ? 'th'
      : switch (rank % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$rank$suffix';
}

String _who(StandingRow row) => row.isYou ? 'you' : row.name;

String _moved(int movement) => movement > 0
    ? 'up $movement'
    : movement < 0
        ? 'down ${-movement}'
        : 'no change';
