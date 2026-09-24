import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../theme/type.dart';
import '../util/file_pick.dart';
import '../util/haptics.dart';
import 'spinner.dart';

/// The lockup's artwork, inked in whichever theme is showing.
///
/// One file, one substitution. The wordmark and the "ai" take the theme's
/// own `text`, and the badge keeps the brand's neon gradient — that
/// magenta-to-blue is the mark, not a colour a theme gets to choose. The
/// tube's hot core is inked with everything else, so on a light ground it
/// reads as a drawn outline inside the bloom rather than disappearing.
///
/// A theme added later is carried with no new artwork, which is why there
/// is no on-light copy of the file any more.
abstract final class ShiftLockup {
  /// The ink in the artwork, standing in for the live theme's `text`.
  static const String _artInk = '#F2F5FA';

  static const String asset = 'assets/brand/shift-ai-lockup.svg';

  /// Width over height of the artwork, glow included. Read off the
  /// viewBox; the lockup is drawn to this and never to a guess.
  static const double ratio = 408.83 / 104.46;

  static String? _template;

  /// Read once, before the first frame. Without it [ShiftLogo] falls back
  /// to the artwork's own ink, so a missed preload is a slightly wrong
  /// colour rather than a missing logo.
  static Future<void> preload() async {
    if (_template != null) return;
    final String svg = await rootBundle.loadString(asset);
    // If the artwork is redrawn with a different ink the swap below would
    // quietly do nothing and the lockup would stick on this one value.
    // Better to fall back to the file and say so in debug.
    final bool recognised = svg.contains(_artInk);
    assert(
      recognised,
      'The lockup no longer contains $_artInk. Update ShiftLockup, or it '
      'will draw the wrong colour.',
    );
    if (recognised) _template = svg;
  }

  static String _hex(Color c) {
    String channel(double v) =>
        (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${channel(c.r)}${channel(c.g)}${channel(c.b)}'.toUpperCase();
  }

  /// The artwork inked in [ink], or null when [preload] has not run.
  static String? forInk(Color ink) => _template?.replaceAll(_artInk, _hex(ink));
}

/// The lockup, from the brand file. Never set by hand; inked only to the
/// theme's own tokens, never to a colour chosen here.
class ShiftLogo extends StatelessWidget {
  const ShiftLogo({this.height = 22, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final double width = height * ShiftLockup.ratio;
    final String? themed = ShiftLockup.forInk(c.text);

    return Semantics(
      label: 'ShiftAi',
      child: themed != null
          ? SvgPicture.string(themed, width: width, height: height)
          : SvgPicture.asset(ShiftLockup.asset, width: width, height: height),
    );
  }
}

/// The private-chat mark. Material has no ghost, and an eye with a line
/// through it reads as "hidden from you" rather than "not kept".
class GhostMark extends StatelessWidget {
  const GhostMark({required this.color, this.size = 22, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GhostPainter(color)),
    );
  }
}

class _GhostPainter extends CustomPainter {
  _GhostPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 * s
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final Path body = Path()
      ..moveTo(4 * s, 20.6 * s)
      ..lineTo(4 * s, 11 * s)
      ..arcToPoint(
        Offset(20 * s, 11 * s),
        radius: Radius.circular(8 * s),
        clockwise: true,
      )
      ..lineTo(20 * s, 20.6 * s)
      ..lineTo(17.2 * s, 18.3 * s)
      ..lineTo(14.4 * s, 20.6 * s)
      ..lineTo(11.6 * s, 18.3 * s)
      ..lineTo(8.8 * s, 20.6 * s)
      ..close();
    canvas.drawPath(body, stroke);

    final Paint eye = Paint()..color = color;
    canvas.drawCircle(Offset(9.6 * s, 11.4 * s), 1.25 * s, eye);
    canvas.drawCircle(Offset(14.4 * s, 11.4 * s), 1.25 * s, eye);
  }

  @override
  bool shouldRepaint(_GhostPainter old) => old.color != color;
}

/// A short muted line above a block, in sentence case.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    // Set as written. Every caller already passes sentence case —
    // "Appearance", "Your avatars", "Prompt" — and this used to shout it
    // into tracked mono capitals on the way to the screen.
    return Text(
      text,
      style: ShiftType.copy(color ?? c.textMuted, size: 13, weight: 600),
    );
  }
}

/// A panel on `surface`, separated by a line rather than a shadow.
class ShiftCard extends StatelessWidget {
  const ShiftCard({
    required this.child,
    this.padding = const EdgeInsets.all(Space.x5),
    this.borderColor,
    this.background,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    // Filled, not outlined. On a dark ground the card's own fill is the
    // edge. On a light one the card is white on a near-white page, so it
    // keeps a hairline — half the 1px outline every card used to wear.
    final Color? edge = borderColor ?? (c.isDarkGround ? null : c.border);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? c.surface,
        borderRadius: Radii.lgAll,
        border: edge == null
            ? null
            : Border.all(
                color: edge,
                width: borderColor == null ? 0.5 : 1,
              ),
      ),
      child: child,
    );
  }
}

/// The two-way scope toggle the vault uses.
/// A segmented control: a recessed track, and a raised thumb that slides
/// to whichever segment is chosen.
///
/// It was a pill of uppercase mono tabs with the chosen one flooded in the
/// accent — loud for something whose whole job is to be a quiet switch,
/// and a second, different control lived in the leaderboard beside it.
/// Segments are equal widths so the thumb can slide rather than jump, as
/// wide as the widest label when [expand] is off.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    super.key,
  });

  final List<T> options;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final int n = options.length;
    final int at = options.indexOf(selected).clamp(0, n - 1);
    // On a dark ground the thumb is a step lighter than its track; on a
    // light one it is the card white, lifted by a shadow.
    final Color thumb =
        c.isDarkGround ? Color.lerp(c.surfaceRaised, c.text, 0.14)! : c.surface;

    final Widget control = Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: Radii.mdAll,
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * at / (n - 1), 0),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: thumb,
                    borderRadius: BorderRadius.circular(Radii.md.x - 2),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: ShiftShadow.color.withValues(
                          alpha: c.isDarkGround ? 0.35 : 0.12,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: options.map((T option) {
              final bool on = option == selected;
              return Expanded(
                child: Semantics(
                  selected: on,
                  button: true,
                  label: labelOf(option),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (option != selected) Haptics.selection();
                      onChanged(option);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.x4,
                      ),
                      child: Center(
                        child: Text(
                          labelOf(option),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ShiftType.copy(
                            on ? c.text : c.textMuted,
                            size: 14,
                            weight: on ? 600 : 500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

    // Off, the control is as wide as its widest label times the count:
    // equal Expanded children report exactly that as their intrinsic width.
    return expand ? control : IntrinsicWidth(child: control);
  }
}

/// A placeholder for media that has no bytes on device. Better an honest
/// labelled block than a bad guess at the real thing.
/// A piece's artwork, and only its artwork.
///
/// The title used to be set over the art on a scrim, with an uppercase
/// type chip in the corner and a play disc in the middle — three layers of
/// chrome on every tile. The media grids people already know put the title
/// under the picture and mark a video with its running time alone, in the
/// corner; the caption lives in the tile beneath this now.
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    required this.seed,
    this.video = false,
    this.durationSeconds,
    this.selected = false,
    this.thumbnailUrl,
    this.mediaType = MediaType.image,
    super.key,
  });

  /// The engine's small preview, when it has one. Without it, or while it
  /// loads, or if it fails, the tile is the seeded art, so a slow network
  /// never shows an empty box.
  final String? thumbnailUrl;

  /// Audio and documents have no picture of their own; they get a symbol
  /// on the art saying which they are.
  final MediaType mediaType;

  /// What the art is drawn from — the piece's id, so it looks the same in
  /// the grid and in its detail panel.
  final String seed;
  final bool video;
  final int? durationSeconds;
  final bool selected;

  static String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final int? d = durationSeconds;

    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: Radii.lgAll,
        border: Border.all(
          color: selected ? c.accent : MediaInk.onMedia.withValues(alpha: 0.06),
          width: selected ? 2.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: Radii.lgAll,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            MediaArt(seed: seed, thumbnailUrl: thumbnailUrl),
            if (thumbnailUrl == null &&
                (mediaType == MediaType.audio ||
                    mediaType == MediaType.document))
              Center(child: _KindMark(mediaType)),
            if (video)
              Positioned(
                right: Space.x2,
                bottom: Space.x2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MediaInk.scrim.withValues(alpha: 0.45),
                    borderRadius: Radii.smAll,
                  ),
                  child: d == null
                      ? const Icon(
                          Icons.play_arrow_rounded,
                          size: 14,
                          color: MediaInk.onMedia,
                        )
                      : Text(
                          _clock(d),
                          style: ShiftType.figures(
                            MediaInk.onMedia,
                            size: 12,
                            weight: 600,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A piece's picture: the engine's image when there is one, faded in over
/// its seeded art, which is also what shows while it loads or if it fails.
class MediaArt extends StatelessWidget {
  const MediaArt({
    required this.seed,
    this.thumbnailUrl,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String seed;
  final String? thumbnailUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final String? url = thumbnailUrl;
    if (url == null) return PosterArt(seed: seed);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PosterArt(seed: seed),
        Image.network(
          url,
          fit: fit,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          frameBuilder: (BuildContext context, Widget child, int? frame,
                  bool synchronous) =>
              synchronous
                  ? child
                  : AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 220),
                      child: child,
                    ),
          errorBuilder: (BuildContext context, Object _, StackTrace? __) =>
              const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// The symbol on an audio or document tile, which has no picture.
class _KindMark extends StatelessWidget {
  const _KindMark(this.type);

  final MediaType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: MediaInk.scrim.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: Icon(
        type == MediaType.audio
            ? Icons.graphic_eq_rounded
            : Icons.description_outlined,
        size: 26,
        color: MediaInk.onMedia,
      ),
    );
  }
}

/// Art for a piece with no thumbnail: audio, documents, and anything the
/// engine has not sent a preview for.
///
/// It was an empty dark box, and a masonry grid of those
/// is a wall of identical rectangles that makes the vault look empty when
/// it is not. This draws from the brand's neon sweep and is seeded by the
/// piece, so the vault reads as one gallery and each piece keeps its own
/// look: the same colours in the grid, in its detail panel, and every
/// time the app opens.
class PosterArt extends StatelessWidget {
  const PosterArt({required this.seed, super.key});

  final String seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PosterPainter(_stableHash(seed)),
      child: const SizedBox.expand(),
    );
  }
}

/// The play affordance over a video's poster.
class PlayDisc extends StatelessWidget {
  const PlayDisc({this.size = 44, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MediaInk.scrim.withValues(alpha: 0.35),
        border: Border.all(color: MediaInk.onMedia.withValues(alpha: 0.55)),
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: MediaInk.onMedia,
        size: size * 0.6,
      ),
    );
  }
}

/// String.hashCode is not promised to be stable between runs, and a piece
/// that changed colour on every launch would read as a different piece.
/// Kept inside 30 bits so the multiply stays exact on the web, where an
/// int is a double and anything past 2^53 quietly loses its low bits.
int _stableHash(String s) {
  int h = 17;
  for (final int unit in s.codeUnits) {
    h = (h * 31 + unit) & 0x3FFFFFFF;
  }
  return h;
}

class _PosterPainter extends CustomPainter {
  const _PosterPainter(this.seed);

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final math.Random rnd = math.Random(seed);
    final Rect bounds = Offset.zero & size;

    // Two points on the sweep, far enough apart that the pair has some
    // contrast in it, near enough that it still reads as the brand.
    final double t1 = rnd.nextDouble();
    final double t2 = (t1 + 0.35 + rnd.nextDouble() * 0.3) % 1.0;
    final Color lead = ShiftBrand.neonAt(t1);
    final Color glow = ShiftBrand.neonAt(t2);
    // A night ground tinted toward the lead, dark enough for white type.
    final Color night = Color.lerp(MediaInk.scrim, lead, 0.14)!;

    final double angle = rnd.nextDouble() * math.pi * 2;
    final double dx = math.cos(angle), dy = math.sin(angle);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-dx, -dy),
          end: Alignment(dx, dy),
          colors: <Color>[night, Color.lerp(night, lead, 0.5)!],
        ).createShader(bounds),
    );

    void orb(Color colour, double reach, double strength) {
      final Offset centre = Offset(
        size.width * (0.15 + rnd.nextDouble() * 0.7),
        size.height * (0.1 + rnd.nextDouble() * 0.55),
      );
      final double radius = size.longestSide * reach;
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              colour.withValues(alpha: strength),
              colour.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    orb(glow, 0.55 + rnd.nextDouble() * 0.25, 0.75);
    orb(lead, 0.28 + rnd.nextDouble() * 0.2, 0.55);
  }

  @override
  bool shouldRepaint(_PosterPainter old) => old.seed != seed;
}

/// Says the engine refused, on a screen whose contents come from it. Only
/// shows when there is an error to report, so it can be dropped into a
/// column unconditionally.
class EngineBanner extends StatelessWidget {
  const EngineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftApiException? error = state.lastError;
    if (error == null) return const SizedBox.shrink();
    final ShiftColors c = ShiftColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: Space.x4),
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.mdAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off_rounded, size: 20, color: c.warning),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Text(
              state.showingCached
                  ? '${error.message} Showing what was last loaded on this '
                      'device.'
                  : error.message,
              style: ShiftType.bodySm(c.text),
            ),
          ),
          if (error.retryable) ...<Widget>[
            const SizedBox(width: Space.x3),
            TextButton(
              onPressed: state.refreshing ? null : state.refresh,
              child: Text('Retry', style: ShiftType.bodySm(c.accent)),
            ),
          ],
        ],
      ),
    );
  }
}

/// The heart. Saving a piece in EcoVault is what puts it in your own
/// vault, so this is the one control that appears on a tile rather than
/// behind a tap into the detail.
class HeartButton extends StatelessWidget {
  const HeartButton({required this.item, this.size = 20, super.key});

  final VaultItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ShiftColors c = ShiftColors.of(context);
    final bool on = item.saved;

    // The button's own tooltip, not a Tooltip round it: only the button's
    // reaches VoiceOver and TalkBack, and with the wrapper the heart was
    // announced as an unlabelled button.
    return IconButton(
      tooltip: on ? 'Saved to your vault' : 'Save to your vault',
      onPressed: () => _toggle(context, state),
      iconSize: size,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        backgroundColor: c.bg.withValues(alpha: 0.55),
        shape: const CircleBorder(),
      ),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (Widget child, Animation<double> anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey<bool>(on),
          size: size,
          color: on ? c.accent : c.text,
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, AppState state) =>
      toggleHeart(context, state, item);
}

/// Hearts [item] or takes the heart off, and says so: a refusal with its
/// reason, a save with where it went. The heart button and the feed's
/// heart and double-tap all go through this.
Future<void> toggleHeart(
  BuildContext context,
  AppState state,
  VaultItem item,
) async {
  final bool wasOn = item.saved;
  final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
  Haptics.light();
  final bool took = await state.toggleSaved(item.id);
  if (!took) {
    bar.showSnackBar(
      SnackBar(
        content: Text(
          state.lastError?.message ?? 'Could not save it just now.',
        ),
      ),
    );
    return;
  }
  // Only on the way in: an un-save needs no announcement.
  if (!wasOn) {
    bar.showSnackBar(
      const SnackBar(content: Text('Saved — it is in your vault now.')),
    );
  }
}

/// Every control in the composer is this tall, so the row is level.
const double _controlSize = 44;

/// The inset above and below the controls inside the pill.
const double _pillInset = 6;

/// What the pill measures at rest.
const double _pillHeight = _controlSize + _pillInset * 2;

/// The pill at the bottom of every screen that takes an instruction.
class PillComposer extends StatefulWidget {
  const PillComposer({
    required this.hint,
    this.onSend,
    this.onStop,
    this.showSparkle = false,
    this.showAvatarPicker = false,
    this.width = 950,
    super.key,
  });

  final String hint;

  /// Returns false when the message was refused, and the bar then keeps
  /// what was typed instead of clearing it away. Typing something,
  /// pressing enter and watching it vanish with nothing to show for it is
  /// the same dead end as being refused, in a worse place.
  final bool Function(String)? onSend;

  /// Set while an answer is on its way: the send button becomes Stop,
  /// which gives up on it. Enter still sends, and a new message replaces
  /// the one being waited for.
  final VoidCallback? onStop;

  /// Suite's composer carries the make-something mark; the others do not.
  final bool showSparkle;

  /// Suite only — which avatar the next ask should be generated as. A
  /// button rather than a row of chips sitting above the bar every time:
  /// nothing to look at until it is opened, one popup instead of a strip
  /// that ate space whether or not anyone was choosing anything.
  final bool showAvatarPicker;
  final double width;

  @override
  State<PillComposer> createState() => _PillComposerState();
}

class _PillComposerState extends State<PillComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<PickedFile> _attachments = <PickedFile>[];
  bool _polishing = false;

  /// Vault's "Re-run" hands a prompt back through the store. The Suite
  /// composer picks it up the next time it builds, and taking it clears
  /// it, so coming back to Suite later does not re-fill the bar.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.showSparkle) return;
    final String? draft = AppScope.of(context).takeComposerDraft();
    if (draft == null || draft.isEmpty) return;
    _controller.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Enter sends. Shift+enter is a line break, which is what people reach
  /// for once the bar can hold more than one line.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    final bool shift = HardwareKeyboard.instance.isShiftPressed;
    if (shift) return KeyEventResult.ignored;
    _send();
    return KeyEventResult.handled;
  }

  void _send() {
    if (_polishing) return;
    if (_controller.text.trim().isNotEmpty) Haptics.light();
    final String text = _controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    final String carried = _attachments.isEmpty
        ? text
        : <String>[
            if (text.isNotEmpty) text,
            '[${_attachments.length} attached: '
                '${_attachments.map((PickedFile f) => f.name).join(', ')}]',
          ].join('\n');
    final bool sent = widget.onSend?.call(carried) ?? true;
    if (!sent) {
      _focus.requestFocus();
      return;
    }
    _controller.clear();
    setState(_attachments.clear);
    _focus.requestFocus();
  }

  /// The "+" takes any kind of file, several at a time, and shows what it
  /// took above the pill so nothing is attached invisibly.
  Future<void> _attach() async {
    final List<PickedFile> picked = await pickAnyFiles();
    if (picked.isEmpty || !mounted) return;
    setState(() => _attachments.addAll(picked));
    _say(
      picked.length == 1
          ? 'Attached ${picked.first.name}'
          : 'Attached ${picked.length} files',
    );
  }

  /// The composer's own snackbars float above it rather than over it. Over
  /// it, they hid Send and the last lines of a polished brief — the lines
  /// the message asks you to read — for the four seconds they showed.
  ///
  /// It waits a frame, so a pill that just grew to fit a polished brief
  /// is measured at its new height rather than the one-line one.
  void _say(String message, {SnackBarAction? action}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showAbove(message, action);
    });
  }

  void _showAbove(String message, SnackBarAction? action) {
    final ScaffoldMessengerState? bar = ScaffoldMessenger.maybeOf(context);
    if (bar == null) return;
    final RenderObject? box = context.findRenderObject();
    // The composer's height already counts the home indicator, which the
    // floating snackbar adds again for itself.
    final double lift = box is RenderBox && box.hasSize
        ? math.max(0, box.size.height - MediaQuery.paddingOf(context).bottom)
        : 0;
    bar
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          margin: EdgeInsets.fromLTRB(Space.x4, 0, Space.x4, lift + Space.x2),
        ),
      );
  }

  /// Polish my prompt: the sparkle rewrites what is in the bar into a
  /// fuller brief and puts it back, so you can read it before sending.
  ///
  /// The bar is read-only until the answer lands, so nothing typed in the
  /// meantime is overwritten, and enter does not send the unpolished text
  /// underneath it. Every outcome says what happened: the rewrite comes
  /// with an Undo, text that is already a brief says so, and a refusal
  /// keeps what you typed and tells you why.
  Future<void> _polish() async {
    final String original = _controller.text;
    final String text = original.trim();
    if (text.isEmpty || _polishing) return;
    Haptics.light();
    setState(() => _polishing = true);
    // The engine does the rewriting. With no server configured the seeded
    // repository answers locally, so the button behaves the same offline.
    final ({String text, ShiftApiException? error}) result =
        await AppScope.read(context).polishPrompt(text);
    if (!mounted) return;
    final String polished = result.text;
    final bool changed = result.error == null && polished.trim() != text;
    setState(() {
      _polishing = false;
      if (changed) {
        _controller.value = TextEditingValue(
          text: polished,
          selection: TextSelection.collapsed(offset: polished.length),
        );
      }
    });
    _focus.requestFocus();

    _say(
      result.error != null
          ? 'Could not polish it: ${result.error!.message}'
          : changed
              ? 'Polished. Read it over before you send.'
              : 'That is already a full brief.',
      action: changed
          ? SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Only if the brief is still what is there: an Undo
                // after you have edited it would throw your edits away.
                if (!mounted || _controller.text != polished) return;
                _controller.value = TextEditingValue(
                  text: original,
                  selection: TextSelection.collapsed(offset: original.length),
                );
              },
            )
          : null,
    );
  }

  /// Opens the avatar sheet and applies whatever gets tapped. Closing it
  /// without tapping anything leaves the current choice alone.
  void _pickAvatar(AppState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) =>
          _AvatarSheet(state: state, onPicked: Navigator.of(sheetContext).pop),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final AppState state = AppScope.of(context);
    final Avatar? active = widget.showAvatarPicker
        ? state.avatars
            .where((Avatar a) => a.id == state.activeAvatarId)
            .firstOrNull
        : null;
    final bool showAvatarButton =
        widget.showAvatarPicker && state.avatars.any((Avatar a) => a.ready);

    // Clear of the home indicator and gesture area. Android draws the app
    // edge to edge now, and nothing stopped the bar sitting under the pill.
    // On the web the inset is zero, so this changes nothing there.
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.x4,
          Space.x3,
          Space.x4,
          Space.x5,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.width),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_attachments.isNotEmpty) ...<Widget>[
                  Wrap(
                    spacing: Space.x2,
                    runSpacing: Space.x2,
                    children: <Widget>[
                      for (int i = 0; i < _attachments.length; i++)
                        _AttachmentChip(
                          file: _attachments[i],
                          onRemove: () =>
                              setState(() => _attachments.removeAt(i)),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.x3),
                ],
                Container(
                  // 44 for the controls plus 6 top and bottom is the 56 the
                  // pill is drawn at, so at rest the row fills it exactly and
                  // nothing has to be nudged to look centred.
                  key: const ValueKey<String>('composer-pill'),
                  constraints: const BoxConstraints(minHeight: _pillHeight),
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.x2,
                    vertical: _pillInset,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: const BorderRadius.all(Radius.circular(28)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Attach a file — any kind',
                        onPressed: _attach,
                        icon: Icon(Icons.add_rounded,
                            size: 22, color: c.textMuted),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(_controlSize, _controlSize),
                        ),
                      ),
                      Expanded(
                        // A polished prompt is several lines, and people
                        // paste paragraphs: the pill grows to eight lines
                        // and then scrolls. Enter sends, shift+enter breaks.
                        //
                        // One line of body type is 28 tall, so 8 above and
                        // below makes the field exactly as tall as a control.
                        // Every child is then 44 and the row is level; once
                        // the text wraps, the row grows and the controls stay
                        // with the last line.
                        //
                        // The 8 is the field's own content padding, not a
                        // Padding round it, so the whole 44 row focuses the
                        // field. Before, only the middle 28 did, under the
                        // 44-point minimum.
                        child: Focus(
                          onKeyEvent: _onKey,
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            readOnly: _polishing,
                            minLines: 1,
                            maxLines: 8,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: ShiftType.body(c.text),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: (_controlSize - 28) / 2,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: widget.hint,
                              hintStyle: ShiftType.body(c.textMuted),
                            ),
                          ),
                        ),
                      ),
                      if (showAvatarButton)
                        IconButton(
                          tooltip: active == null
                              ? 'Generating as ${BuiltInAvatars.shiftai.name}'
                              : 'Generating as ${active.name}',
                          onPressed: () => _pickAvatar(state),
                          // A plain glyph, same family as the "+" beside it —
                          // just tinted the accent once an avatar is active,
                          // never a photo or a ring around this one.
                          icon: Icon(
                            active == null
                                ? Icons.face_outlined
                                : Icons.face_rounded,
                            size: 22,
                            color: active == null ? c.textMuted : c.accent,
                          ),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(_controlSize, _controlSize),
                          ),
                        ),
                      if (widget.showSparkle)
                        // Greyed until there is something to polish, so an
                        // empty bar does not offer a button that does nothing.
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (BuildContext context,
                              TextEditingValue value, Widget? _) {
                            final bool empty = value.text.trim().isEmpty;
                            return IconButton(
                              tooltip: 'Polish my prompt',
                              onPressed: _polishing || empty ? null : _polish,
                              icon: _polishing
                                  ? ShiftSpinner(color: c.textMuted, size: 18)
                                  : Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 20,
                                      color: empty ? c.textMuted : c.accent,
                                    ),
                              style: IconButton.styleFrom(
                                minimumSize:
                                    const Size(_controlSize, _controlSize),
                              ),
                            );
                          },
                        ),
                      const SizedBox(width: Space.x1),
                      // A full control, 44 like the rest. It was a 40
                      // circle, under Apple's 44-point minimum target.
                      SizedBox(
                        width: _controlSize,
                        height: _controlSize,
                        child: Center(
                          child: SizedBox(
                            width: _controlSize,
                            height: _controlSize,
                            child: IconButton(
                              tooltip: widget.onStop == null ? 'Send' : 'Stop',
                              onPressed: widget.onStop == null
                                  ? _send
                                  : () {
                                      Haptics.light();
                                      widget.onStop!();
                                    },
                              icon: Icon(
                                widget.onStop == null
                                    ? Icons.arrow_upward_rounded
                                    : Icons.stop_rounded,
                                size: 20,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: c.accent,
                                foregroundColor: c.onAccent,
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The composer button's own face: the active avatar's preview, ringed in
/// the accent so it reads as "on" rather than just another icon, or a
/// plain outline face when generating in the engine's own default voice.
class _AvatarGlyph extends StatelessWidget {
  const _AvatarGlyph({required this.avatar, required this.size});

  final Avatar? avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    if (avatar == null) {
      return Icon(Icons.face_outlined, size: size, color: c.textMuted);
    }
    final String? previewUrl = avatar!.previewUrl;
    final String? asset = avatar!.asset;
    Widget face() =>
        Icon(Icons.face_rounded, size: size - 4, color: c.onAccent);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          shape: BoxShape.circle, border: Border.all(color: c.accent)),
      child: asset != null
          ? Image.asset(asset, fit: BoxFit.cover, width: size, height: size)
          : previewUrl == null
              ? face()
              : Image.network(
                  previewUrl,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorBuilder:
                      (BuildContext context, Object _, StackTrace? __) =>
                          face(),
                ),
    );
  }
}

/// What tapping the composer's avatar button opens: the built-in ShiftAi
/// avatar, plus every one of yours that has finished training. Training
/// ones are not offered — sending as one that is not ready is what
/// `docs/API.md` calls a `badRequest`, and a picker should not offer
/// choices the engine would refuse.
class _AvatarSheet extends StatelessWidget {
  const _AvatarSheet({required this.state, required this.onPicked});

  final AppState state;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final List<Avatar> ready =
        state.avatars.where((Avatar a) => a.ready).toList();

    void choose(String? id) {
      state.setActiveAvatar(id);
      onPicked();
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x5),
              child: Text('Generate as', style: ShiftType.caption(c.textMuted)),
            ),
            const SizedBox(height: Space.x2),
            // The built-in one first, and the choice when nothing else
            // is: until you make an avatar, this is who the Suite
            // generates as.
            _AvatarOption(
              avatar: BuiltInAvatars.shiftai,
              name: BuiltInAvatars.shiftai.name,
              subtitle: 'Built in',
              selected: state.activeAvatarId == null,
              onTap: () => choose(null),
            ),
            for (final Avatar avatar in ready)
              _AvatarOption(
                avatar: avatar,
                name: avatar.name,
                selected: state.activeAvatarId == avatar.id,
                onTap: () => choose(avatar.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.name,
    required this.selected,
    required this.onTap,
    this.avatar,
    this.subtitle,
  });

  final Avatar? avatar;
  final String name;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return ListTile(
      leading: _AvatarGlyph(avatar: avatar, size: 32),
      title: Text(name, style: ShiftType.body(c.text)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: ShiftType.caption(c.textMuted)),
      trailing: selected ? Icon(Icons.check_rounded, color: c.accent) : null,
      onTap: onTap,
    );
  }
}

/// What is attached, with a way to take it off again.
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.file, required this.onRemove});

  final PickedFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final IconData glyph = switch (file.kind) {
      PickedKind.image => Icons.image_outlined,
      PickedKind.video => Icons.movie_outlined,
      PickedKind.audio => Icons.graphic_eq_rounded,
      PickedKind.file => Icons.description_outlined,
    };

    return Container(
      padding:
          const EdgeInsets.fromLTRB(Space.x3, Space.x2, Space.x1, Space.x2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.pillAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(glyph, size: 16, color: c.sky),
          const SizedBox(width: Space.x2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ShiftType.bodySm(c.text),
            ),
          ),
          const SizedBox(width: Space.x2),
          Text(file.sizeLabel, style: ShiftType.caption(c.textMuted)),
          IconButton(
            tooltip: 'Remove ${file.name}',
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// "‹ Create   Trophies" — the way back to the screen a board hangs off.
class ScreenBreadcrumb extends StatelessWidget {
  const ScreenBreadcrumb({
    required this.parent,
    required this.title,
    required this.onBack,
    super.key,
  });

  final String parent;
  final String title;
  final VoidCallback onBack;

  /// A back link in the accent over the screen's title set large — the
  /// shape of a navigation stack. It was a grey pill with the parent's
  /// name beside a subheading, which put the way back and the place you
  /// are at the same weight.
  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Back to $parent',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: SizedBox(
              height: 36,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Pulled left so the chevron's own side bearing lines
                  // the text up with the title below it.
                  Transform.translate(
                    offset: const Offset(-6, 0),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 28,
                      color: c.accent,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(-8, 0),
                    child: Text(
                      parent,
                      style: ShiftType.copy(c.accent, size: 17, weight: 500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Semantics(
          header: true,
          child: Text(title, style: ShiftType.largeTitle(c.text)),
        ),
      ],
    );
  }
}

/// The two-tab header Agents uses, with the scope picker on the right.
class ScreenTabs extends StatelessWidget {
  const ScreenTabs({
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.scopeLabel,
    this.onScopeTap,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final String scopeLabel;

  /// The repository or folder picker to the right of the tabs.
  final VoidCallback? onScopeTap;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    // A segmented control, not underlined tabs: two views of one list are
    // a choice of lens, the way a Mail or Photos toolbar sets it.
    return Row(
      children: <Widget>[
        SegmentedPills<int>(
          options: List<int>.generate(labels.length, (int i) => i),
          labelOf: (int i) => labels[i],
          selected: selected,
          onChanged: onChanged,
        ),
        const SizedBox(width: Space.x3),
        // Takes what is left and shrinks with an ellipsis rather than
        // pushing off the edge: a repository or folder name has no length
        // limit, and at a large text size even a short one ran 101px past
        // the screen.
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: Radii.smAll,
              onTap: onScopeTap,
              // 44 tall, the minimum tap target; it was 36.
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: Space.x1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        scopeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ShiftType.copy(c.accent, size: 15, weight: 500),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: c.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rows in one filled, rounded group, with hairlines inset to where the
/// text starts — the grouped list a settings or standings page is built of.
class GroupedList extends StatelessWidget {
  const GroupedList({
    required this.children,
    this.dividerInset = Space.x4,
    super.key,
  });

  final List<Widget> children;

  /// How far in from the leading edge each hairline starts.
  final double dividerInset;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.surface, borderRadius: Radii.lgAll),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.only(left: dividerInset),
                  child: Divider(height: 1, thickness: 0.5, color: c.border),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Pull down to reload from the engine, as any list on an iPhone does.
///
/// The spinner is the platform's own (RefreshIndicator.adaptive): the
/// iOS activity wheel on an iPhone, Material's on Android and the web. A
/// reload that fails keeps what is on screen, which AppState.refresh
/// already does, and says why rather than dropping silently back into
/// place. The scroll view inside needs AlwaysScrollableScrollPhysics, or a
/// list shorter than the screen cannot be pulled at all.
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return RefreshIndicator.adaptive(
      color: c.accent,
      backgroundColor: c.surface,
      onRefresh: () async {
        final AppState state = AppScope.read(context);
        final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
        await state.refresh();
        final ShiftApiException? error = state.lastError;
        if (error != null) {
          bar.showSnackBar(SnackBar(content: Text(error.message)));
        }
      },
      child: child,
    );
  }
}

/// What a screen says when it has nothing to show: a symbol, a title, a
/// line on what goes here, and the one thing to do next.
///
/// These used to be a sentence of grey text, which is most of what a brand
/// new account sees on its first day. [compact] is for an empty filter or
/// search inside a screen that otherwise has content.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final double disc = compact ? 52 : 72;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? Space.x5 : Space.x7,
        horizontal: Space.x4,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: disc,
                height: disc,
                decoration: BoxDecoration(
                  color: c.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: disc * 0.46, color: c.accent),
              ),
              SizedBox(height: compact ? Space.x3 : Space.x4),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: compact
                      ? ShiftType.copy(c.text, size: 17, weight: 600)
                      : ShiftType.sectionTitle(c.text),
                ),
              ),
              const SizedBox(height: Space.x2),
              Text(
                message,
                textAlign: TextAlign.center,
                style: ShiftType.bodySm(c.textMuted),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: Space.x5),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A filled search field, as a list's search bar is drawn: a magnifier,
/// the hint, and a clear button once something is typed.
class SearchField extends StatefulWidget {
  const SearchField({required this.hint, required this.onChanged, super.key});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: Space.x3),
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
              controller: _text,
              onChanged: (String v) {
                setState(() {});
                widget.onChanged(v);
              },
              textInputAction: TextInputAction.search,
              style: ShiftType.copy(c.text, size: 16),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: widget.hint,
                hintStyle: ShiftType.copy(c.textMuted, size: 16),
              ),
            ),
          ),
          if (_text.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _text.clear();
                setState(() {});
                widget.onChanged('');
              },
              icon: Icon(Icons.cancel_rounded, size: 18, color: c.textMuted),
              style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
            )
          else
            const SizedBox(width: Space.x3),
        ],
      ),
    );
  }
}

/// A round check and its sentence, tappable as one row: the circle iOS
/// uses for a tick (Reminders, Mail's selection), rather than Material's
/// square box.
class ShiftCheckRow extends StatelessWidget {
  const ShiftCheckRow({
    required this.value,
    required this.onChanged,
    required this.child,
    super.key,
  });

  final bool value;

  /// Null greys the row out.
  final ValueChanged<bool>? onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final bool enabled = onChanged != null;
    return Semantics(
      checked: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                Haptics.selection();
                onChanged!(!value);
              }
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? c.accent : c.bg.withValues(alpha: 0),
                  border: Border.all(
                    color: value ? c.accent : c.borderStrong,
                    width: 1.5,
                  ),
                ),
                child: value
                    ? Icon(Icons.check_rounded, size: 16, color: c.onAccent)
                    : null,
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Opacity(opacity: enabled ? 1 : 0.5, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
