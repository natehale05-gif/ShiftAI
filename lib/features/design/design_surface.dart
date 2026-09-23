import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/common.dart';
import 'editors.dart';

/// The Design hub: four things you can start, then everything you have
/// already made.
class DesignSurface extends StatefulWidget {
  const DesignSurface({super.key});

  @override
  State<DesignSurface> createState() => _DesignSurfaceState();
}

class _DesignSurfaceState extends State<DesignSurface> {
  static const double _maxWidth = 1560;

  String _query = '';
  bool _asList = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String needle = _query.trim().toLowerCase();
    final List<DesignDoc> shown = needle.isEmpty
        ? state.designs
        : state.designs
            .where((DesignDoc d) => d.title.toLowerCase().contains(needle))
            .toList(growable: false);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // On a phone the tiles go two up and the cards go full width,
        // rather than keeping a desktop size that no longer fits.
        final bool narrow = constraints.maxWidth < 620;
        final double gutter = narrow ? Space.x5 : Space.x6;
        final double room = constraints.maxWidth - gutter * 2;
        final double tileWidth = narrow ? (room - Space.x4) / 2 : 246;
        // Four big squares eat a whole phone screen before you reach
        // anything you have made, so the tiles go short and wide instead.
        final double tileHeight = narrow ? 88 : 164;
        final double cardWidth = narrow ? room : 372;

        return Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  Space.x5,
                  gutter,
                  Space.x5,
                ),
                children: <Widget>[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const EngineBanner(),
                          const Eyebrow('Make something new'),
                          const SizedBox(height: Space.x4),
                          Wrap(
                            spacing: narrow ? Space.x4 : Space.x5,
                            runSpacing: narrow ? Space.x4 : Space.x5,
                            children: DesignKind.values
                                .map(
                                  (DesignKind kind) => _StartTile(
                                    kind: kind,
                                    width: tileWidth,
                                    height: tileHeight,
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: Space.x6),
                          _SearchRow(
                            query: _query,
                            asList: _asList,
                            onQuery: (String v) => setState(() => _query = v),
                            onToggleList: () =>
                                setState(() => _asList = !_asList),
                          ),
                          const SizedBox(height: Space.x5),
                          if (shown.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: Space.x5),
                              child: Text(
                                needle.isEmpty
                                    ? 'Nothing made yet. Start one above.'
                                    : 'No design matches “$_query”.',
                                style: ShiftType.body(
                                  ShiftColors.of(context).textMuted,
                                ),
                              ),
                            )
                          else
                            Wrap(
                              spacing: Space.x5,
                              runSpacing: Space.x5,
                              children: shown
                                  .map(
                                    (DesignDoc doc) => _DesignCard(
                                      doc: doc,
                                      width: _asList ? room : cardWidth,
                                      compact: _asList,
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PillComposer(
              hint: 'Describe a page',
              onSend: (_) {
                DesignEditorScreen.open(context, DesignKind.design);
                return true;
              },
            ),
          ],
        );
      },
    );
  }
}

class _StartTile extends StatelessWidget {
  const _StartTile({
    required this.kind,
    required this.width,
    required this.height,
  });

  final DesignKind kind;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            button: true,
            label: 'New ${kind.label}',
            child: InkWell(
              borderRadius: Radii.lgAll,
              onTap: () => DesignEditorScreen.open(context, kind),
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceRaised,
                  borderRadius: Radii.lgAll,
                ),
                child: Icon(
                  kind.icon,
                  size: height < 120 ? 26 : 34,
                  color: c.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.x2),
          Text(
            kind.label,
            style: ShiftType.body(c.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.query,
    required this.asList,
    required this.onQuery,
    required this.onToggleList,
  });

  final String query;
  final bool asList;
  final ValueChanged<String> onQuery;
  final VoidCallback onToggleList;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          // A filled search field, as a list's search bar is drawn, not an
          // outlined capsule.
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: Space.x3),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: Radii.mdAll,
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.search_rounded, size: 19, color: c.textMuted),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: TextField(
                    onChanged: onQuery,
                    style: ShiftType.copy(c.text, size: 16),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Search designs',
                      hintStyle: ShiftType.copy(c.textMuted, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: Space.x3),
        IconButton(
          tooltip: asList ? 'Show as a grid' : 'Show as a list',
          onPressed: onToggleList,
          icon: Icon(
            asList ? Icons.grid_view_rounded : Icons.view_list_rounded,
            size: 22,
            color: asList ? c.accent : c.textMuted,
          ),
          style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
        ),
      ],
    );
  }
}

class _DesignCard extends StatelessWidget {
  const _DesignCard({
    required this.doc,
    required this.width,
    this.compact = false,
  });

  final DesignDoc doc;
  final double width;

  /// List view drops the big thumbnail and keeps the row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.lgAll,
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!compact)
              Container(
                height: 186,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceRaised,
                  borderRadius: const BorderRadius.vertical(top: Radii.lg),
                ),
                child: Text(
                  doc.kindLabel,
                  style: ShiftType.caption(c.textMuted),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(doc.title, style: ShiftType.body(c.text)),
                  const SizedBox(height: 2),
                  Text(
                    doc.versionLabel,
                    style: ShiftType.bodySm(c.textMuted),
                  ),
                  const SizedBox(height: Space.x2),
                  Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Open',
                        onPressed: () => DesignEditorScreen.open(
                          context,
                          DesignKind.design,
                          title: doc.title,
                        ),
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 19,
                          color: c.textMuted,
                        ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Duplicate',
                        // The toast waits for the engine: saying it was
                        // duplicated before the write lands is a lie the
                        // rollback then quietly contradicts.
                        onPressed: () async {
                          final AppState state = AppScope.read(context);
                          final ScaffoldMessengerState bar =
                              ScaffoldMessenger.of(context);
                          final bool took = await state.duplicateDesign(doc.id);
                          bar.showSnackBar(
                            SnackBar(
                              content: Text(
                                took
                                    ? 'Duplicated “${doc.title}”'
                                    : state.lastError?.message ??
                                        'Could not duplicate it.',
                              ),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 19,
                          color: c.textMuted,
                        ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => _confirmDelete(context, doc),
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: c.textMuted,
                        ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                    ],
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

Future<void> _confirmDelete(BuildContext context, DesignDoc doc) async {
  final AppState state = AppScope.read(context);
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      return AlertDialog(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text('Delete this design?', style: ShiftType.subheading(c.text)),
        content: Text(
          '“${doc.title}” and its ${doc.versionLabel.toLowerCase()} go for '
          'good.',
          style: ShiftType.bodySm(c.textMuted),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.danger,
              foregroundColor: c.onStatus,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  if (!(yes ?? false) || !context.mounted) return;
  final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
  if (!await state.deleteDesign(doc.id)) {
    bar.showSnackBar(
      SnackBar(
        content: Text(state.lastError?.message ?? 'Could not delete it.'),
      ),
    );
  }
}
