import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/type.dart';

/// The longest side of the photo sent to train an avatar. It used to be
/// 512 — a size chosen when this was a profile picture — which is far too
/// little for HeyGen to build a likeness from. 2048 keeps a phone photo's
/// detail and still caps a 48-megapixel original at a few megabytes.
const int kAvatarMaxSide = 2048;

/// Below this on the shorter side there is not enough face to train on.
/// Better to say so here than to upload it and fail minutes later.
const int kAvatarMinSide = 256;

/// A photo ready to upload, or the sentence saying why it is not.
class PreparedPhoto {
  const PreparedPhoto._({
    this.bytes,
    this.mimeType = 'image/png',
    this.fileName = 'avatar.png',
    this.problem,
  });

  final Uint8List? bytes;

  /// Always matches [bytes]. A small JPEG used to go up unchanged but
  /// labelled `image/png`, which is the kind of mismatch a renderer
  /// rejects without saying why.
  final String mimeType;
  final String fileName;
  final String? problem;
}

/// Checks a picked photo and scales it down if it is huge. Kept as it is
/// when it is already a sensible size, so nothing is lost to re-encoding.
Future<PreparedPhoto> prepareAvatarPhoto(
  Uint8List source, {
  required String fileName,
  required String mimeType,
}) async {
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
    if (w == 0 || h == 0) return _unreadable(fileName);
    if (math.min(w, h) < kAvatarMinSide) {
      return PreparedPhoto._(
        problem: '$fileName is $w × $h. Use a photo at least '
            '$kAvatarMinSide pixels on each side, face clearly in view.',
      );
    }

    final int longest = math.max(w, h);
    if (longest <= kAvatarMaxSide) {
      return PreparedPhoto._(
        bytes: source,
        mimeType: _imageType(mimeType, fileName),
        fileName: fileName,
      );
    }

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
    // only bigger — and keeps its own type.
    if (png == null) {
      return PreparedPhoto._(
        bytes: source,
        mimeType: _imageType(mimeType, fileName),
        fileName: fileName,
      );
    }
    return PreparedPhoto._(
      bytes: png.buffer.asUint8List(),
      fileName: '${_stem(fileName)}.png',
    );
  } on Object catch (error) {
    debugPrint('avatar: could not read the picture — $error');
    return _unreadable(fileName);
  }
}

PreparedPhoto _unreadable(String fileName) => PreparedPhoto._(
      problem: 'Could not read $fileName as a picture. '
          'Try a JPEG or PNG.',
    );

String _stem(String fileName) {
  final int dot = fileName.lastIndexOf('.');
  return dot <= 0 ? fileName : fileName.substring(0, dot);
}

/// The picker's type when it is an image type, otherwise one read off the
/// extension. Never `application/octet-stream` for something that decoded
/// as a picture.
String _imageType(String mimeType, String fileName) {
  if (mimeType.startsWith('image/')) return mimeType;
  final String ext = fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    _ => 'image/png',
  };
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
