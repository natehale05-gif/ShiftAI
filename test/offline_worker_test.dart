import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web app's offline worker lives in the build script, as JavaScript,
/// so nothing compiles it here. These hold it to the rule it broke once.
String _worker() {
  final String script = File('tool/build_web_hosted.sh').readAsStringSync();
  final int start = script.indexOf("cat > offline_worker.js <<'JS'");
  final int end = script.indexOf('\nJS\n', start);
  expect(start, isNonNegative, reason: 'worker not found in the script');
  return script.substring(start, end);
}

void main() {
  test(
      'the worker caches this build\'s files by name, never the API: '
      'Rex\'s preview serves both from one origin', () {
    final String worker = _worker();
    // It used to answer every same-origin GET from its cache, so the
    // vault, avatars, saved chats and /v1/me stayed on their first copy
    // until the next deploy, whoever was signed in.
    expect(worker, contains('var FILES = new Set(__FILES__);'));
    expect(worker, contains('} else if (FILES.has(rel)) {'));
    expect(worker, isNot(contains('isPage ? page(req) : fromBuild(req)')));
    // The page's own list of what it fetched is filtered the same way.
    expect(worker, contains("rel === '' || FILES.has(rel)"));
  });

  test('the build writes the file list into the worker', () {
    final String script = File('tool/build_web_hosted.sh').readAsStringSync();
    expect(script, contains("js.replace('__FILES__', json.dumps(files))"));
  });
}
