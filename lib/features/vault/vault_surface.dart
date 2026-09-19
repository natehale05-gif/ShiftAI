import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';

/// Media only, with a two way scope toggle: your own generations, or the
/// published work in EcoVault. Picking a tile opens the detail panel.
class VaultSurface extends StatelessWidget {
  const VaultSurface({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 1040;
        final VaultItem? selected = state.selectedVaultItem;

        final Widget grid = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _ScopeBar(),
            // The vault is the engine's. An empty grid with no explanation
            // reads as "you have made nothing", which is a different
            // sentence from "the engine did not answer".
            const Padding(
              padding: EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, 0),
              child: EngineBanner(),
            ),
            Expanded(child: _MasonryGrid(items: state.visibleVault)),
          ],
        );

        // On a phone the detail takes the screen, so it slides in over the
        // grid rather than the grid simply vanishing.
        if (!wide) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
            child: selected == null
                ? KeyedSubtree(
                    key: const ValueKey<String>('vault-grid'),
                    child: grid,
                  )
                : KeyedSubtree(
                    key: ValueKey<String>('vault-detail-${selected.id}'),
                    child: _DetailPanel(
                      item: selected,
                      onClose: () => state.selectVaultItem(null),
                      showBackArrow: true,
                    ),
                  ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: grid),
            if (selected != null) ...<Widget>[
              VerticalDivider(width: 1, color: ShiftColors.of(context).border),
              SizedBox(
                width: 380,
                child: _DetailPanel(
                  item: selected,
                  onClose: () => state.selectVaultItem(null),
                  showBackArrow: false,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ScopeBar extends StatelessWidget {
  const _ScopeBar();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.x6,
        Space.x5,
        Space.x6,
        Space.x3,
      ),
      // A Row put the count on top of the ECOVAULT pill on a phone, which
      // also swallowed the tap. Wrapping drops the count onto its own
      // line when the two will not sit side by side.
      child: Wrap(
        spacing: Space.x4,
        runSpacing: Space.x2,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SegmentedPills<VaultScope>(
            options: VaultScope.values,
            labelOf: (VaultScope s) => s.label,
            selected: state.vaultScope,
            onChanged: state.setVaultScope,
          ),
          // In My Vault the split is worth stating: what you made, and
          // what you saved from other people.
          Text(
            state.vaultScope == VaultScope.mine && state.savedFromEco.isNotEmpty
                ? '${state.vault.length} MADE · '
                    '${state.savedFromEco.length} SAVED'
                : '${state.visibleVault.length} ITEMS',
            style: ShiftType.labelSm(c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A masonry that needs no package: items are dealt into whichever column
/// is shortest, so tiles keep their own aspect.
class _MasonryGrid extends StatelessWidget {
  const _MasonryGrid({required this.items});

  final List<VaultItem> items;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    if (items.isEmpty) {
      final ShiftColors c = ShiftColors.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: Text(
            state.lastError != null
                ? 'Your vault is on the engine, and it did not answer. '
                    'Nothing here is missing — it just has not arrived.'
                : state.vaultScope == VaultScope.mine
                    ? 'Nothing in your vault yet. Anything you make lands '
                        'here, and so does anything you heart in EcoVault.'
                    : 'Nothing published to EcoVault yet.',
            textAlign: TextAlign.center,
            style: ShiftType.body(c.textMuted),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.maxWidth - Space.x6 * 2;
        final int columns = available >= 1040
            ? 4
            : available >= 560
                ? 3
                : 2;
        final double columnWidth =
            (available - Space.x4 * (columns - 1)) / columns;

        final List<List<VaultItem>> buckets =
            List<List<VaultItem>>.generate(columns, (_) => <VaultItem>[]);
        final List<double> heights = List<double>.filled(columns, 0);

        for (final VaultItem item in items) {
          int shortest = 0;
          for (int i = 1; i < columns; i++) {
            if (heights[i] < heights[shortest]) shortest = i;
          }
          buckets[shortest].add(item);
          // The tile clamps its height, so the bookkeeping has to clamp too
          // or the columns come out ragged.
          heights[shortest] +=
              (columnWidth / item.aspect).clamp(150, 420) + Space.x4;
        }

        return Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              Space.x6,
              Space.x3,
              Space.x6,
              Space.x6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < columns; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: Space.x4),
                  SizedBox(
                    width: columnWidth,
                    child: Column(
                      children: buckets[i]
                          .map(
                            (VaultItem item) => Padding(
                              padding: const EdgeInsets.only(bottom: Space.x4),
                              child: _VaultTile(
                                item: item,
                                height: columnWidth / item.aspect,
                                selected: state.selectedVaultId == item.id,
                                onTap: () => state.selectVaultItem(item.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VaultTile extends StatelessWidget {
  const _VaultTile({
    required this.item,
    required this.height,
    required this.selected,
    required this.onTap,
  });

  final VaultItem item;
  final double height;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool video = item.kind == MediaKind.video;
    final double tileHeight = height.clamp(150, 420);
    return Semantics(
      button: true,
      selected: selected,
      label: '${item.title}, ${item.kind.name}',
      child: Stack(
        children: <Widget>[
          InkWell(
            borderRadius: Radii.lgAll,
            onTap: onTap,
            child: SizedBox(
              height: tileHeight,
              child: MediaPlaceholder(
                label: item.title,
                tag: item.kind.name,
                selected: selected,
                labelMaxLines: 2,
                // Someone else's piece says whose it is, on the tile, so
                // it is never mistaken for your own further down the page.
                caption: item.mine
                    ? (video
                        ? '${Fmt.seconds(item.durationSeconds)} · '
                            '${item.dimensions}'
                        : item.dimensions)
                    : 'By ${item.byName}',
              ),
            ),
          ),
          // The heart sits on the corner of the tile rather than behind a
          // tap into the detail: saving while browsing is the whole ask.
          if (!item.mine)
            Positioned(
              top: 4,
              right: 4,
              child: HeartButton(item: item),
            ),
        ],
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.item,
    required this.onClose,
    required this.showBackArrow,
  });

  final VaultItem item;
  final VoidCallback onClose;
  final bool showBackArrow;

  Future<void> _rename(BuildContext context) async {
    final AppState state = AppScope.read(context);
    final TextEditingController controller =
        TextEditingController(text: item.title);
    final String? next = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final ShiftColors c = ShiftColors.of(context);
        return AlertDialog(
          backgroundColor: c.surface,
          shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
          title: Text('Rename', style: ShiftType.subheading(c.text)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: ShiftType.bodySm(c.text),
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (next == null || next.trim().isEmpty || !context.mounted) return;
    final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
    if (!await state.renameVaultItem(item.id, next.trim())) {
      _refused(bar, state, 'rename it');
    }
  }

  /// A write the engine turned down rolls the screen back. Saying nothing
  /// at that point is what makes a working button look broken.
  static void _refused(
    ScaffoldMessengerState bar,
    AppState state,
    String what,
  ) {
    bar.showSnackBar(
      SnackBar(
        content: Text(state.lastError?.message ?? 'Could not $what.'),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final AppState state = AppScope.read(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final ShiftColors c = ShiftColors.of(context);
        return AlertDialog(
          backgroundColor: c.surface,
          shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
          title: Text('Delete this item?', style: ShiftType.subheading(c.text)),
          content: Text(
            'It leaves your vault for good. Anything published from it stays '
            'in EcoVault.',
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
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
    if (!(confirmed ?? false) || !context.mounted) return;
    final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
    if (!await state.deleteVaultItem(item.id)) {
      _refused(bar, state, 'delete it');
    }
  }

  /// Publishing is a write like any other, so a refusal is shown rather
  /// than quietly undone.
  Future<void> _publish(BuildContext context) async {
    final AppState state = AppScope.read(context);
    final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
    if (!await state.publishVaultItem(item.id)) {
      _refused(bar, state, 'publish it');
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final bool video = item.kind == MediaKind.video;

    return Container(
      color: c.surface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.x5),
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showBackArrow)
                  IconButton(
                    tooltip: 'Back to the vault',
                    onPressed: onClose,
                    icon: Icon(Icons.arrow_back_rounded, color: c.text),
                  ),
                Expanded(
                  child: Text(
                    item.title,
                    style: ShiftType.subheading(c.text),
                  ),
                ),
                if (!item.mine) HeartButton(item: item),
                if (!showBackArrow)
                  IconButton(
                    tooltip: 'Close details',
                    onPressed: onClose,
                    icon: Icon(Icons.close_rounded, color: c.textMuted),
                  ),
              ],
            ),
            if (!item.mine) ...<Widget>[
              const SizedBox(height: Space.x1),
              Text(
                item.saved
                    ? 'By ${item.byName} · saved to your vault'
                    : 'By ${item.byName}',
                style: ShiftType.bodySm(c.textMuted),
              ),
            ],
            const SizedBox(height: Space.x4),
            // A 9:16 clip would otherwise fill a phone screen on its own and
            // push everything worth reading below the fold.
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.46,
                ),
                child: AspectRatio(
                  aspectRatio: item.aspect,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surfaceRaised,
                      borderRadius: Radii.lgAll,
                      border: Border.all(color: c.borderStrong),
                    ),
                    child: Icon(
                      video
                          ? Icons.play_circle_outline_rounded
                          : Icons.image_outlined,
                      size: 40,
                      color: c.sky,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.x5),
            const Eyebrow('Prompt'),
            const SizedBox(height: Space.x2),
            Text(item.prompt, style: ShiftType.bodySm(c.text)),
            const SizedBox(height: Space.x5),
            Divider(color: c.border),
            const SizedBox(height: Space.x3),
            _MetaRow(label: 'Model', value: item.model),
            _MetaRow(label: 'Created', value: Fmt.dateTime(item.createdAt)),
            _MetaRow(label: 'Charge', value: '${item.credits} credits'),
            if (video)
              _MetaRow(
                label: 'Length',
                value: Fmt.seconds(item.durationSeconds),
              ),
            _MetaRow(
              label: 'Where',
              value: !item.mine
                  ? 'EcoVault · ${item.byName}'
                  : item.published
                      ? 'Published to EcoVault'
                      : 'Your vault',
            ),
            const SizedBox(height: Space.x5),
            // Renaming, publishing and deleting are things you do to your
            // own work. Saving someone else's piece does not hand you any
            // of them — what it gives you is the heart and the prompt.
            if (item.mine) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rename(context),
                      child: const Text('Rename'),
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          item.published ? null : () => _publish(context),
                      child: Text(item.published ? 'PUBLISHED' : 'PUBLISH'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x3),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    // Re-run is the prompt, not a copy of the result: it
                    // goes back into the Suite bar so it can be changed
                    // before it is sent again.
                    onPressed: () {
                      state.reusePrompt(item.prompt);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            video
                                ? 'The clip\u2019s prompt is back in the bar.'
                                : 'That prompt is back in the bar.',
                          ),
                        ),
                      );
                    },
                    child: const Text('Re-run'),
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: item.mine
                      ? OutlinedButton(
                          onPressed: () => _delete(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: c.danger,
                            side: BorderSide(color: c.danger),
                          ),
                          child: const Text('Delete'),
                        )
                      : OutlinedButton(
                          onPressed: () => state.toggleSaved(item.id),
                          // The heart above already says which state it
                          // is in, so the button only needs the verb.
                          child: Text(item.saved ? 'Remove' : 'Save'),
                        ),
                ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Text(
              video
                  ? 'Re-run puts this clip\u2019s prompt back in the Suite bar, '
                      'where it can be changed before it is sent again.'
                  : 'Re-run puts this prompt back in the Suite bar, where it '
                      'can be changed before it is sent again.',
              style: ShiftType.caption(c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(label, style: ShiftType.bodySm(c.textMuted)),
          ),
          Expanded(
            child: Text(value, style: ShiftType.bodyStrong(c.text)),
          ),
        ],
      ),
    );
  }
}
