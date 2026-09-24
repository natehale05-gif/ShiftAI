#!/usr/bin/env bash
# Builds the web app for a static host that only serves common web file
# types (no custom MIME types).
#
#   - --no-web-resources-cdn keeps CanvasKit local, so the app makes no
#     outbound request at all. Fonts are bundled too.
#   - Debug symbol maps and the skwasm renderer are dropped; the JS build
#     only ever loads canvaskit.
#   - Flutter's own service worker is removed: it served a stale cache.
#     offline_worker.js replaces it: this build's files from this build's
#     cache at once, the page from the network if it answers within 2 s
#     and from its last copy otherwise. A new build clears the old cache.
#     Only the build's own files are cached (listed at the end); the API
#     and everything else on the origin go straight to the network.
#   - AssetManifest.bin is copied to a .wasm name and a small shim in
#     index.html points the engine at it, because hosts that allow-list
#     extensions do not serve .bin.
#   - A build id (the git commit, so it is unique per deploy) is baked
#     into the page and polled for while the app is open, because nothing
#     else notices a new build has shipped: an installed PWA that is only
#     ever resumed, never fully reloaded, would otherwise run whatever it
#     first loaded forever. The offline worker never caches it.
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

cat > offline_worker.js <<'JS'
// The app's files come from this build's own cache, straight away; only
// the page itself asks the network first, and not for long.
//
// It used to be network first for everything, with no time limit. Every
// open waited on the network for all ~3.8 MB (CanvasKit, main.dart.js,
// fonts) even when a copy was sitting in the cache, and on a weak signal
// one request that stalled, never failing and never finishing, left the
// page on its loading screen for good.
//
// The cache is named after the build, so a cached main.dart.js can never
// be served beside a newer page: a new deploy ships a new worker (this
// file changes with the build id), which clears the old build's cache as
// it takes over. build_id.txt is never cached; it is how the page
// notices a new build.
//
// Only this build's own files are cached, by name (FILES, written in when
// the build finishes). Everything else on this origin goes to the network
// untouched. It used to cache every GET here, and Rex's preview serves
// the API from the same origin as the page, so /v1/vault, /v1/avatars,
// /v1/threads and /v1/me were answered from their first copy until the
// next deploy: a new image never reached the vault, a training avatar
// never finished, and since a cache match ignores the Authorization
// header, the next account signed in on that browser would have been
// handed this one's.
var BUILD = '__BUILD_ID__';
var FILES = new Set(__FILES__);
var KEEP = 'shiftai-' + BUILD;
// How long the page waits on the network before opening on its last copy.
var PAGE_WAIT_MS = 2000;

self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
  event.waitUntil(caches.keys().then(function (names) {
    return Promise.all(names.map(function (name) {
      if (name.indexOf('shiftai') === 0 && name !== KEEP) {
        return caches.delete(name);
      }
    }));
  }).then(function () { return self.clients.claim(); }));
});

// The page's list of files it fetched before this worker controlled it.
self.addEventListener('message', function (event) {
  var urls = ((event.data && event.data.keep) || []).filter(function (u) {
    var rel = ours(u);
    return rel !== null && (rel === '' || FILES.has(rel));
  });
  event.waitUntil(caches.open(KEEP).then(function (cache) {
    return Promise.all(urls.map(function (u) {
      return cache.match(u, { ignoreSearch: true }).then(function (hit) {
        return hit || cache.add(u).catch(function () {});
      });
    }));
  }));
});

// [u]'s path under this worker's scope, query left off, or null for
// anything outside it.
function ours(u) {
  var scope = new URL(self.registration.scope);
  var url = new URL(u, scope);
  if (url.origin !== scope.origin) return null;
  if (url.pathname.indexOf(scope.pathname) !== 0) return null;
  return url.pathname.slice(scope.pathname.length);
}

function keep(cache, req, res) {
  if (res && res.ok) cache.put(req, res.clone());
  return res;
}

// A file of this build: the cached copy if there is one, else the network.
function fromBuild(req) {
  return caches.open(KEEP).then(function (cache) {
    return cache.match(req, { ignoreSearch: true }).then(function (hit) {
      return hit || fetch(req).then(function (res) {
        return keep(cache, req, res);
      });
    });
  });
}

// The page: the network if it answers within PAGE_WAIT_MS, else the last
// copy, so a new build is picked up when the signal allows and the app
// still opens when it does not.
function page(req) {
  return caches.open(KEEP).then(function (cache) {
    var network = fetch(req).then(function (res) { return keep(cache, req, res); });
    var cached = cache.match(req, { ignoreSearch: true }).then(function (hit) {
      return hit || cache.match('./', { ignoreSearch: true });
    }).then(function (hit) {
      return hit || cache.match('index.html', { ignoreSearch: true });
    });
    var late = new Promise(function (resolve) {
      setTimeout(function () {
        cached.then(function (hit) { if (hit) resolve(hit); });
      }, PAGE_WAIT_MS);
    });
    return Promise.race([
      network.catch(function () {
        return cached.then(function (hit) { return hit || Response.error(); });
      }),
      late,
    ]);
  });
}

self.addEventListener('fetch', function (event) {
  var req = event.request;
  if (req.method !== 'GET') return;
  var rel = ours(req.url);
  if (rel === null) return;
  if (req.mode === 'navigate' || rel === '' || rel === 'index.html') {
    event.respondWith(page(req));
  } else if (FILES.has(rel)) {
    event.respondWith(fromBuild(req));
  }
  // Anything else (the API, a vault file, build_id.txt) is the network's.
});
JS
sed -i "s/__BUILD_ID__/${BUILD_ID}/" offline_worker.js

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
    // Offline, and fast. The worker serves this build's files from its
    // cache and the page from the network when it answers in time. On
    // the very first visit the page loads
    // before the worker controls it, so once the app has drawn, the page
    // hands the worker the list of files it fetched and the worker keeps
    // a copy. The next open with no network then comes from that copy.
    (function () {
      if (!('serviceWorker' in navigator)) return;
      navigator.serviceWorker.register('offline_worker.js').catch(function () {});
      window.addEventListener('flutter-first-frame', function () {
        setTimeout(function () {
          var here = location.origin;
          var urls = performance.getEntriesByType('resource')
            .map(function (e) { return e.name.split('#')[0]; })
            .filter(function (u) {
              return u.indexOf(here) === 0 && u.indexOf('build_id.txt') < 0;
            });
          urls.push(location.href.split('#')[0]);
          navigator.serviceWorker.ready.then(function (reg) {
            if (reg.active) reg.active.postMessage({ keep: urls });
          });
        }, 1500);
      });
    })();
  </script>
  <script>
    // The offline worker never caches build_id.txt (see the build script),
    // and nothing else
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

# The worker caches these files and nothing else. Written last, so the
# list is exactly what ships. The page and the worker are handled on their
# own, and build_id.txt is never cached.
python3 - <<'PY'
import json, pathlib
skip = {'index.html', 'offline_worker.js', 'build_id.txt'}
files = sorted(
    p.as_posix() for p in pathlib.Path('.').rglob('*')
    if p.is_file() and p.as_posix() not in skip
)
worker = pathlib.Path('offline_worker.js')
js = worker.read_text()
assert '__FILES__' in js, 'file list placeholder missing from the worker'
worker.write_text(js.replace('__FILES__', json.dumps(files)))
PY

echo "built $(find . -type f | wc -l) files, $(du -sh . | cut -f1)"
