import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../widgets/common.dart';
import 'editors.dart';
import '../../widgets/alert.dart';

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
                            needle.isEmpty
                                ? const EmptyState(
                                    icon: Icons.draw_rounded,
                                    title: 'Nothing made yet',
                                    message: 'Pick Slides, Design, a '
                                        'codebase or a Brand above, or '
                                        'describe one in the bar below.',
                                  )
                                : EmptyState(
                                    compact: true,
                                    icon: Icons.search_off_rounded,
                                    title: 'No results',
                                    message: 'No design matches “$_query”.',
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
          child: SearchField(hint: 'Search designs', onChanged: onQuery),
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

/// A design's thumbnail: a sketch of what kind of thing it is, carrying
/// its own colours.
///
/// There are no renders of a design yet, so the card used to be an empty
/// grey block with "Page" in the middle, which is how the vault looked
/// before it had posters. Each kind now draws its shape: a page's header,
/// hero and copy; a deck's stacked slides; a brand's swatches and type.
/// The hero art is the same seeded PosterArt the vault uses, keyed on the
/// design's id, so each design keeps its look from launch to launch.
class _DesignPreview extends StatelessWidget {
  const _DesignPreview({required this.doc});

  final DesignDoc doc;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final String kind = doc.kindLabel.toLowerCase();

    final Widget sketch = switch (kind) {
      'deck' => _deck(c),
      'brand' => _brand(c),
      _ => _page(c),
    };

    return ColoredBox(
      color: c.surfaceRaised,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: sketch),
          Positioned(
            left: Space.x3,
            top: Space.x3,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x2,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.85),
                borderRadius: Radii.pillAll,
              ),
              child: Text(
                doc.kindLabel,
                style: ShiftType.copy(c.textMuted, size: 12, weight: 600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(ShiftColors c, double widthFactor, {double height = 6}) =>
      FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: c.textMuted.withValues(alpha: 0.28),
            borderRadius: Radii.pillAll,
          ),
        ),
      );

  Widget _paper(ShiftColors c, {required Widget child}) => DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.smAll,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: ShiftShadow.color
                  .withValues(alpha: c.isDarkGround ? 0.4 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      );

  /// A web page, cropped by the bottom of the card: nav, hero, copy.
  Widget _page(ShiftColors c) => Padding(
        padding: const EdgeInsets.fromLTRB(40, 40, 40, 0),
        child: _paper(
          c,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Spacer(),
                    for (int i = 0; i < 3; i++) ...<Widget>[
                      const SizedBox(width: 6),
                      SizedBox(width: 18, child: _line(c, 1, height: 4)),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: Radii.smAll,
                  child: SizedBox(height: 56, child: PosterArt(seed: doc.id)),
                ),
                const SizedBox(height: 10),
                _line(c, 0.7, height: 7),
                const SizedBox(height: 6),
                _line(c, 0.9),
                const SizedBox(height: 5),
                _line(c, 0.55),
              ],
            ),
          ),
        ),
      );

  /// Slides: one on top of two, each a little further back.
  Widget _deck(ShiftColors c) => Center(
        child: SizedBox(
          width: 200,
          height: 124,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (final double back in <double>[2, 1])
                Positioned(
                  left: back * 10,
                  right: -back * 10,
                  top: -back * 8,
                  bottom: back * 8,
                  child: Opacity(
                    opacity: 1 - back * 0.3,
                    child: _paper(c, child: const SizedBox.expand()),
                  ),
                ),
              Positioned.fill(
                child: _paper(
                  c,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _line(c, 0.9, height: 8),
                              const SizedBox(height: 6),
                              _line(c, 0.6, height: 8),
                              const SizedBox(height: 12),
                              _line(c, 0.8, height: 4),
                              const SizedBox(height: 4),
                              _line(c, 0.7, height: 4),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: Radii.smAll,
                            child: PosterArt(seed: doc.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  /// A brand sheet: the mark, the type, the palette.
  Widget _brand(ShiftColors c) => Padding(
        padding: const EdgeInsets.fromLTRB(40, 44, 40, 24),
        child: _paper(
          c,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                ClipOval(
                  child: SizedBox.square(
                    dimension: 56,
                    child: PosterArt(seed: doc.id),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Aa', style: ShiftType.sectionTitle(c.text)),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          for (final Color swatch in <Color>[
                            c.accent,
                            c.sky,
                            c.success,
                            c.warning,
                          ]) ...<Widget>[
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: swatch,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
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
        // Filled on a dark ground, a hairline on a light one, as ShiftCard.
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: Radii.lgAll,
          border:
              c.isDarkGround ? null : Border.all(color: c.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (!compact)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radii.lg),
                child: SizedBox(height: 186, child: _DesignPreview(doc: doc)),
              ),
            Padding(
              padding: const EdgeInsets.all(Space.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    doc.title,
                    style: ShiftType.copy(c.text, size: 16, weight: 600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    doc.versionLabel,
                    style: ShiftType.copy(c.textMuted, size: 14),
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
  final bool? yes = await showShiftAlert<bool>(
    context,
    title: 'Delete this design?',
    message: '“${doc.title}” and its ${doc.versionLabel.toLowerCase()} go for '
        'good.',
    actions: const <ShiftAlertAction<bool>>[
      ShiftAlertAction<bool>('Cancel', value: false, isDefault: true),
      ShiftAlertAction<bool>('Delete', value: true, destructive: true),
    ],
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
