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
#   - A build id (the git commit, so it is unique per deploy) is baked
#     into the page and polled for while the app is open, since without a
#     service worker nothing else notices a new build has shipped — an
#     installed PWA that is only ever resumed, never fully reloaded,
#     would otherwise run whatever it first loaded forever.
#
# Usage: tool/build_web_hosted.sh   (from the project root)

set -euo pipefail

OUT="build/web"

# version.json's build_number comes straight from pubspec.yaml and does
# not change from one deploy to the next, so it cannot serve as this
# signal — the git commit does.
BUILD_ID="$(git rev-parse HEAD 2>/dev/null || date +%s)"

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

# Rewritten on every build with a fresh value; the page polls this while
# open and reloads itself when it no longer matches what it booted with.
printf '%s' "$BUILD_ID" > build_id.txt

cat > index.html <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="description" content="ShiftAi — the creator suite: chat, earnings, vault, trophies, notes, agents.">
  <!--
    The live theme-color tag is what Chrome reads, in real time, for the
    status bar. An installed app's navigation bar ignores it and takes the
    manifest's colours, re-read only when Chrome checks the installed app
    for updates. Hence one manifest per theme, and the script below
    linking the right one.
  -->
  <meta name="theme-color" content="#0A0A0F">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="ShiftAi">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/png" href="favicon.png">
  <link rel="manifest" href="manifest.json">
  <title>ShiftAi</title>
  <script>
    // Before any Dart runs: link the manifest for the theme this person
    // last chose, and paint the first frame in it. Chrome colours an
    // installed app's navigation bar from the manifest alone and can read
    // it as soon as the page loads, before the app has started and
    // swapped the link itself (system_bars_web.dart). The saved blob is
    // shared_preferences' JSON string of the app's own JSON, hence the
    // two parses. Colours are ShiftColors' bg per theme;
    // test/web_manifest_test.dart holds this table to tokens.dart.
    (function () {
      var BG = {
        dark: '#0E1628', light: '#F4F6FA',
        retro: '#0A0A0F', retroLight: '#F7F7F8'
      };
      // ShiftColors' text per theme: the ink of the loading screen's logo.
      var INK = {
        dark: '#F2F5FA', light: '#0E1628',
        retro: '#FFFFFF', retroLight: '#0A0A0F'
      };
      // The same choice AppState makes: the theme picked by hand, or,
      // following the system (a new account's default), that theme's
      // day or night partner.
      var picked = 'retro', follow = true;
      try {
        var raw = localStorage.getItem('flutter.shift.app.v1');
        var saved = raw ? JSON.parse(JSON.parse(raw)) : {};
        if (BG.hasOwnProperty(saved.theme)) picked = saved.theme;
        follow = typeof saved.themeAuto === 'boolean'
          ? saved.themeAuto : !saved.theme;
      } catch (e) { /* nothing saved, or unreadable: the default */ }
      var theme = picked;
      if (follow) {
        var night = window.matchMedia &&
          window.matchMedia('(prefers-color-scheme: dark)').matches;
        var retro = picked === 'retro' || picked === 'retroLight';
        theme = retro ? (night ? 'retro' : 'retroLight')
                      : (night ? 'dark' : 'light');
      }
      document.querySelector('link[rel="manifest"]')
        .setAttribute('href', 'manifest-' + theme + '.json');
      document.querySelector('meta[name="theme-color"]')
        .setAttribute('content', BG[theme]);
      document.documentElement.style.backgroundColor = BG[theme];
      window.__shiftBootBg = BG[theme];
      window.__shiftBootInk = INK[theme];
    })();
  </script>
  <style>
    /* ShiftColors.retro bg and text, the theme a new account opens on.
       The script above repaints both for a saved theme before the first
       paint, so the load never flashes one ground and then another. */
    html, body { margin: 0; padding: 0; height: 100%; background: #0A0A0F; }
    /* The lockup alone on the theme's ground, breathing slowly so a
       long first load on a phone still reads as alive. It used to be
       "LOADING SHIFT AI" in tracked uppercase mono, pale grey on every
       theme, which all but vanished on the light ones. */
    #boot {
      position: fixed; inset: 0; display: flex; align-items: center;
      justify-content: center; background: #0A0A0F; color: #FFFFFF;
    }
    #boot svg {
      height: 30px; width: auto;
      animation: boot-breathe 1.4s ease-in-out infinite alternate;
    }
    @keyframes boot-breathe { from { opacity: 1; } to { opacity: 0.45; } }
    @media (prefers-reduced-motion: reduce) {
      #boot svg { animation: none; }
    }
    /* Chrome for Android only draws a page under the gesture bar, in
       place of a solid bar, when the page uses this inset. Flutter paints
       on a canvas and never would, so this invisible probe does, and
       lib/util/system_bars_web.dart measures it to pad the app. */
    #shift-safe-area {
      position: fixed; left: 0; bottom: 0; width: 0;
      height: env(safe-area-inset-bottom, 0px);
      visibility: hidden; pointer-events: none;
    }
  </style>
</head>
<body>
  <div id="shift-safe-area"></div>
  <div id="boot" role="img" aria-label="ShiftAi is loading">__LOCKUP__</div>
  <script>
    document.body.style.backgroundColor = window.__shiftBootBg;
    var boot = document.getElementById('boot');
    boot.style.backgroundColor = window.__shiftBootBg;
    boot.style.color = window.__shiftBootInk;
  </script>
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
  <script>
    // There is no service worker (see the build script), so nothing else
    // notices a new build has shipped. An installed PWA that is only ever
    // resumed from the home screen, never fully reloaded, would otherwise
    // keep running whatever it first loaded, forever — reload it whenever
    // the id this page booted with no longer matches the one on the
    // server, which a fresh build always rewrites.
    (function () {
      var BUILD_ID = '__BUILD_ID__';
      function checkForUpdate() {
        fetch('build_id.txt', { cache: 'no-store' })
          .then(function (r) { return r.text(); })
          .then(function (id) {
            if (id.trim() && id.trim() !== BUILD_ID) { window.location.reload(); }
          })
          .catch(function () { /* offline, or unreachable — try again next time */ });
      }
      document.addEventListener('visibilitychange', function () {
        if (document.visibilityState === 'visible') checkForUpdate();
      });
      window.addEventListener('focus', checkForUpdate);
      // Belt and braces for a platform that resumes a frozen PWA without
      // firing either event above.
      setInterval(checkForUpdate, 5 * 60 * 1000);
    })();
  </script>
</body>
</html>
HTML

# The heredoc above is single-quoted (no shell interpolation, deliberately
# — the page's own JavaScript uses '$'-free code, but there is no reason
# to trust that forever), so the build id is spliced in afterwards.
sed -i.bak "s/__BUILD_ID__/$BUILD_ID/" index.html && rm -f index.html.bak

# The loading screen's logo is the app's own lockup, inlined so it shows
# before anything else has downloaded. Its ink becomes currentColor, which
# the boot script sets to the saved theme's text colour, as ShiftLockup
# does in Dart. The gradient "ai" badge is the brand's and stays as it is.
python3 - <<'PY'
import pathlib, re
svg = pathlib.Path('assets/assets/brand/shift-ai-lockup.svg').read_text()
svg = re.sub(r'<!--.*?-->', '', svg, flags=re.S)
assert '#F2F5FA' in svg, 'lockup ink changed; update build_web_hosted.sh'
svg = svg.replace('#F2F5FA', 'currentColor')
svg = svg.replace('<svg ', '<svg aria-hidden="true" ', 1)
page = pathlib.Path('index.html')
html = page.read_text()
assert '__LOCKUP__' in html
page.write_text(html.replace('__LOCKUP__', svg.strip()))
PY

echo "built $(find . -type f | wc -l) files, $(du -sh . | cut -f1)"
