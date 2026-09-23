import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';
import 'media_player.dart';

/// Media only, with a two way scope toggle: your own generations, or the
/// published work in EcoVault. Picking a tile opens the detail panel.
class VaultSurface extends StatefulWidget {
  const VaultSurface({super.key});

  @override
  State<VaultSurface> createState() => _VaultSurfaceState();
}

class _VaultSurfaceState extends State<VaultSurface> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<VaultItem> shown = vaultMatches(state.visibleVault, _query);
    final bool searching = _query.trim().isNotEmpty;

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
            // Design had search and the vault, which holds far more, did not.
            // Only shown once there is something to search.
            if (state.visibleVault.isNotEmpty || searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.x6,
                  0,
                  Space.x6,
                  Space.x3,
                ),
                child: SearchField(
                  hint: state.vaultScope == VaultScope.mine
                      ? 'Search your vault'
                      : 'Search EcoVault',
                  onChanged: (String v) => setState(() => _query = v),
                ),
              ),
            Expanded(
              child: searching && shown.isEmpty
                  ? PullToRefresh(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: <Widget>[
                          EmptyState(
                            compact: true,
                            icon: Icons.search_off_rounded,
                            title: 'No results',
                            message: 'Nothing in '
                                '${state.vaultScope.label} matches '
                                '“${_query.trim()}”.',
                          ),
                        ],
                      ),
                    )
                  : _MasonryGrid(items: shown),
            ),
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
                ? '${state.vault.length} made · '
                    '${state.savedFromEco.length} saved'
                : '${state.visibleVault.length} '
                    '${state.visibleVault.length == 1 ? 'item' : 'items'}',
            style: ShiftType.bodySm(c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// The pieces a vault search keeps: every word typed has to appear in the
/// title, the prompt, the creator's name or handle, or the model, in any
/// case and any order. "dusk ferry" finds "Ferry wake at dusk".
List<VaultItem> vaultMatches(List<VaultItem> items, String query) {
  final List<String> words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return items;
  return items.where((VaultItem v) {
    final String haystack = <String?>[
      v.title,
      v.prompt,
      v.byName,
      v.byHandle,
      v.model,
      v.mediaType.name,
    ].whereType<String>().join(' ').toLowerCase();
    return words.every(haystack.contains);
  }).toList(growable: false);
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
      // Scrollable even when empty, so it can still be pulled to reload.
      return PullToRefresh(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            if (state.lastError != null)
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Your vault did not load',
                message: 'It is on the engine, and the engine did not '
                    'answer. Nothing here is missing; it has not arrived.',
                actionLabel: 'Try again',
                onAction: state.refreshing ? null : state.refresh,
              )
            else if (state.vaultScope == VaultScope.mine)
              EmptyState(
                icon: Icons.collections_outlined,
                title: 'Nothing in your vault yet',
                message: 'Anything you make lands here, and so does '
                    'anything you heart in EcoVault.',
                actionLabel: 'Browse EcoVault',
                onAction: () => state.setVaultScope(VaultScope.eco),
              )
            else
              const EmptyState(
                icon: Icons.public_rounded,
                title: 'Nothing in EcoVault yet',
                message: 'When people publish, their work shows up here '
                    'for you to heart.',
              ),
          ],
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
          heights[shortest] += (columnWidth / item.aspect).clamp(150, 420) +
              _VaultTile.captionHeightFor(context) +
              Space.x5;
        }

        return Scrollbar(
          child: PullToRefresh(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                                padding:
                                    const EdgeInsets.only(bottom: Space.x5),
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

  /// The caption under the art: a gap, one line of title, one of detail.
  /// Computed in one place, so the masonry's arithmetic and the tile agree
  /// on how tall a tile is and the columns come out level. It grows with
  /// the text size: a fixed 48 overflowed by 20px at 1.5x text and 40px
  /// at 2x.
  static double captionHeightFor(BuildContext context) {
    final TextScaler scale = MediaQuery.textScalerOf(context);
    return Space.x2 + scale.scale(22) + scale.scale(18);
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool video = item.kind == MediaKind.video;
    final double artHeight = height.clamp(150, 420);
    final String kind = item.mediaType.label;
    // Someone else's piece says whose it is, so it is never mistaken for
    // your own further down the page.
    final String detail = item.mine
        ? <String>[kind, if (item.dimensions.isNotEmpty) item.dimensions]
            .join(' · ')
        : 'By ${item.byName}';

    return Semantics(
      button: true,
      selected: selected,
      label: '${item.title}, ${item.mediaType.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: artHeight,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  MediaThumbnail(
                    seed: item.id,
                    video: video,
                    durationSeconds: item.durationSeconds,
                    selected: selected,
                    thumbnailUrl: item.thumbnailUrl,
                    mediaType: item.mediaType,
                  ),
                  // The heart sits on the corner of the art rather than
                  // behind a tap into the detail: saving while browsing is
                  // the whole ask.
                  if (!item.mine)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: HeartButton(item: item),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: captionHeightFor(context),
              child: Padding(
                padding: const EdgeInsets.only(top: Space.x2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShiftType.copy(
                        c.text,
                        size: 15,
                        weight: 600,
                        lineHeight: 22,
                      ),
                    ),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ShiftType.copy(
                        c.textMuted,
                        size: 13,
                        weight: 500,
                        lineHeight: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
              child: const Text('Save'),
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
              child: const Text('Delete'),
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

    void rerun() {
      // Re-run is the prompt, not a copy of the result: it goes back into
      // the Suite bar so it can be changed before it is sent again.
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
    }

    // One prominent action, the rest in a list below the facts, as an
    // iPhone's detail screens do. It was four equal buttons in a grid,
    // Delete among them in an outline of red.
    final bool canPublish = item.mine && !item.published;

    return ColoredBox(
      color: c.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Space.x5,
            Space.x2,
            Space.x5,
            Space.x6,
          ),
          children: <Widget>[
            SizedBox(
              height: 44,
              child: Row(
                children: <Widget>[
                  if (showBackArrow)
                    Transform.translate(
                      offset: const Offset(-10, 0),
                      child: TextButton.icon(
                        onPressed: onClose,
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          size: 28,
                          color: c.accent,
                        ),
                        label: Text(
                          'Vault',
                          style:
                              ShiftType.copy(c.accent, size: 17, weight: 500),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.only(right: Space.x3),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (!item.mine) HeartButton(item: item),
                  if (!showBackArrow)
                    IconButton(
                      tooltip: 'Close details',
                      onPressed: onClose,
                      icon: Icon(Icons.close_rounded, color: c.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Space.x2),
            Semantics(
              header: true,
              child: Text(
                item.title,
                style: ShiftType.largeTitle(c.text).copyWith(fontSize: 28),
              ),
            ),
            if (!item.mine) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                item.saved
                    ? 'By ${item.byName} · saved to your vault'
                    : 'By ${item.byName}',
                style: ShiftType.copy(c.textMuted, size: 15),
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
                  // The same art as the piece's tile, so opening it lands
                  // on the thing you tapped rather than on a blank box.
                  child: ClipRRect(
                    borderRadius: Radii.lgAll,
                    child: VaultMedia(item: item),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.x5),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: canPublish ? () => _publish(context) : rerun,
                icon: Icon(
                  canPublish ? Icons.public_rounded : Icons.replay_rounded,
                  size: 20,
                ),
                label: Text(canPublish ? 'Publish to EcoVault' : 'Re-run'),
              ),
            ),
            const SizedBox(height: Space.x6),
            const Eyebrow('Prompt'),
            const SizedBox(height: Space.x2),
            Container(
              padding: const EdgeInsets.all(Space.x4),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: Radii.lgAll,
              ),
              child: SelectableText(
                item.prompt,
                style: ShiftType.copy(c.text, size: 15, lineHeight: 22),
              ),
            ),
            const SizedBox(height: Space.x5),
            const Eyebrow('Info'),
            const SizedBox(height: Space.x2),
            GroupedList(
              children: <Widget>[
                _MetaRow(label: 'Model', value: item.model),
                _MetaRow(
                  label: 'Created',
                  value: Fmt.dateTime(item.createdAt),
                ),
                _MetaRow(
                  label: 'Charge',
                  value: item.credits == 1
                      ? '1 credit'
                      : '${item.credits} credits',
                ),
                if (video)
                  _MetaRow(
                    label: 'Length',
                    value: Fmt.seconds(item.durationSeconds),
                  ),
                _MetaRow(
                  label: 'Where',
                  value: !item.mine
                      ? 'EcoVault'
                      : item.published
                          ? 'Published to EcoVault'
                          : 'Your vault',
                ),
              ],
            ),
            const SizedBox(height: Space.x5),
            // Renaming, publishing and deleting are things you do to your
            // own work. Saving someone else's piece does not hand you any
            // of them; what it gives you is the heart and the prompt.
            GroupedList(
              children: <Widget>[
                if (canPublish)
                  _ActionRow(
                    icon: Icons.replay_rounded,
                    label: 'Re-run',
                    onTap: rerun,
                  ),
                if (item.mine)
                  _ActionRow(
                    icon: Icons.edit_outlined,
                    label: 'Rename',
                    onTap: () => _rename(context),
                  )
                else
                  _ActionRow(
                    icon: item.saved
                        ? Icons.heart_broken_outlined
                        : Icons.favorite_border_rounded,
                    label: item.saved
                        ? 'Remove from your vault'
                        : 'Save to your vault',
                    onTap: () => state.toggleSaved(item.id),
                  ),
                if (item.mine)
                  _ActionRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    danger: true,
                    onTap: () => _delete(context),
                  ),
              ],
            ),
            const SizedBox(height: Space.x2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              child: Text(
                video
                    ? 'Re-run puts this clip\u2019s prompt back in the Suite '
                        'bar, where it can be changed before it is sent again.'
                    : 'Re-run puts this prompt back in the Suite bar, where '
                        'it can be changed before it is sent again.',
                style: ShiftType.caption(c.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row in the detail's action list: a symbol and a verb in the accent,
/// or in red for the one that cannot be undone.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final Color tone = danger ? c.danger : c.accent;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.x4),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: tone),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Text(
                  label,
                  style: ShiftType.copy(tone, size: 16, weight: 500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  /// A label on the left and its value on the right, as an Info list is.
  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: 13,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: ShiftType.copy(c.text, size: 15)),
          const SizedBox(width: Space.x4),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: ShiftType.copy(c.textMuted, size: 15),
            ),
          ),
        ],
      ),
    );
  }
}
