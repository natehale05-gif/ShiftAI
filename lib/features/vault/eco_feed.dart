import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../theme/type.dart';
import '../../util/format.dart';
import '../../util/haptics.dart';
import '../../widgets/common.dart';
import 'media_player.dart';

/// EcoVault as a feed, the way Instagram shows one: one post at a time,
/// full width, who made it above, the heart and the prompt below.
///
/// It was the same masonry grid as your own vault, which is a way to find
/// your own things again. Other people's work is something to scroll
/// through, so it reads as posts instead.
class EcoFeed extends StatelessWidget {
  const EcoFeed({required this.items, super.key});

  final List<VaultItem> items;

  /// Instagram's own column on a wide screen; a phone is edge to edge.
  static const double maxWidth = 470;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: PullToRefresh(
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: Space.x2, bottom: Space.x6),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxWidth),
              child: FeedPost(
                key: ValueKey<String>('post-${items[index].id}'),
                item: items[index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One post: the maker, the piece, the heart, the caption, when.
class FeedPost extends StatefulWidget {
  const FeedPost({required this.item, super.key});

  final VaultItem item;

  /// Instagram's limits: nothing taller than 4:5 or wider than 1.91:1, so
  /// a 9:16 clip does not take a whole screen to scroll past.
  static double frameOf(VaultItem item) => item.aspect.clamp(0.8, 1.91);

  @override
  State<FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends State<FeedPost>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  /// The big heart that blooms over the piece on a double tap.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  VaultItem get item => widget.item;

  /// Double tap hearts, as on Instagram. It only ever adds one: a second
  /// double tap on a hearted post leaves it hearted.
  void _doubleTap(AppState state) {
    _burst.forward(from: 0);
    if (item.saved) {
      Haptics.light();
      return;
    }
    toggleHeart(context, state, item);
  }

  void _more(AppState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheet) {
        final ShiftColors c = ShiftColors.of(sheet);
        Widget row(IconData icon, String label, VoidCallback onTap) => InkWell(
              onTap: () {
                Navigator.of(sheet).pop();
                onTap();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                  child: Row(
                    children: <Widget>[
                      Icon(icon, size: 20, color: c.accent),
                      const SizedBox(width: Space.x3),
                      Text(label, style: ShiftType.copy(c.text, size: 16)),
                    ],
                  ),
                ),
              ),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.x5,
              0,
              Space.x5,
              Space.x5,
            ),
            child: GroupedList(
              children: <Widget>[
                row(Icons.replay_rounded, 'Use this prompt', _usePrompt),
                row(Icons.content_copy_rounded, 'Copy prompt', () {
                  Clipboard.setData(ClipboardData(text: item.prompt));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Prompt copied')),
                  );
                }),
                row(
                  Icons.info_outline_rounded,
                  'Details',
                  () => state.selectVaultItem(item.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The feed's remix: the prompt goes back in the Suite bar, to change
  /// and send as your own.
  void _usePrompt() {
    AppScope.read(context).reusePrompt(item.prompt);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('That prompt is in the Suite bar.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final String handle = item.byHandle ?? '';
    final String name = item.byName ?? handle;
    final int? hearts = item.hearts;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Who made it, and with what: Instagram's name and place line.
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.x3, 0, 0, Space.x2),
            child: Row(
              children: <Widget>[
                CreatorFace(name: name, url: item.byAvatarUrl, size: 32),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        handle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShiftType.copy(c.text, size: 14, weight: 600),
                      ),
                      if (item.model.isNotEmpty)
                        Text(
                          item.model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ShiftType.copy(c.textMuted, size: 12),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'More',
                  onPressed: () => _more(state),
                  icon: Icon(Icons.more_horiz_rounded, color: c.text),
                ),
              ],
            ),
          ),
          Semantics(
            label: '${item.title}, ${item.mediaType.label}, by $name. '
                'Double tap to save.',
            child: GestureDetector(
              onDoubleTap: () => _doubleTap(state),
              child: AspectRatio(
                aspectRatio: FeedPost.frameOf(item),
                // Clipped: the drawn art glows past its box, and in a feed
                // that washed over the name above and the caption below.
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      ColoredBox(
                        color: c.surface,
                        child: VaultMedia(item: item),
                      ),
                      if (item.mediaType == MediaType.video)
                        Positioned(
                          top: Space.x3,
                          right: Space.x3,
                          child: IgnorePointer(
                            child: _Length(seconds: item.durationSeconds),
                          ),
                        ),
                      IgnorePointer(child: _Burst(animation: _burst)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The heart and the remix, left; nothing on the right, as there
          // is no separate bookmark: the heart is the save.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x1),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip:
                      item.saved ? 'Saved to your vault' : 'Save to your vault',
                  onPressed: () => toggleHeart(context, state, item),
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (Widget child, Animation<double> a) =>
                        ScaleTransition(scale: a, child: child),
                    child: Icon(
                      item.saved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey<bool>(item.saved),
                      size: 26,
                      color: item.saved ? c.accent : c.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Use this prompt',
                  onPressed: _usePrompt,
                  icon: Icon(Icons.replay_rounded, size: 26, color: c.text),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (hearts != null && hearts > 0) ...<Widget>[
                  Text(
                    hearts == 1 ? '1 heart' : '${Fmt.grouped(hearts)} hearts',
                    style: ShiftType.copy(c.text, size: 14, weight: 600),
                  ),
                  const SizedBox(height: Space.x1),
                ],
                // The title is the caption, after the handle.
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: '$handle ',
                        style: ShiftType.copy(c.text, size: 14, weight: 600),
                      ),
                      TextSpan(
                        text: item.title,
                        style: ShiftType.copy(c.text, size: 14),
                      ),
                    ],
                  ),
                ),
                // The prompt is what people come to EcoVault for, folded
                // to two lines until asked for, like a long caption.
                if (item.prompt.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      item.prompt,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: ShiftType.copy(
                        c.textMuted,
                        size: 14,
                        lineHeight: 20,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: Space.x1),
                Text(
                  Fmt.ago(item.createdAt),
                  style: ShiftType.copy(c.textMuted, size: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A video's mark in the corner, with its length when the engine says.
class _Length extends StatelessWidget {
  const _Length({required this.seconds});

  final int? seconds;

  @override
  Widget build(BuildContext context) {
    final int? d = seconds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: MediaInk.scrim.withValues(alpha: 0.45),
        borderRadius: Radii.smAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.play_arrow_rounded,
            size: 14,
            color: MediaInk.onMedia,
          ),
          if (d != null) ...<Widget>[
            const SizedBox(width: 2),
            Text(
              '${d ~/ 60}:${(d % 60).toString().padLeft(2, '0')}',
              style: ShiftType.figures(MediaInk.onMedia, size: 12, weight: 600),
            ),
          ],
        ],
      ),
    );
  }
}

/// The heart that blooms in the middle of a post and fades.
class _Burst extends StatelessWidget {
  const _Burst({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double t = animation.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        // Up past full size and back in the first third, then fade out.
        final double scale =
            t < 0.3 ? Curves.easeOutBack.transform(t / 0.3) : 1;
        final double opacity = t < 0.6 ? 1 : 1 - (t - 0.6) / 0.4;
        return Center(
          child: Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Icon(
        Icons.favorite_rounded,
        size: 96,
        color: MediaInk.onMedia,
        shadows: <Shadow>[
          Shadow(
            color: ShiftShadow.color.withValues(alpha: 0.35),
            blurRadius: 18,
          ),
        ],
      ),
    );
  }
}

/// A maker's face: their picture, or their initials in a circle.
class CreatorFace extends StatelessWidget {
  const CreatorFace({
    required this.name,
    required this.url,
    required this.size,
    super.key,
  });

  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final Widget initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      child: Text(
        initialsOf(name),
        style: ShiftType.copy(c.textMuted, size: 12, weight: 600),
      ),
    );
    final String? picture = url;
    if (picture == null) return ExcludeSemantics(child: initials);
    return ExcludeSemantics(
      child: ClipOval(
        child: Image.network(
          picture,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (BuildContext context, Object _, StackTrace? __) =>
              initials,
        ),
      ),
    );
  }
}
