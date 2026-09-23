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
      label: 'SHIFT ai',
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

/// A short uppercase mono line above a block.
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
                        color: Colors.black.withValues(
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
                    onTap: () => onChanged(option),
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
    super.key,
  });

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
          color: selected ? c.accent : Colors.white.withValues(alpha: 0.06),
          width: selected ? 2.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: Radii.lgAll,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            PosterArt(seed: seed),
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
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: Radii.smAll,
                  ),
                  child: d == null
                      ? const Icon(
                          Icons.play_arrow_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : Text(
                          _clock(d),
                          style: ShiftType.figures(
                            Colors.white,
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

/// Art for a piece with no thumbnail — which is every piece, until the
/// engine sends previews.
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
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
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
    final Color night = Color.lerp(Colors.black, lead, 0.14)!;

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
            child: Text(error.message, style: ShiftType.bodySm(c.text)),
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

    return Tooltip(
      message: on ? 'Saved to your vault' : 'Save to your vault',
      child: IconButton(
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
      ),
    );
  }

  Future<void> _toggle(BuildContext context, AppState state) async {
    final bool wasOn = item.saved;
    final ScaffoldMessengerState bar = ScaffoldMessenger.of(context);
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
    final ScaffoldMessengerState? bar = ScaffoldMessenger.maybeOf(context);
    bar?.showSnackBar(
      SnackBar(
        content: Text(
          picked.length == 1
              ? 'Attached ${picked.first.name}'
              : 'Attached ${picked.length} files',
        ),
      ),
    );
  }

  /// Polish my prompt: the sparkle rewrites what is in the bar into a
  /// fuller brief and puts it back, so you can read it before sending.
  Future<void> _polish() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || _polishing) return;
    setState(() => _polishing = true);
    // The engine does the rewriting. With no server configured the seeded
    // repository answers locally, so the button behaves the same offline.
    final String polished = await AppScope.read(context).polishPrompt(text);
    if (!mounted) return;
    setState(() {
      _polishing = false;
      _controller.value = TextEditingValue(
        text: polished,
        selection: TextSelection.collapsed(offset: polished.length),
      );
    });
    _focus.requestFocus();
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

    return Padding(
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
                      icon:
                          Icon(Icons.add_rounded, size: 22, color: c.textMuted),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: (_controlSize - 28) / 2,
                        ),
                        child: Focus(
                          onKeyEvent: _onKey,
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            minLines: 1,
                            maxLines: 8,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: ShiftType.body(c.text),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintText: widget.hint,
                              hintStyle: ShiftType.body(c.textMuted),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showAvatarButton)
                      IconButton(
                        tooltip: active == null
                            ? 'Choose an avatar to generate as'
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
                      IconButton(
                        tooltip: 'Polish my prompt',
                        onPressed: _polishing ? null : _polish,
                        icon: _polishing
                            ? SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    c.accent,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.auto_awesome_rounded,
                                size: 20,
                                color: c.accent,
                              ),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(_controlSize, _controlSize),
                        ),
                      ),
                    const SizedBox(width: Space.x1),
                    // The send circle is smaller than a control, so it is
                    // centred inside one rather than sitting on the floor.
                    SizedBox(
                      width: _controlSize,
                      height: _controlSize,
                      child: Center(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            tooltip: 'Send',
                            onPressed: _send,
                            icon: const Icon(
                              Icons.arrow_upward_rounded,
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
    Widget face() =>
        Icon(Icons.face_rounded, size: size - 4, color: c.onAccent);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          shape: BoxShape.circle, border: Border.all(color: c.accent)),
      child: previewUrl == null
          ? face()
          : Image.network(
              previewUrl,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (BuildContext context, Object _, StackTrace? __) =>
                  face(),
            ),
    );
  }
}

/// What tapping the composer's avatar button opens: this ask's default
/// voice, plus every avatar that has finished training. Training ones are
/// not offered — sending as one that is not ready is what `docs/API.md`
/// calls a `badRequest`, and a picker should not offer choices the engine
/// would refuse.
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
            _AvatarOption(
              name: 'Default voice',
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
  });

  final Avatar? avatar;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return ListTile(
      leading: _AvatarGlyph(avatar: avatar, size: 32),
      title: Text(name, style: ShiftType.body(c.text)),
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
        Text(title, style: ShiftType.largeTitle(c.text)),
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
        const Spacer(),
        InkWell(
          borderRadius: Radii.smAll,
          onTap: onScopeTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x1,
              vertical: Space.x2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  scopeLabel,
                  style: ShiftType.copy(c.accent, size: 15, weight: 500),
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
