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

/// The lockup's artwork, recoloured to whichever theme is showing.
///
/// There are two brand files, and their palettes are the dark and light
/// themes' own `text` and `accent` tokens — which is why the retro pair
/// used to draw a blue "ai" over a pink app. Rather than add a third and
/// fourth copy of the same drawing, one file is loaded and its two fills
/// are swapped for the live theme's. A theme added later is then carried
/// with no new artwork.
abstract final class ShiftLockup {
  /// The fills in the on-dark artwork: the wordmark, then the divider and
  /// the "ai", which share a colour.
  static const String _artText = '#F2F5FA';
  static const String _artAccent = '#5B8CFF';

  static const String asset = 'assets/brand/shift-ai-on-dark.svg';

  static String? _template;

  /// Read once, before the first frame. Without it [ShiftLogo] falls back
  /// to the unrecoloured files, so a missed preload is a wrong colour
  /// rather than a missing logo.
  static Future<void> preload() async {
    if (_template != null) return;
    final String svg = await rootBundle.loadString(asset);
    // If the artwork is redrawn with a different palette the swap below
    // would quietly do nothing and the lockup would stick on the old
    // blue. Better to fall back to the files and say so in debug.
    final bool recognised =
        svg.contains(_artText) && svg.contains(_artAccent);
    assert(
      recognised,
      'The lockup no longer contains $_artText and $_artAccent. Update '
      'ShiftLockup, or it will draw the wrong colours.',
    );
    if (recognised) _template = svg;
  }

  static String _hex(Color c) {
    String channel(double v) =>
        (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${channel(c.r)}${channel(c.g)}${channel(c.b)}'.toUpperCase();
  }

  /// The artwork with the wordmark in [text] and the "ai" in [accent], or
  /// null when [preload] has not run.
  static String? forColors(Color text, Color accent) {
    final String? svg = _template;
    if (svg == null) return null;
    return svg
        .replaceAll(_artText, _hex(text))
        .replaceAll(_artAccent, _hex(accent));
  }
}

/// The lockup, from the brand files. Never set by hand; recoloured only to
/// the theme's own tokens, never to a colour chosen here.
class ShiftLogo extends StatelessWidget {
  const ShiftLogo({this.height = 22, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    // The artwork is 589.6 × 71.55, and never goes below 110px wide.
    final double width = math.max(height * (589.6 / 71.55), 110);
    final String? themed = ShiftLockup.forColors(c.text, c.accent);

    return Semantics(
      label: 'SHIFT ai',
      child: themed != null
          ? SvgPicture.string(themed, width: width, height: height)
          : SvgPicture.asset(
              c.isDarkGround
                  ? ShiftLockup.asset
                  : 'assets/brand/shift-ai-on-light.svg',
              width: width,
              height: height,
            ),
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
    return Text(
      text.toUpperCase(),
      style: ShiftType.labelSm(color ?? c.textMuted),
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
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? c.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: borderColor ?? c.border),
      ),
      child: child,
    );
  }
}

/// The two-way scope toggle the vault uses.
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
    return Container(
      padding: const EdgeInsets.all(Space.x1),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.pillAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: options.map((T option) {
          final bool on = option == selected;
          final Widget button = Semantics(
            selected: on,
            button: true,
            child: InkWell(
              borderRadius: Radii.pillAll,
              onTap: () => onChanged(option),
              child: Container(
                height: 36,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                decoration: BoxDecoration(
                  color: on ? c.accent : Colors.transparent,
                  borderRadius: Radii.pillAll,
                ),
                child: Text(
                  labelOf(option).toUpperCase(),
                  style: ShiftType.labelSm(on ? c.onAccent : c.textMuted),
                ),
              ),
            ),
          );
          return expand ? Expanded(child: button) : button;
        }).toList(),
      ),
    );
  }
}

/// A placeholder for media that has no bytes on device. Better an honest
/// labelled block than a bad guess at the real thing.
class MediaPlaceholder extends StatelessWidget {
  const MediaPlaceholder({
    required this.label,
    required this.tag,
    this.caption,
    this.selected = false,
    this.labelMaxLines = 1,
    super.key,
  });

  final String label;
  final String tag;
  final String? caption;
  final bool selected;

  /// A tall tile can give a long title a second line; a short one cannot,
  /// so the caller decides rather than the text overflowing.
  final int labelMaxLines;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Container(
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: selected ? c.surfaceRaised : c.surface,
        borderRadius: Radii.lgAll,
        border: Border.all(color: selected ? c.accent : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x2,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: selected ? c.bg : c.surfaceRaised,
              borderRadius: Radii.smAll,
            ),
            child: Text(
              tag.toUpperCase(),
              style: ShiftType.labelSm(tag == 'video' ? c.sky : c.textMuted),
            ),
          ),
          // The text sits on the floor of the tile and takes only the
          // lines that actually fit. Splitting the leftover space with a
          // Spacer used to cut the second line of a title in half on a
          // narrow tile; here a line is either drawn whole or dropped for
          // an ellipsis.
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                const double labelLine = 24;
                const double captionLine = 20;
                final double forLabel = caption == null
                    ? box.maxHeight
                    : box.maxHeight - captionLine;
                final int lines =
                    (forLabel / labelLine).floor().clamp(1, labelMaxLines);

                return Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        maxLines: lines,
                        overflow: TextOverflow.ellipsis,
                        style: ShiftType.bodyStrong(c.text),
                      ),
                      if (caption != null)
                        Text(
                          caption!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ShiftType.caption(c.textMuted),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
                          minimumSize:
                              const Size(_controlSize, _controlSize),
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
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.accent)),
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
              child: Text('Generate as', style: ShiftType.labelSm(c.textMuted)),
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
      trailing:
          selected ? Icon(Icons.check_rounded, color: c.accent) : null,
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

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    return Row(
      children: <Widget>[
        InkWell(
          borderRadius: Radii.pillAll,
          onTap: onBack,
          child: Container(
            height: 44,
            padding: const EdgeInsets.fromLTRB(
              Space.x3,
              0,
              Space.x4,
              0,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: Radii.pillAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.chevron_left_rounded, size: 20, color: c.textMuted),
                const SizedBox(width: Space.x1),
                Text(parent, style: ShiftType.bodySm(c.textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(width: Space.x4),
        Text(
          title,
          style: ShiftType.subheading(c.text),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            for (int i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: Space.x5),
                child: Semantics(
                  selected: i == selected,
                  button: true,
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Container(
                      padding: const EdgeInsets.only(bottom: Space.x2),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 2,
                            color:
                                i == selected ? c.accent : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Text(
                        labels[i],
                        style: ShiftType.subheading(
                          i == selected ? c.text : c.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: Space.x2),
              child: InkWell(
                borderRadius: Radii.smAll,
                onTap: onScopeTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(scopeLabel, style: ShiftType.bodySm(c.textMuted)),
                    const SizedBox(width: Space.x1),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: c.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Divider(height: 1, color: c.border),
      ],
    );
  }
}
