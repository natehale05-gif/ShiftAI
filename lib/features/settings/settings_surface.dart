import 'package:flutter/cupertino.dart' show CupertinoSwitch;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/modes.dart';
import '../../app/shell.dart';
import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/file_pick.dart';
import '../../widgets/common.dart';
import 'account_card.dart';
import 'avatar.dart';
import 'connectors.dart';

/// The avatar maker and the account first, then appearance, sections and
/// connections — who you are before how the app looks and behaves.
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
                // Who you are comes first: the account itself — name,
                // email, username — and then the avatars you show up as.
                // Everything below is how the app looks and behaves, not
                // who is using it.
                AccountCard(),
                SizedBox(height: Space.x4),
                _AvatarsCard(),
                SizedBox(height: Space.x4),
                _AppearanceCard(),
                SizedBox(height: Space.x4),
                _FeaturesCard(),
                SizedBox(height: Space.x4),
                _ConnectionsCard(),
                // Only in a debug build: pointing the app at an engine is
                // a developer's job, not something to ship to a creator.
                if (kDebugMode) ...<Widget>[
                  SizedBox(height: Space.x4),
                  _EngineCard(),
                ],
                // The one action on this screen that cannot be undone is
                // the last thing on it, full stop — never near a button
                // someone might actually mean to tap.
                SizedBox(height: Space.x4),
                DeleteAccountCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One row of colour swatches, one label for whichever is picked — the
/// grid of four bordered, captioned cards this replaced said the same
/// thing with a lot more to look at.
class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Eyebrow('Appearance'),
          const SizedBox(height: Space.x3),
          _SwitchRow(
            title: 'Match system',
            subtitle: state.themeId.isRetro
                ? 'Retro light by day, Retro neon by night, with your phone.'
                : 'Light by day, Dark by night, with your phone.',
            value: state.followSystem,
            onChanged: state.setFollowSystem,
          ),
          const SizedBox(height: Space.x4),
          // Picking one by hand turns Match system off: a swatch is an
          // override, and the check marks what is showing either way.
          Wrap(
            spacing: Space.x3,
            runSpacing: Space.x3,
            children: <Widget>[
              for (final ShiftThemeId id in ShiftThemeId.values)
                _ThemeSwatch(
                  id: id,
                  selected: state.activeTheme == id,
                  onTap: () => state.setTheme(id),
                ),
            ],
          ),
          const SizedBox(height: Space.x3),
          Text(
            state.followSystem
                ? '${state.activeTheme.label} · matching your phone'
                : state.activeTheme.label,
            style: ShiftType.bodyStrong(c.text),
          ),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
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
      label: id.label,
      child: InkWell(
        borderRadius: Radii.pillAll,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: preview.bg,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? c.accent : preview.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded, size: 18, color: preview.accent)
              : Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: preview.accent,
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }
}

/// A setting that is on or off: a title, a line under it, and the iOS
/// switch in the theme's accent.
///
/// The whole row is the control, as it is in Settings on an iPhone. The
/// switch alone is 59 by 39, under the 44-point minimum, and on its own
/// it was announced as a toggle with no name. Merged, the row reads as
/// one labelled switch and takes the tap anywhere along it.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: Radii.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.x1),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: ShiftType.bodyStrong(c.text)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: ShiftType.caption(c.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.x3),
                // Material's switch has an outlined off state and an inset
                // thumb, and on a phone it looked borrowed.
                CupertinoSwitch(
                  value: value,
                  activeTrackColor: c.accent,
                  inactiveTrackColor: c.surfaceRaised,
                  onChanged: onChanged,
                ),
              ],
            ),
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
            _SwitchRow(
              title: feature.label,
              subtitle: feature.description,
              value: state.isEnabled(feature),
              onChanged: (bool on) => state.setFeatureEnabled(feature, on),
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
              // One column is a grouped list, hairlines inset to the names;
              // three are filled tiles, which a hairline cannot separate.
              if (columns == 1) {
                return Column(
                  children: <Widget>[
                    for (int i = 0; i < live.length; i++) ...<Widget>[
                      if (i > 0) const _ConnectorDivider(),
                      _ConnectorRow(live[i]),
                    ],
                  ],
                );
              }
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
                    _ConnectorRow(live[i], tile: true),
              );
            },
          ),
          const SizedBox(height: Space.x3),
          Text(
            live.isEmpty
                ? 'Nothing connected yet. Browse all to see what ShiftAi can '
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
                    style: ShiftType.caption(c.textMuted),
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
                      separatorBuilder: (_, __) => const _ConnectorDivider(),
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
  const _ConnectorRow(this.connector, {this.tile = false});

  final Connector connector;

  /// Filled, for the wide grid. Otherwise a bare row in a grouped list.
  final bool tile;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tile ? Space.x3 : 0,
        vertical: Space.x3,
      ),
      decoration: tile
          ? BoxDecoration(color: c.surfaceRaised, borderRadius: Radii.mdAll)
          : null,
      child: Row(
        children: <Widget>[
          Container(
            width: _connectorMark,
            height: _connectorMark,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tile ? c.surface : c.surfaceRaised,
              borderRadius: Radii.smAll,
            ),
            child: Text(
              connector.initials,
              style: ShiftType.copy(c.textMuted, size: 12, weight: 700),
            ),
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Text(
              connector.name,
              style: ShiftType.copy(c.text, size: 16, weight: 500),
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

const double _connectorMark = 34;

/// A hairline between connector rows, starting where the names do.
class _ConnectorDivider extends StatelessWidget {
  const _ConnectorDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: _connectorMark + Space.x3),
      child: Divider(
        height: 1,
        thickness: 0.5,
        color: ShiftColors.of(context).border,
      ),
    );
  }
}

/// Your avatar: a photo of you, framed. Pick a picture, drag it to place
/// and zoom until it sits right in the circle, then save. The photo is kept
/// with the framing, so it can be re-framed later without picking again.
/// The gallery: every avatar this creator has trained, the personal one
/// picked out, and a way to start a new one.
class _AvatarsCard extends StatefulWidget {
  const _AvatarsCard();

  @override
  State<_AvatarsCard> createState() => _AvatarsCardState();
}

class _AvatarsCardState extends State<_AvatarsCard> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final List<Avatar> avatars = state.avatars;

    return ShiftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Eyebrow('Your avatars'),
          const SizedBox(height: Space.x2),
          Text(
            'An animated likeness you can use as your profile picture, on '
            'the leaderboard, and to generate with in the Suite.',
            style: ShiftType.caption(c.textMuted),
          ),
          const SizedBox(height: Space.x4),
          if (avatars.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: Space.x5),
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                borderRadius: Radii.mdAll,
              ),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.person_outline_rounded,
                    size: 28,
                    color: c.textMuted,
                  ),
                  const SizedBox(height: Space.x2),
                  Text('No avatars yet', style: ShiftType.bodySm(c.textMuted)),
                ],
              ),
            )
          else
            Wrap(
              spacing: Space.x3,
              runSpacing: Space.x3,
              children:
                  avatars.map((Avatar a) => _AvatarTile(avatar: a)).toList(),
            ),
          const SizedBox(height: Space.x4),
          if (_creating)
            _CreateAvatarFlow(onDone: () => setState(() => _creating = false))
          else
            OutlinedButton.icon(
              onPressed: () => setState(() => _creating = true),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create an avatar'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: c.text,
              ),
            ),
        ],
      ),
    );
  }
}

/// An avatar's face in its gallery card.
///
/// Only a preview the server has sent is a picture. Before, anything that
/// was not a ready avatar with a URL got a spinner, so a ready avatar whose
/// preview had not arrived, like the demo's "Everyday", spun forever and
/// read as broken. Now a face with no picture is a portrait in its own
/// colours, seeded by the avatar like a vault poster. Training dims it and
/// marks it with an hourglass rather than a spinner that never finishes.
class _AvatarFace extends StatelessWidget {
  const _AvatarFace({required this.avatar});

  final Avatar avatar;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final String? url = avatar.previewUrl;

    final Widget portrait = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PosterArt(seed: avatar.id),
        Icon(
          Icons.person_rounded,
          size: _size * 0.62,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ],
    );

    final Widget face = switch (avatar.status) {
      AvatarStatus.failed => ColoredBox(
          color: c.surface,
          child: Icon(Icons.error_outline_rounded, color: c.danger),
        ),
      AvatarStatus.ready when url != null && url.isNotEmpty => Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object _, StackTrace? __) =>
              portrait,
        ),
      AvatarStatus.ready => portrait,
      AvatarStatus.training => Opacity(opacity: 0.45, child: portrait),
    };

    return Semantics(
      label: '${avatar.name}, ${avatar.status.name}',
      image: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: _size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(child: ClipOval(child: face)),
            if (avatar.status == AvatarStatus.training)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 14,
                    color: c.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarTile extends StatelessWidget {
  const _AvatarTile({required this.avatar});

  final Avatar avatar;

  Future<void> _makePersonal(BuildContext context) async {
    final AppState state = AppScope.read(context);
    final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
    if (!await state.makeAvatarPersonal(avatar.id)) {
      bar.showSnackBar(
        SnackBar(
          content:
              Text(state.lastError?.message ?? 'Could not make it personal.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    return Container(
      width: 148,
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: Radii.mdAll,
        border: avatar.personal ? Border.all(color: c.accent) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(child: _AvatarFace(avatar: avatar)),
          const SizedBox(height: Space.x2),
          Text(
            avatar.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: ShiftType.copy(c.text, size: 15, weight: 600),
          ),
          const SizedBox(height: 2),
          Text(
            avatar.personal
                ? 'Personal'
                : switch (avatar.status) {
                    AvatarStatus.training => 'Training…',
                    AvatarStatus.failed => 'Failed',
                    AvatarStatus.ready => 'Ready',
                  },
            textAlign: TextAlign.center,
            style: ShiftType.caption(avatar.personal ? c.accent : c.textMuted),
          ),
          const SizedBox(height: Space.x2),
          if (!avatar.personal && avatar.ready)
            Center(
              child: TextButton(
                onPressed: () => _makePersonal(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child:
                    Text('Make personal', style: ShiftType.caption(c.accent)),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Delete',
              onPressed: () => _confirmDeleteAvatar(context, avatar),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: c.textMuted.withValues(alpha: 0.7),
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteAvatar(BuildContext context, Avatar avatar) async {
  final AppState state = AppScope.read(context);
  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      final ShiftColors c = ShiftColors.of(context);
      return AlertDialog(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.lgAll),
        title: Text('Delete this avatar?', style: ShiftType.subheading(c.text)),
        content: Text(
          avatar.personal
              ? '"${avatar.name}" goes for good, and your profile picture '
                  'and leaderboard face fall back to initials.'
              : '"${avatar.name}" goes for good.',
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
  if (!await state.deleteAvatar(avatar.id)) {
    bar.showSnackBar(
      SnackBar(
          content: Text(state.lastError?.message ?? 'Could not delete it.')),
    );
  }
}

/// Choose a photo or clip, name it, and hand it to the engine to train.
/// There is nothing to preview here beyond the picture itself — the
/// training happens server-side, so nothing this dialog could show would
/// be the real thing.
class _CreateAvatarFlow extends StatefulWidget {
  const _CreateAvatarFlow({required this.onDone});

  final VoidCallback onDone;

  @override
  State<_CreateAvatarFlow> createState() => _CreateAvatarFlowState();
}

class _CreateAvatarFlowState extends State<_CreateAvatarFlow> {
  final TextEditingController _name = TextEditingController();
  Uint8List? _bytes;
  String _fileName = 'avatar.png';
  bool _picking = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    setState(() => _picking = true);
    final PickedFile? picked = await pickOneImage();
    if (!mounted) return;
    if (picked == null) {
      setState(() => _picking = false);
      return;
    }

    final Uint8List? bytes = await prepareAvatarBytes(picked.bytes);
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _picking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not read ${picked.name} as a picture.'),
        ),
      );
      return;
    }

    setState(() {
      _picking = false;
      _bytes = bytes;
      _fileName = picked.name;
    });
  }

  Future<void> _create() async {
    final Uint8List? bytes = _bytes;
    if (bytes == null) return;
    final AppState state = AppScope.read(context);
    setState(() => _saving = true);
    final Avatar? created = await state.createAvatar(
      bytes,
      name: _name.text.trim().isEmpty ? 'Avatar' : _name.text.trim(),
      fileName: _fileName,
    );
    if (!mounted) return;
    if (created == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(state.lastError?.message ?? 'Could not create the avatar.'),
        ),
      );
      return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final Uint8List? bytes = _bytes;

    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration:
          BoxDecoration(color: c.surfaceRaised, borderRadius: Radii.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surface,
                  border: Border.all(color: c.border),
                ),
                child: _picking
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                        ),
                      )
                    : bytes == null
                        ? Icon(Icons.person_outline_rounded, color: c.textMuted)
                        : Image.memory(bytes,
                            fit: BoxFit.cover, width: 56, height: 56),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: OutlinedButton(
                  onPressed: _picking ? null : _choosePhoto,
                  child: Text(
                    bytes == null ? 'Choose a photo or clip' : 'Replace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.x4),
          TextField(
            controller: _name,
            style: ShiftType.bodySm(c.text),
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: Space.x2),
          Text(
            'HeyGen trains from this — it takes a few minutes, and you can '
            'keep working while it does.',
            style: ShiftType.caption(c.textMuted),
          ),
          const SizedBox(height: Space.x4),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : widget.onDone,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: FilledButton(
                  onPressed: bytes == null || _saving ? null : _create,
                  child: _saving
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ShiftColors.of(context).onAccent,
                            ),
                          ),
                        )
                      : const Text('Create'),
                ),
              ),
            ],
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
                  child: const Text('Save'),
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
