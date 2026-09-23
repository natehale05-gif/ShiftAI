import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/type.dart';

/// The longest side a picked avatar photo is allowed. Big enough to stay
/// sharp at every size the app draws it, small enough to keep in storage.
const int kAvatarMaxSide = 512;

/// Scales a picked image down and re-encodes it as PNG. Returns null if the
/// bytes are not an image the engine can read.
Future<Uint8List?> prepareAvatarBytes(Uint8List source) async {
  try {
    // Decode once to learn the size, then decode again at the size we
    // actually want. Re-encoding through the canvas keeps this working on
    // every backend rather than depending on codec-level scaling.
    final ui.Codec probe = await ui.instantiateImageCodec(source);
    final ui.FrameInfo first = await probe.getNextFrame();
    final int w = first.image.width;
    final int h = first.image.height;
    first.image.dispose();
    probe.dispose();
    if (w == 0 || h == 0) return null;

    final int longest = math.max(w, h);
    if (longest <= kAvatarMaxSide) return source;

    final double factor = kAvatarMaxSide / longest;
    final ui.Codec codec = await ui.instantiateImageCodec(
      source,
      targetWidth: math.max(1, (w * factor).round()),
      targetHeight: math.max(1, (h * factor).round()),
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ByteData? png =
        await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    // If re-encoding is not available, the original still works — it is
    // only bigger.
    return png?.buffer.asUint8List() ?? source;
  } on Object catch (error) {
    debugPrint('avatar: could not read the picture — $error');
    return null;
  }
}

/// The avatar: the personal HeyGen avatar's preview when there is a
/// ready one, initials otherwise. The preview is hosted by the server, so
/// drawing it costs a network image rather than bytes on the device.
class ShiftAvatar extends StatelessWidget {
  const ShiftAvatar({
    required this.initials,
    this.previewUrl,
    this.size = 36,
    this.ring = true,
    super.key,
  });

  /// The personal avatar's preview URL. Null while there is none yet, or
  /// while the personal one is still training.
  final String? previewUrl;
  final String initials;
  final double size;
  final bool ring;

  Widget _initials(ShiftColors c) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.accentSoft,
          border:
              ring ? Border.all(color: c.accent.withValues(alpha: 0.45)) : null,
        ),
        child: Text(
          initials,
          style: ShiftType.copy(c.accent, size: size * 0.36, weight: 600),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);
    final String? url = previewUrl;

    if (url == null || url.isEmpty) return _initials(c);

    return Semantics(
      label: 'Your avatar',
      image: true,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: ring ? Border.all(color: c.border) : null,
        ),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          // A broken or slow link reads as no avatar yet, not a hole in
          // the circle.
          errorBuilder: (BuildContext context, Object _, StackTrace? __) =>
              _initials(c),
          loadingBuilder: (
            BuildContext context,
            Widget child,
            ImageChunkEvent? progress,
          ) =>
              progress == null ? child : _initials(c),
        ),
      ),
    );
  }
}
