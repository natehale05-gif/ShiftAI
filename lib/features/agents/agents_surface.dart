import 'package:flutter/material.dart';

import '../../app/shell.dart';
import '../../data/seed.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/common.dart';

/// Two tabs: the runs sitting against a repository, and the jobs running in
/// a folder. Both are lists of one line each — nothing is dressed up.
class AgentsSurface extends StatelessWidget {
  const AgentsSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.x5,
              Space.x5,
              Space.x5,
              Space.x5,
            ),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kContentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ScreenTabs(
                        labels: const <String>['Agents', 'Jobs'],
                        selected: state.showingJobs ? 1 : 0,
                        onChanged: (int i) => state.showJobs(i == 1),
                        scopeLabel: state.showingJobs
                            ? state.jobScope
                            : state.agentScope,
                        onScopeTap: () => _showScopePicker(context, state),
                      ),
                      const SizedBox(height: Space.x5),
                      if (state.showingJobs)
                        const _JobsTab()
                      else
                        const _AgentsTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        PillComposer(
          hint: state.showingJobs ? 'Start a job' : 'Give an agent a task',
          onSend: (String text) => _hand(context, state, text),
        ),
      ],
    );
  }
}

/// Sending from the Agents bar puts a real row at the top of the list it
/// belongs to, in the scope showing. A refusal says so instead.
Future<void> _hand(BuildContext context, AppState state, String text) async {
  final bool jobs = state.showingJobs;
  final String scope = jobs ? state.jobScope : state.agentScope;
  final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
  final bool took = await state.startAgentWork(text);
  bar.showSnackBar(
    SnackBar(
      content: Text(
        took
            ? (jobs
                ? 'Queued in $scope: ${_oneLine(text)}'
                : 'Handed to an agent on $scope: ${_oneLine(text)}')
            : state.lastError?.message ?? 'The engine would not take that.',
      ),
    ),
  );
}

/// Re-run puts the row back to working for real, and says so only once
/// the engine has taken it.
Future<void> _rerun(BuildContext context, String id, String title) async {
  final AppState state = AppScope.read(context);
  final NavigatorState nav = Navigator.of(context);
  final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
  nav.pop();
  final bool took = await state.rerunAgent(id);
  bar.showSnackBar(
    SnackBar(
      content: Text(
        took
            ? 'Running “$title” again'
            : state.lastError?.message ?? 'Could not start it again.',
      ),
    ),
  );
}

/// The first line of what was typed, short enough for a toast.
String _oneLine(String text) {
  final String flat = text.split('\n').first.trim();
  return flat.length <= 48 ? flat : '${flat.substring(0, 47)}…';
}

class _AgentsTab extends StatefulWidget {
  const _AgentsTab();

  @override
  State<_AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<_AgentsTab> {
  bool _onlyTrouble = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    final List<AgentRun> inScope = state.visibleRuns;
    final List<AgentRun> runs = _onlyTrouble
        ? inScope
            .where(
              (AgentRun r) =>
                  r.status == RunStatus.failed ||
                  r.status == RunStatus.needsYou,
            )
            .toList(growable: false)
        : inScope;

    int countOf(RunStatus status) =>
        inScope.where((AgentRun r) => r.status == status).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: Space.x5,
          runSpacing: Space.x2,
          children: <Widget>[
            _Count(value: inScope.length, label: 'in all', color: c.text),
            _Count(
              value: countOf(RunStatus.working),
              label: 'working',
              color: _statusColor(RunStatus.working, c),
            ),
            _Count(
              value: countOf(RunStatus.needsYou),
              label: 'need you',
              color: _statusColor(RunStatus.needsYou, c),
            ),
            _Count(
              value: countOf(RunStatus.inReview),
              label: 'in review',
              color: _statusColor(RunStatus.inReview, c),
            ),
          ],
        ),
        const SizedBox(height: Space.x5),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            borderRadius: Radii.pillAll,
            onTap: () => setState(() => _onlyTrouble = !_onlyTrouble),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x2,
                vertical: Space.x2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _onlyTrouble ? 'Needs attention and failed' : 'Everything',
                    style: ShiftType.body(
                      _onlyTrouble ? c.accent : c.textMuted,
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  AnimatedRotation(
                    turns: _onlyTrouble ? 0.25 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: _onlyTrouble ? c.accent : c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.x2),
        if (runs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.x4),
            child: Text(
              _onlyTrouble
                  ? 'Nothing needs you right now.'
                  : 'Nothing running on ${state.agentScope} yet — give an '
                      'agent a task below.',
              style: ShiftType.body(c.textMuted),
            ),
          )
        else
          ...runs.map((AgentRun run) => _RunRow(run: run)),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$value', style: ShiftType.body(color)),
        const SizedBox(width: Space.x2),
        Text(label, style: ShiftType.body(c.textMuted)),
      ],
    );
  }
}

/// One colour per status, used by the dot and by the count above it, so a
/// row and its tally always agree. The retro themes make accent pink,
/// which sits close to danger — that is why "in review" is its own colour
/// rather than another shade of the accent.
Color _statusColor(RunStatus status, ShiftColors c) => switch (status) {
      RunStatus.working => c.accent,
      RunStatus.needsYou => c.warning,
      RunStatus.inReview => c.sky,
      RunStatus.done => c.success,
      RunStatus.failed => c.danger,
    };

class _RunRow extends StatelessWidget {
  const _RunRow({required this.run});

  final AgentRun run;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    return _ListRow(
      onTap: () => _showRunDetail(
        context,
        runId: run.id,
        title: run.title,
        status: run.status,
        lines: <String, String>{
          'Status': run.checksPassed ? 'Checks passed' : run.detail,
          if (run.diff != null) 'Change': run.diff!,
          if (run.scope != null) 'Where': run.scope!,
        },
      ),
      dotColor: _statusColor(run.status, c),
      title: run.title,
      detail: run.checksPassed
          ? null
          : Text(run.detail, style: ShiftType.bodySm(c.textMuted)),
      richDetail: run.checksPassed
          ? Row(
              children: <Widget>[
                Icon(Icons.check_rounded, size: 15, color: c.textMuted),
                const SizedBox(width: Space.x2),
                Flexible(
                  child: Text(
                    'Checks Passed · ${run.diff} · ${run.scope}',
                    style: ShiftType.bodySm(c.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}

class _JobsTab extends StatelessWidget {
  const _JobsTab();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Running in ${state.jobScope}',
                style: ShiftType.body(c.text),
              ),
            ),
            Text(Seed.jobPolicy, style: ShiftType.bodySm(c.textMuted)),
          ],
        ),
        const SizedBox(height: Space.x3),
        if (state.visibleJobs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.x4),
            child: Text(
              'No jobs in ${state.jobScope} yet — start one below.',
              style: ShiftType.body(c.textMuted),
            ),
          ),
        ...state.visibleJobs.map(
          (JobRow job) => _ListRow(
            dotColor: _statusColor(job.status, c),
            title: job.title,
            detail: Text(job.detail, style: ShiftType.bodySm(c.textMuted)),
            onTap: () => _showRunDetail(
              context,
              title: job.title,
              status: job.status,
              lines: <String, String>{
                'Status': job.detail,
                'Where': job.scope ?? state.jobScope,
                'Policy': Seed.jobPolicy,
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// One row: a status dot, a title, a line underneath, a hairline that starts
/// where the text does.
class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.dotColor,
    required this.title,
    this.detail,
    this.richDetail,
    this.onTap,
  });

  final Color dotColor;
  final String title;
  final Widget? detail;
  final Widget? richDetail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: Space.x3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: Radii.pillAll,
                ),
              ),
            ),
            const SizedBox(width: Space.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: ShiftType.body(c.text)),
                  const SizedBox(height: 2),
                  if (richDetail != null)
                    richDetail!
                  else
                    detail ?? const SizedBox.shrink(),
                  const SizedBox(height: Space.x3),
                  Divider(height: 1, color: c.border),
                ],
              ),
            ),
            if (onTap != null) ...<Widget>[
              const SizedBox(width: Space.x3),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: c.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A run or a job, opened. There is no remote to fetch from here, so the
/// sheet shows exactly what the row carries rather than inventing detail.
Future<void> _showRunDetail(
  BuildContext context, {
  required String title,
  required RunStatus status,
  required Map<String, String> lines,
  String? runId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ShiftColors.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radii.lg),
    ),
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _statusColor(status, c),
                        borderRadius: Radii.pillAll,
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Text(title, style: ShiftType.subheading(c.text)),
                  ),
                ],
              ),
              const SizedBox(height: Space.x4),
              for (final MapEntry<String, String> line in lines.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.x3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 76,
                        child: Text(
                          line.key,
                          style: ShiftType.bodySm(c.textMuted),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          line.value,
                          style: ShiftType.bodyStrong(c.text),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: Space.x2),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: runId == null
                          ? null
                          : () => _rerun(context, runId, title),
                      child: const Text('Re-run'),
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('CLOSE'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The repository (or folder) the tab is pointed at. Only one is wired up
/// for real, so the sheet says so rather than offering a silent no-op.
Future<void> _showScopePicker(BuildContext context, AppState state) {
  final bool jobs = state.showingJobs;
  final String current = jobs ? Seed.jobScope : Seed.agentScope;
  final List<String> options = jobs ? Seed.jobScopes : Seed.agentScopes;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ShiftColors.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radii.lg),
    ),
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(Space.x5),
              child: Text(
                jobs ? 'Run jobs in' : 'Work on',
                style: ShiftType.subheading(c.text),
              ),
            ),
            for (final String option in options)
              ListTile(
                leading: Icon(
                  jobs ? Icons.folder_outlined : Icons.code_rounded,
                  size: 20,
                  color: option == current ? c.accent : c.textMuted,
                ),
                title: Text(
                  option,
                  style: ShiftType.body(
                    option == current ? c.text : c.textMuted,
                  ),
                ),
                trailing: option == current
                    ? Icon(Icons.check_rounded, size: 18, color: c.accent)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  if (option != current) state.setScope(option);
                },
              ),
            const SizedBox(height: Space.x4),
          ],
        ),
      );
    },
  );
}
