import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'the Apple Music picker stays compiled out, and nothing in lib/ asks '
      'for it', () {
    // Left in, App Store Connect asks for an NSAppleMusicUsageDescription
    // (ITMS-90683), a purpose string for access ShiftAi does not use.
    expect(
      File('ios/Podfile').readAsStringSync(),
      contains('\nPod::PICKER_AUDIO = false\n'),
    );
    // With it out, FileType.audio fails at runtime with "Support for the
    // Audio picker is not compiled in". Nothing may ask for it.
    final List<String> asks = <String>[];
    for (final FileSystemEntity f
        in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.readAsStringSync().contains('FileType.audio')) asks.add(f.path);
    }
    expect(asks, isEmpty);
  });
}
