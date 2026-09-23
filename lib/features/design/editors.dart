import 'package:flutter/material.dart';

import '../../data/seed.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/common.dart';

/// A piece opened for work: the conversation on the left, what it is making
/// on the right. The shell steps out of the way — this takes the window.
class DesignEditorScreen extends StatefulWidget {
  const DesignEditorScreen({required this.kind, this.title, super.key});

  final DesignKind kind;
  final String? title;

  static Future<void> open(
    BuildContext context,
    DesignKind kind, {
    String? title,
  }) {
    final AppState state = AppScope.read(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) => AppScope(
          notifier: state,
          child: DesignEditorScreen(kind: kind, title: title),
        ),
      ),
    );
  }

  @override
  State<DesignEditorScreen> createState() => _DesignEditorScreenState();
}

class _DesignEditorScreenState extends State<DesignEditorScreen> {
  /// The chat pane folds away when you want the whole window for the work.
  bool _chatOpen = true;

  /// Whether the preview has anything in it yet.
  bool _filled = false;

  /// On a phone, which pane is showing: the chat (0) or the preview (1).
  int _pane = 0;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final DesignKind kind = widget.kind;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool split = constraints.maxWidth >= kSplitBreakpoint;
            final Widget chat = _ChatPane(
              kind: kind,
              title: widget.title,
              chatOpen: _chatOpen,
              onToggleChat: () => setState(() => _chatOpen = !_chatOpen),
              onMake: () => setState(() => _filled = true),
            );
            final Widget preview = _PreviewPane(
              kind: kind,
              filled: _filled,
              onMake: () => setState(() => _filled = true),
            );

            // On a phone the two panes are a segmented choice, the same
            // control the rest of the app uses, not Material's underlined
            // tabs. Both stay built, so a half-written message survives a
            // look at the preview.
            if (!split) {
              final Widget phoneChat = _ChatPane(
                kind: kind,
                title: widget.title,
                chatOpen: true,
                onToggleChat: () {},
                onMake: () => setState(() => _filled = true),
                showHeader: false,
              );
              return Column(
                children: <Widget>[
                  // Back first, then the switch: on an iPhone the way out
                  // is always the top-left corner.
                  SizedBox(
                    height: 52,
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: Space.x1),
                        IconButton(
                          tooltip: 'Back to Design',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            size: 30,
                            color: c.accent,
                          ),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.title ?? kind.untitled,
                            overflow: TextOverflow.ellipsis,
                            style: ShiftType.copy(
                              c.text,
                              size: 17,
                              weight: 600,
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.x4),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.x4,
                      Space.x2,
                      Space.x4,
                      0,
                    ),
                    child: SegmentedPills<int>(
                      options: const <int>[0, 1],
                      labelOf: (int i) => i == 0 ? 'Chat' : kind.paneLabel,
                      selected: _pane,
                      onChanged: (int i) => setState(() => _pane = i),
                      expand: true,
                    ),
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _pane,
                      children: <Widget>[phoneChat, preview],
                    ),
                  ),
                ],
              );
            }

            if (!_chatOpen) {
              return Column(
                children: <Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.x3,
                        Space.x2,
                        0,
                        0,
                      ),
                      child: TextButton.icon(
                        onPressed: () => setState(() => _chatOpen = true),
                        icon: const Icon(Icons.view_sidebar_outlined, size: 18),
                        label: const Text('Show the chat'),
                        style: TextButton.styleFrom(
                          foregroundColor: c.accent,
                          minimumSize: const Size(0, 44),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: preview),
                ],
              );
            }

            return Row(
              children: <Widget>[
                Expanded(flex: 44, child: chat),
                VerticalDivider(width: 1, color: c.border),
                Expanded(flex: 56, child: preview),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Below this the two panes stack behind a tab bar rather than squeezing.
const double kSplitBreakpoint = 900;

class _ChatPane extends StatelessWidget {
  const _ChatPane({
    required this.kind,
    required this.chatOpen,
    required this.onToggleChat,
    required this.onMake,
    this.title,
    this.showHeader = true,
  });

  /// Off on a phone, where the back button and title sit above the
  /// Chat / preview switch instead of inside one of its panes.
  final bool showHeader;

  final DesignKind kind;
  final String? title;
  final bool chatOpen;
  final VoidCallback onToggleChat;
  final VoidCallback onMake;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    return Column(
      children: <Widget>[
        if (showHeader)
          SizedBox(
            height: 60,
            child: Row(
              children: <Widget>[
                const SizedBox(width: Space.x2),
                IconButton(
                  tooltip: 'Back to Design',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    size: 30,
                    color: c.accent,
                  ),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
                Flexible(
                  child: Text(
                    title ?? kind.untitled,
                    style: ShiftType.copy(c.text, size: 17, weight: 600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: c.textMuted,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Hide this pane',
                  onPressed: onToggleChat,
                  icon: Icon(
                    Icons.view_sidebar_outlined,
                    size: 20,
                    color: c.accent,
                  ),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
                IconButton(
                  tooltip: 'Open in a new window',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A second window needs the desktop build — hide the '
                        'chat pane for the full width here.',
                      ),
                    ),
                  ),
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 20,
                    color: c.accent,
                  ),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
                const SizedBox(width: Space.x2),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Space.x6),
            child: Column(
              children: <Widget>[
                const SizedBox(height: Space.x8),
                // The same accent disc the empty screens use, and a title
                // set like one, rather than a 40pt light headline.
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: c.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(kind.icon, size: 32, color: c.accent),
                ),
                const SizedBox(height: Space.x5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    kind.prompt,
                    textAlign: TextAlign.center,
                    style: ShiftType.largeTitle(c.text).copyWith(fontSize: 28),
                  ),
                ),
                const SizedBox(height: Space.x6),
                if (kind.startsFromBrand)
                  OutlinedButton.icon(
                    onPressed: () => _chooseBrand(context),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                    ),
                    label: const Text('Choose a brand'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.text,
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.x5,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: Radii.mdAll,
                      ),
                      textStyle: ShiftType.copy(c.text, size: 15, weight: 600),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 690),
                    child: Column(
                      children: Seed.sourceOptions
                          .map(
                            (SourceOption option) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: Space.x3,
                              ),
                              child: _SourceCard(
                                option: option,
                                onTap: onMake,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                const SizedBox(height: Space.x8),
              ],
            ),
          ),
        ),
        const PillComposer(hint: 'Write a message', width: 820),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.option, required this.onTap});

  final SourceOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: Radii.lgAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Radii.lgAll,
            border: Border.all(color: c.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  borderRadius: Radii.mdAll,
                ),
                child: Icon(option.icon, size: 20, color: c.accent),
              ),
              const SizedBox(width: Space.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(option.title, style: ShiftType.bodyStrong(c.text)),
                    const SizedBox(height: 2),
                    Text(
                      option.detail,
                      style: ShiftType.bodySm(c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    required this.kind,
    required this.filled,
    required this.onMake,
  });

  final DesignKind kind;
  final bool filled;
  final VoidCallback onMake;

  /// What sits in the toolbar, per kind.
  List<IconData> get _tools => switch (kind) {
        DesignKind.brand => <IconData>[Icons.notes_rounded],
        DesignKind.codebase => <IconData>[
            Icons.description_outlined,
            Icons.folder_outlined,
            Icons.check_circle_outline_rounded,
          ],
        DesignKind.design => <IconData>[
            Icons.near_me_outlined,
            Icons.pan_tool_outlined,
            Icons.text_fields_rounded,
            Icons.grid_on_rounded,
            Icons.sticky_note_2_outlined,
            Icons.draw_outlined,
            Icons.category_outlined,
          ],
        DesignKind.slides => <IconData>[
            Icons.text_fields_rounded,
            Icons.image_outlined,
            Icons.table_chart_outlined,
            Icons.category_outlined,
            Icons.play_arrow_rounded,
          ],
      };

  String get _zoom => kind == DesignKind.design ? '50%' : '100%';

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    return Container(
      color: c.bg,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 60,
            child: Row(
              children: <Widget>[
                const SizedBox(width: Space.x5),
                Text(kind.paneLabel, style: ShiftType.body(c.text)),
                const SizedBox(width: Space.x1),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: c.textMuted,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Comments',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No comments on this yet.')),
                  ),
                  icon: Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 20,
                    color: c.textMuted,
                  ),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
                const SizedBox(width: Space.x2),
                OutlinedButton.icon(
                  onPressed: () => _share(context, kind),
                  icon: const Icon(Icons.lock_outline_rounded, size: 15),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.text,
                    minimumSize: const Size(0, 44),
                    side: BorderSide(color: c.borderStrong),
                    shape: const RoundedRectangleBorder(
                      borderRadius: Radii.mdAll,
                    ),
                    textStyle: ShiftType.copy(c.text, size: 15, weight: 600),
                  ),
                ),
                IconButton(
                  tooltip: 'Full screen',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hide the chat pane for the full width.'),
                    ),
                  ),
                  icon: Icon(
                    Icons.open_in_full_rounded,
                    size: 20,
                    color: c.textMuted,
                  ),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: c.textMuted,
                  ),
                  style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
                ),
                const SizedBox(width: Space.x2),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x5,
              0,
              Space.x5,
              Space.x3,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(Space.x1),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: Radii.mdAll,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int i = 0; i < _tools.length; i++)
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == 0 ? c.accentSoft : Colors.transparent,
                            borderRadius: Radii.smAll,
                          ),
                          child: Icon(
                            _tools[i],
                            size: 20,
                            color: i == 0 ? c.accent : c.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(_zoom, style: ShiftType.caption(c.textMuted)),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Expanded(
            child: Stack(
              children: <Widget>[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.x6),
                    child: filled
                        ? _Artboard(kind: kind)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(kind.icon, size: 34, color: c.textMuted),
                              const SizedBox(height: Space.x5),
                              Text(
                                kind.emptyLine,
                                textAlign: TextAlign.center,
                                style: ShiftType.body(c.textMuted),
                              ),
                              const SizedBox(height: Space.x5),
                              FilledButton(
                                onPressed: onMake,
                                style: FilledButton.styleFrom(
                                  backgroundColor: c.accent,
                                  foregroundColor: c.onAccent,
                                  minimumSize: const Size(0, 52),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Space.x5,
                                  ),
                                ),
                                child: Text(kind.emptyAction),
                              ),
                            ],
                          ),
                  ),
                ),
                if (kind == DesignKind.design)
                  Positioned(
                    right: Space.x4,
                    bottom: Space.x4,
                    child: Container(
                      width: 148,
                      height: 100,
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border.all(color: c.borderStrong),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the preview shows once there is something in it. No bytes come back
/// from a model here, so this is an honest blank artboard rather than a
/// picture pretending to be generated work.
class _Artboard extends StatelessWidget {
  const _Artboard({required this.kind});

  final DesignKind kind;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final double aspect = switch (kind) {
      DesignKind.slides => 16 / 9,
      DesignKind.brand => 4 / 3,
      _ => 3 / 4,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
      child: AspectRatio(
        aspectRatio: aspect,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Radii.lgAll,
            border: Border.all(color: c.borderStrong),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(kind.icon, size: 30, color: c.accent),
              const SizedBox(height: Space.x4),
              Text(kind.untitled, style: ShiftType.bodyStrong(c.text)),
              const SizedBox(height: Space.x2),
              Text(
                'Draft 1 · nothing rendered yet',
                style: ShiftType.caption(c.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _chooseBrand(BuildContext context) async {
  final String? picked = await showModalBottomSheet<String>(
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
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(Space.x5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a brand',
                  style: ShiftType.subheading(c.text),
                ),
              ),
            ),
            for (final String brand in Seed.brands)
              ListTile(
                title: Text(brand, style: ShiftType.body(c.text)),
                onTap: () => Navigator.of(context).pop(brand),
              ),
            const SizedBox(height: Space.x4),
          ],
        ),
      );
    },
  );
  if (picked != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Using $picked')),
    );
  }
}

Future<void> _share(BuildContext context, DesignKind kind) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      return AlertDialog(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text('Share', style: ShiftType.subheading(c.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.lock_outline_rounded, size: 16, color: c.textMuted),
                const SizedBox(width: Space.x2),
                Text(
                  'Only you can open this',
                  style: ShiftType.bodySm(c.textMuted),
                ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Text(
              'Sharing needs the backend to mint a link — nothing leaves this '
              'device yet.',
              style: ShiftType.bodySm(c.text),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
