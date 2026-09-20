import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/modes.dart';
import '../../app/shell.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/file_pick.dart';
import '../../widgets/common.dart';
import 'account_card.dart';
import 'avatar.dart';
import 'connectors.dart';

/// Appearance, the avatar maker, connections and the account, in order.
class SettingsSurface extends StatelessWidget {
  const SettingsSurface({super.key});

  @override
  Widget build(BuildContext context) {
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _AppearanceCard(),
                SizedBox(height: Space.x4),
                _FeaturesCard(),
                SizedBox(height: Space.x4),
                _AvatarCard(),
                SizedBox(height: Space.x4),
                _ConnectionsCard(),
                SizedBox(height: Space.x4),
                AccountCard(),
                // Only in a debug build: pointing the app at an engine is
                // a developer's job, not something to ship to a creator.
                if (kDebugMode) ...<Widget>[
                  SizedBox(height: Space.x4),
                  _EngineCard(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Eyebrow('Appearance'),
          const SizedBox(height: Space.x3),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // Four themes no longer fit across one row on a laptop, so
              // they wrap into a grid rather than squeezing.
              final int columns = constraints.maxWidth >= 860
                  ? 4
                  : constraints.maxWidth >= 520
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ShiftThemeId.values.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: Space.x3,
                  crossAxisSpacing: Space.x3,
                  mainAxisExtent: 66,
                ),
                itemBuilder: (BuildContext context, int i) {
                  final ShiftThemeId id = ShiftThemeId.values[i];
                  return _ThemeTile(
                    id: id,
                    selected: state.themeId == id,
                    onTap: () => state.setTheme(id),
                  );
                },
              );
            },
          ),
          const SizedBox(height: Space.x3),
          Text(
            'The retro pair carries the older SHIFT identity — neon on '
            'black, or the same ink on white. Retro neon is what a new '
            'account opens on; dark and light are the plainer pair.',
            style: ShiftType.caption(ShiftColors.of(context).textMuted),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.id,
    required this.selected,
    required this.onTap,
  });

  final ShiftThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final ShiftColors preview = ShiftColors.forTheme(id);

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: Radii.mdAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.x4),
          decoration: BoxDecoration(
            color: selected ? c.accentSoft : c.surface,
            borderRadius: Radii.mdAll,
            border: Border.all(color: selected ? c.accent : c.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: preview.bg,
                  borderRadius: Radii.smAll,
                  border: Border.all(color: preview.border),
                ),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: preview.accent,
                    borderRadius: Radii.pillAll,
                  ),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Text(id.label, style: ShiftType.bodyStrong(c.text)),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 18, color: c.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// The switches that hide whole sections of the app.
///
/// Off means gone, not greyed out: the sidebar row, the surface and every
/// link into it disappear together. Nothing here deletes anything — a
/// feature switched back on returns with its contents untouched.
class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Eyebrow('Sections'),
          const SizedBox(height: Space.x2),
          Text(
            'Switch off what you do not use. Nothing is deleted, and Suite '
            'and Settings always stay.',
            style: ShiftType.caption(c.textMuted),
          ),
          const SizedBox(height: Space.x3),
          for (final ShiftFeature feature in ShiftFeature.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          feature.label,
                          style: ShiftType.bodyStrong(c.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feature.description,
                          style: ShiftType.caption(c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.x3),
                  Switch(
                    value: state.isEnabled(feature),
                    onChanged: (bool on) =>
                        state.setFeatureEnabled(feature, on),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ConnectionsCard extends StatelessWidget {
  const _ConnectionsCard();

  @override
  Widget build(BuildContext context) {
    // Gated here rather than in the list above so that list stays const.
    // The SizedBox leaves the spacer above it, which is invisible anyway.
    if (!AppScope.of(context).isEnabled(ShiftFeature.connectors)) {
      return const SizedBox.shrink();
    }
    final ShiftColors c = ShiftColors.of(context);
    // The catalogue comes from the engine; with no server behind it that
    // is the built-in list, so this reads the same either way.
    final List<Connector> all = AppScope.of(context).connectors;
    final List<Connector> live =
        all.where((Connector x) => x.live).toList(growable: false);

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Eyebrow(
                  'Connections · ${live.length} of ${all.length} live',
                ),
              ),
              TextButton(
                onPressed: () => _showCatalog(context),
                child: Text('Browse all', style: ShiftType.bodySm(c.accent)),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = constraints.maxWidth >= 720 ? 3 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: live.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: Space.x3,
                  crossAxisSpacing: Space.x3,
                  mainAxisExtent: 60,
                ),
                itemBuilder: (BuildContext context, int i) =>
                    _ConnectorRow(live[i]),
              );
            },
          ),
          const SizedBox(height: Space.x3),
          Text(
            live.isEmpty
                ? 'Nothing connected yet. Browse all to see what SHIFT can '
                    'talk to, and authorise the ones you use.'
                : 'The other ${all.length - live.length} are listed and '
                    'ready to authorise. Logos are placeholders until the '
                    'real marks are dropped in.',
            style: ShiftType.caption(c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// "Browse all" used to go nowhere. It now opens the catalogue, searchable,
/// with the live ones first — the same list the real client reads.
Future<void> _showCatalog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ShiftColors.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radii.lg),
    ),
    builder: (BuildContext context) => const _CatalogSheet(),
  );
}

class _CatalogSheet extends StatefulWidget {
  const _CatalogSheet();

  @override
  State<_CatalogSheet> createState() => _CatalogSheetState();
}

class _CatalogSheetState extends State<_CatalogSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final String needle = _query.trim().toLowerCase();
    final List<Connector> matches = AppScope.of(context)
        .connectors
        .where((Connector x) => x.name.toLowerCase().contains(needle))
        .toList(growable: false)
      ..sort((Connector a, Connector b) {
        if (a.live != b.live) return a.live ? -1 : 1;
        return a.name.compareTo(b.name);
      });

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (BuildContext context, ScrollController scroll) {
        return Column(
          children: <Widget>[
            const SizedBox(height: Space.x3),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.borderStrong,
                borderRadius: Radii.pillAll,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.x5,
                Space.x4,
                Space.x5,
                Space.x3,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Connections',
                      style: ShiftType.subheading(c.text),
                    ),
                  ),
                  Text(
                    '${matches.length} OF '
                    '${AppScope.of(context).connectors.length}',
                    style: ShiftType.labelSm(c.textMuted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x5),
              child: TextField(
                autofocus: false,
                style: ShiftType.bodySm(c.text),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: c.textMuted,
                  ),
                  hintText: 'Search connections',
                  hintStyle: ShiftType.bodySm(c.textMuted),
                ),
                onChanged: (String value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: Space.x3),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing matches “$_query”.',
                        style: ShiftType.body(c.textMuted),
                      ),
                    )
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(
                        Space.x5,
                        0,
                        Space.x5,
                        Space.x6,
                      ),
                      itemCount: matches.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: Space.x3),
                      itemBuilder: (BuildContext context, int i) =>
                          _ConnectorRow(matches[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ConnectorRow extends StatelessWidget {
  const _ConnectorRow(this.connector);

  final Connector connector;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x3,
        vertical: Space.x3,
      ),
      decoration: BoxDecoration(
        borderRadius: Radii.mdAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: Radii.smAll,
            ),
            child: Text(
              connector.initials,
              style: ShiftType.mono(c.textMuted, size: 12),
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Text(
              connector.name,
              style: ShiftType.bodyStrong(c.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (connector.live) ...<Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: c.success,
                borderRadius: Radii.pillAll,
              ),
            ),
            const SizedBox(width: Space.x2),
            Text('Live', style: ShiftType.caption(c.success)),
          ] else
            Text('Not connected', style: ShiftType.caption(c.textMuted)),
        ],
      ),
    );
  }
}

/// Your avatar: a photo of you, framed. Pick a picture, drag it to place
/// and zoom until it sits right in the circle, then save. The photo is kept
/// with the framing, so it can be re-framed later without picking again.
class _AvatarCard extends StatefulWidget {
  const _AvatarCard();

  @override
  State<_AvatarCard> createState() => _AvatarCardState();
}

class _AvatarCardState extends State<_AvatarCard> {
  static const double _preview = 200;

  AvatarPhoto? _draft;
  AvatarPhoto? _saved;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _saved = AppScope.read(context).avatar;
    _draft = _saved;
  }

  bool get _dirty {
    final AvatarPhoto? draft = _draft;
    if (draft == null) return false;
    final AvatarPhoto? saved = _saved;
    if (saved == null) return true;
    return !identical(saved.bytes, draft.bytes) ||
        saved.zoom != draft.zoom ||
        saved.offsetX != draft.offsetX ||
        saved.offsetY != draft.offsetY;
  }

  Future<void> _choosePhoto() async {
    setState(() => _loading = true);
    final PickedFile? picked = await pickOneImage();
    if (!mounted) return;
    if (picked == null) {
      setState(() => _loading = false);
      return;
    }

    final Uint8List? bytes = await prepareAvatarBytes(picked.bytes);
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not read ${picked.name} as a picture.'),
        ),
      );
      return;
    }

    // A new picture starts centred and unzoomed; the framing you had for
    // the last one would mean nothing here.
    setState(() {
      _loading = false;
      _draft = AvatarPhoto(bytes: bytes);
    });
  }

  /// Dragging moves the picture inside the circle. The offsets are kept as
  /// a fraction of the diameter so the same framing holds at any size.
  void _drag(DragUpdateDetails details) {
    final AvatarPhoto? draft = _draft;
    if (draft == null) return;
    // Past this the picture would pull away from the edge of the circle.
    final double limit = math.max(0, (draft.zoom - 1) / 2);
    setState(() {
      _draft = draft.copyWith(
        offsetX:
            (draft.offsetX + details.delta.dx / _preview).clamp(-limit, limit),
        offsetY:
            (draft.offsetY + details.delta.dy / _preview).clamp(-limit, limit),
      );
    });
  }

  void _setZoom(double value) {
    final AvatarPhoto? draft = _draft;
    if (draft == null) return;
    final double limit = math.max(0, (value - 1) / 2);
    setState(() {
      _draft = draft.copyWith(
        zoom: value,
        offsetX: draft.offsetX.clamp(-limit, limit),
        offsetY: draft.offsetY.clamp(-limit, limit),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final AvatarPhoto? draft = _draft;

    final Widget frame = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onPanUpdate: draft == null ? null : _drag,
          child: Container(
            width: _preview,
            height: _preview,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surfaceRaised,
              border: Border.all(color: draft == null ? c.border : c.accent),
            ),
            child: _loading
                ? Center(
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                      ),
                    ),
                  )
                : draft == null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.person_outline_rounded,
                              size: 34,
                              color: c.textMuted,
                            ),
                            const SizedBox(height: Space.x2),
                            Text(
                              'No photo yet',
                              style: ShiftType.bodySm(c.textMuted),
                            ),
                          ],
                        ),
                      )
                    : AvatarFrame(photo: draft, diameter: _preview),
          ),
        ),
        const SizedBox(height: Space.x3),
        Text(
          draft == null ? 'INITIALS' : 'DRAG TO PLACE',
          style: ShiftType.labelSm(c.textMuted),
        ),
      ],
    );

    final Widget controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: _loading ? null : _choosePhoto,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text(draft == null ? 'Choose a photo' : 'Replace photo'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: c.text,
          ),
        ),
        const SizedBox(height: Space.x5),
        const Eyebrow('Zoom'),
        Row(
          children: <Widget>[
            Icon(Icons.image_outlined, size: 16, color: c.textMuted),
            Expanded(
              child: Slider(
                value: draft?.zoom ?? 1,
                min: 1,
                max: 3,
                onChanged: draft == null ? null : _setZoom,
              ),
            ),
            Icon(Icons.zoom_in_rounded, size: 20, color: c.textMuted),
          ],
        ),
        const SizedBox(height: Space.x2),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: draft == null
                ? null
                : () => setState(
                      () => _draft = AvatarPhoto(bytes: draft.bytes),
                    ),
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Recentre'),
            style: TextButton.styleFrom(foregroundColor: c.accent),
          ),
        ),
      ],
    );

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Eyebrow('Your avatar'),
          const SizedBox(height: Space.x4),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(child: frame),
                    const SizedBox(height: Space.x5),
                    controls,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: _preview, child: frame),
                  const SizedBox(width: Space.x6),
                  Expanded(child: controls),
                ],
              );
            },
          ),
          const SizedBox(height: Space.x5),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      _dirty ? () => setState(() => _draft = _saved) : null,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: FilledButton(
                  onPressed: draft == null || !_dirty
                      ? null
                      : () {
                          state.setAvatar(draft);
                          setState(() => _saved = draft);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Avatar saved')),
                          );
                        },
                  child: const Text('USE THIS'),
                ),
              ),
            ],
          ),
          if (_saved != null) ...<Widget>[
            const SizedBox(height: Space.x3),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  state.setAvatar(null);
                  setState(() {
                    _saved = null;
                    _draft = null;
                  });
                },
                style: TextButton.styleFrom(foregroundColor: c.danger),
                child: const Text('Remove photo'),
              ),
            ),
          ],
          const SizedBox(height: Space.x2),
          Text(
            'The photo stays on this device — it is saved with the rest of '
            'your settings and never uploaded. It shows in the sidebar and '
            'on your account.',
            style: ShiftType.caption(c.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Where the app gets its data. Empty means the built-in catalogue, which
/// is what a build with no server runs on. Debug builds only.
class _EngineCard extends StatefulWidget {
  const _EngineCard();

  @override
  State<_EngineCard> createState() => _EngineCardState();
}

class _EngineCardState extends State<_EngineCard> {
  late final TextEditingController _url =
      TextEditingController(text: AppScope.read(context).backendBaseUrl ?? '');

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final bool live = (state.backendBaseUrl ?? '').isNotEmpty;

    return ShiftCard(
      borderColor: c.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child: Eyebrow('Engine · ${live ? 'live' : 'built in'}')),
              if (state.refreshing)
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.x3),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: ShiftType.bodySm(c.text),
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.shiftai.club',
            ),
          ),
          if (state.lastError != null) ...<Widget>[
            const SizedBox(height: Space.x3),
            Text(
              '${state.lastError!.kind.name}: ${state.lastError!.message}',
              style: ShiftType.bodySm(c.danger),
            ),
          ],
          const SizedBox(height: Space.x4),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: state.refreshing ? null : state.refresh,
                  child: const Text('Refresh'),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    state.setBackendBaseUrl(_url.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Saved. Restart to pick up the change.'),
                      ),
                    );
                  },
                  child: const Text('SAVE'),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x3),
          Text(
            'The repository is chosen when the app starts, so a new URL '
            'takes effect on the next launch. Debug builds only — this card '
            'is not compiled into a release.',
            style: ShiftType.caption(c.textMuted),
          ),
        ],
      ),
    );
  }
}
