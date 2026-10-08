import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'the hosted page connects to the saved server while the app loads, '
      'the way the app\'s reads will use it', () {
    final String script = File('tool/build_web_hosted.sh').readAsStringSync();
    // The key the app saves the server under, as shared_preferences on the
    // web stores it.
    expect(script, contains("localStorage.getItem('flutter.shift-backend')"));
    expect(script, contains("link.rel = 'preconnect';"));
    // CORS reads without cookies only reuse an anonymous connection.
    expect(script, contains("link.crossOrigin = 'anonymous';"));
    // Before the engine starts, so it overlaps the download.
    expect(script.indexOf("link.rel = 'preconnect';"),
        lessThan(script.indexOf('<script src="flutter_bootstrap.js"')));
  });

  test('the key it reads is the one the app saves the server under', () {
    final String state = File('lib/state/app_state.dart').readAsStringSync();
    expect(state, contains("static const String backend = 'shift-backend';"));
  });
}
