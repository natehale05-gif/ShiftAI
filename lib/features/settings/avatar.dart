import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/type.dart';

/// A photo of you, plus how it is framed in the circle. The photo is kept
/// whole and the crop is stored beside it, so the framing can be changed
/// later without asking for the picture again.
@immutable
class AvatarPhoto {
  const AvatarPhoto({
    required this.bytes,
    this.zoom = 1,
    this.offsetX = 0,
    this.offsetY = 0,
  });

  /// The picture, already scaled down to avatar size on the way in.
  final Uint8List bytes;

  /// 1 is "fit the circle"; above that crops in.
  final double zoom;

  /// Where the picture sits in the circle, as a fraction of its own size,
  /// so the framing survives being drawn at any diameter.
  final double offsetX;
  final double offsetY;

  AvatarPhoto copyWith({double? zoom, double? offsetX, double? offsetY}) =>
      AvatarPhoto(
        bytes: bytes,
        zoom: zoom ?? this.zoom,
        offsetX: offsetX ?? this.offsetX,
        offsetY: offsetY ?? this.offsetY,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'bytes': base64Encode(bytes),
        'zoom': zoom,
        'dx': offsetX,
        'dy': offsetY,
      };

  static AvatarPhoto? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final String? encoded = raw['bytes'] as String?;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      return AvatarPhoto(
        bytes: base64Decode(encoded),
        zoom: (raw['zoom'] as num?)?.toDouble() ?? 1,
        offsetX: (raw['dx'] as num?)?.toDouble() ?? 0,
        offsetY: (raw['dy'] as num?)?.toDouble() ?? 0,
      );
    } on FormatException {
      return null;
    }
  }
}

/// The longest side a stored avatar photo is allowed. Big enough to stay
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

/// The avatar: the photo framed in a circle when there is one, initials
/// when there is not.
class ShiftAvatar extends StatelessWidget {
  const ShiftAvatar({
    required this.photo,
    required this.initials,
    this.size = 36,
    this.ring = true,
    super.key,
  });

  final AvatarPhoto? photo;
  final String initials;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final ShiftColors c = ShiftColors.of(context);

    if (photo == null) {
      return Container(
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
          style: ShiftType.mono(c.accent, size: size * 0.33),
        ),
      );
    }

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
        child: AvatarFrame(photo: photo!, diameter: size),
      ),
    );
  }
}

/// The photo drawn at its saved zoom and position. Used both by the small
/// avatar and by the editor, so what you frame is exactly what you get.
class AvatarFrame extends StatelessWidget {
  const AvatarFrame({
    required this.photo,
    required this.diameter,
    super.key,
  });

  final AvatarPhoto photo;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Transform.translate(
          offset: Offset(
            photo.offsetX * diameter,
            photo.offsetY * diameter,
          ),
          child: Transform.scale(
            scale: photo.zoom,
            child: Image.memory(
              photo.bytes,
              fit: BoxFit.cover,
              width: diameter,
              height: diameter,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (BuildContext context, Object _, StackTrace? __) =>
                  ColoredBox(color: ShiftColors.of(context).surfaceRaised),
            ),
          ),
        ),
      ),
    );
  }
}
