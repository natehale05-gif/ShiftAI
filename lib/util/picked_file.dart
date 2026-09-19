import 'package:flutter/foundation.dart';

/// One file the person chose, whatever its kind — image, video, audio,
/// document, archive. The composer only needs the name and the size to
/// show it; the bytes are there for the upload the real client does.
@immutable
class PickedFile {
  const PickedFile({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;

  int get sizeBytes => bytes.length;

  /// "2.4 MB", "812 KB", "94 B" — short enough for a chip.
  String get sizeLabel {
    final int b = sizeBytes;
    if (b >= 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (b >= 1024) return '${(b / 1024).round()} KB';
    return '$b B';
  }

  /// The broad family, used to pick the chip's glyph. Anything that is not
  /// obviously media is treated as a document rather than refused.
  PickedKind get kind {
    final String m = mimeType.toLowerCase();
    if (m.startsWith('image/')) return PickedKind.image;
    if (m.startsWith('video/')) return PickedKind.video;
    if (m.startsWith('audio/')) return PickedKind.audio;
    return PickedKind.file;
  }
}

enum PickedKind { image, video, audio, file }
