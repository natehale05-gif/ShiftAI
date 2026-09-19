import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'picked_file.dart';

export 'picked_file.dart';

/// iOS, Android and desktop go through the platform's own picker. The bytes
/// are read here so everything above this deals in [PickedFile] and never
/// in a path that may not exist on every platform.
Future<List<PickedFile>> pickAnyFiles() async {
  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    // Any kind of file, to match what the web dialog offers.
    type: FileType.any,
    withData: true,
  );
  if (result == null) return const <PickedFile>[];
  return result.files
      .map(_from)
      .whereType<PickedFile>()
      .toList(growable: false);
}

Future<PickedFile?> pickOneImage() async {
  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  return _from(result.files.first);
}

PickedFile? _from(PlatformFile file) {
  final Uint8List? bytes = file.bytes;
  if (bytes == null) return null;
  return PickedFile(
    name: file.name,
    bytes: bytes,
    mimeType: _mimeFor(file.extension?.toLowerCase()),
  );
}

/// The picker gives an extension, not a type. Enough of a table to get the
/// chip glyph right; anything unrecognised is a document, which is what the
/// chip falls back to anyway.
String _mimeFor(String? extension) => switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'svg' => 'image/svg+xml',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'pdf' => 'application/pdf',
      'zip' => 'application/zip',
      'json' => 'application/json',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      _ => 'application/octet-stream',
    };
