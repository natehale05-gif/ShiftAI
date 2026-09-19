#!/usr/bin/env bash
# Builds the web app for a static host that only serves common web file
# types (no custom MIME types, no service worker).
#
#   - --no-web-resources-cdn keeps CanvasKit local, so the app makes no
#     outbound request at all. Fonts are bundled too.
#   - Debug symbol maps and the skwasm renderer are dropped; the JS build
#     only ever loads canvaskit.
#   - The service worker is removed, so a new version is picked up on
#     reload rather than served from a stale cache.
#   - AssetManifest.bin is copied to a .wasm name and a small shim in
#     index.html points the engine at it, because hosts that allow-list
#     extensions do not serve .bin.
#
# Usage: tool/build_web_hosted.sh   (from the project root)

set -euo pipefail

OUT="build/web"

flutter build web --release --no-web-resources-cdn

cd "$OUT"

rm -f canvaskit/*.symbols canvaskit/chromium/*.symbols
rm -f canvaskit/skwasm*
rm -f flutter_service_worker.js .last_build_id
rm -rf assets/shaders

python3 - <<'PY'
import re, pathlib
p = pathlib.Path('flutter_bootstrap.js')
s = p.read_text()
s2 = re.sub(
    r'_flutter\.loader\.load\(\{\s*serviceWorkerSettings:\s*\{[^}]*\}\s*,?\s*\}\);',
    '_flutter.loader.load({});',
    s,
)
# Idempotent: a bootstrap that already carries the bare load() has been
# through this once, which is not an error.
assert s2 != s or '_flutter.loader.load({})' in s, (
    'service worker registration not found in flutter_bootstrap.js'
)
p.write_text(s2)
PY

cp assets/AssetManifest.bin assets/AssetManifest.bin.wasm

cat > index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="description" content="SHIFT AI — the creator suite: chat, earnings, vault, trophies, notes, agents.">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="SHIFT AI">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/png" href="favicon.png">
  <link rel="manifest" href="manifest.json">
  <title>SHIFT AI</title>
  <style>
    /* ShiftColors.retro bg and textMuted. This is painted before any
       Dart runs, so it has to match the theme a new account opens on or
       the load flashes one ground and then repaints another. */
    html, body { margin: 0; padding: 0; height: 100%; background: #0A0A0F; }
    #boot {
      position: fixed; inset: 0; display: flex; align-items: center;
      justify-content: center; background: #0A0A0F; color: #BFBFBF;
      font: 500 11px/14px ui-monospace, "SF Mono", Menlo, Consolas, monospace;
      letter-spacing: 0.16em;
    }
  </style>
</head>
<body>
  <div id="boot">LOADING SHIFT AI</div>
  <script>
    // Hosts that allow-list file extensions will not serve .bin, so the
    // asset manifest ships under a .wasm name and the engine is pointed
    // at it here. No base href: every path resolves against this page.
    (function () {
      var rewrite = { 'assets/AssetManifest.bin': 'assets/AssetManifest.bin.wasm' };
      var original = window.fetch.bind(window);
      window.fetch = function (input, init) {
        try {
          var url = typeof input === 'string' ? input : (input && input.url) || '';
          for (var from in rewrite) {
            if (url.slice(-from.length) === from) {
              return original(url.slice(0, url.length - from.length) + rewrite[from], init);
            }
          }
        } catch (e) { /* fall through to the real fetch */ }
        return original(input, init);
      };
    })();
  </script>
  <script src="flutter_bootstrap.js" async></script>
  <script>
    window.addEventListener('flutter-first-frame', function () {
      var boot = document.getElementById('boot');
      if (boot) { boot.remove(); }
    });
  </script>
</body>
</html>
HTML

echo "built $(find . -type f | wc -l) files, $(du -sh . | cut -f1)"
