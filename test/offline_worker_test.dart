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

  test(
      'every file the worker fetches is revalidated, never taken from the '
      'browser\'s cache of the last build', () {
    final String worker = _worker();
    // main.dart.js has the same name in every build and Pages lets a
    // browser reuse it for 10 minutes: a new build's cache was filled with
    // the old one, and the app did not update until the deploy after.
    expect(worker, contains("cache: 'no-cache'"));
    expect(RegExp(r'\bfetch\(req\)').hasMatch(worker), isFalse);
    expect(worker, isNot(contains('cache.add(')));
    expect(worker, contains('hit || fresh(req)'));
    expect(worker, contains('return hit || fresh(req).then('));
  });

  test(
      'the page reloads once when a new build\'s worker takes over from '
      'an old one', () {
    final String script = File('tool/build_web_hosted.sh').readAsStringSync();
    // The old worker handed a fresh page the old main.dart.js; the page's
    // build id matched the server's, so nothing ever reloaded it.
    expect(script, contains("addEventListener('controllerchange'"));
    expect(script,
        contains('var hadWorker = !!navigator.serviceWorker.controller;'));
    expect(script, contains('if (!hadWorker || reloaded) return;'));
  });

  test(
      'the page opens from this build\'s copy without waiting on the '
      'network', () {
    final String worker = _worker();
    // It used to race the network for up to 2 s on every open: on a weak
    // signal, 2 s of loading screen before a copy already in the cache.
    expect(worker, isNot(contains('PAGE_WAIT_MS')));
    expect(worker, isNot(contains('setTimeout')));
    final String page = worker.substring(worker.indexOf('function page(req)'),
        worker.indexOf("self.addEventListener('fetch'"));
    final int cached = page.indexOf("cache.match('index.html'");
    final int network = page.indexOf('return hit || fresh(req).then(');
    expect(cached, isNonNegative);
    expect(network, greaterThan(cached),
        reason: 'the cache is asked first, the network only after');
  });

  test('the build writes the file list into the worker', () {
    final String script = File('tool/build_web_hosted.sh').readAsStringSync();
    expect(script, contains("js.replace('__FILES__', json.dumps(files))"));
  });
}
