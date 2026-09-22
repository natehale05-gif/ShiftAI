#!/usr/bin/env python3
"""Writes every app icon both stores ask for, from the brand artwork.

The mark is the lockup's own lowercase "ai" — the `id="ai"` group in
assets/brand/shift-ai-lockup.svg, lifted out rather than typed in a
similar font, so the icon and the wordmark are the same drawing. It is
taken by group id and not by position, because the artwork's path count
is whatever the trace produced and a second path is not a contract.

Every icon is drawn in one of the four app themes: the glyph in that
theme's onAccent colour, on a ground of its accent. Those are the same
two tokens a filled button uses, so the pairing is one the design system
has already answered rather than a new decision made here.

    python3 tool/make_icons.py                  # the default theme
    python3 tool/make_icons.py --theme dark     # ship a different one
    python3 tool/make_icons.py --list           # what the four look like

All four are always written to store/icon-themes/ for brand use. Only the
chosen one is installed as the app icon, because a launcher icon is a
single fixed asset — it cannot follow the theme the person picks inside
the app.

Writes:
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png   every size in Contents.json
  android/app/src/main/res/mipmap-*/ic_launcher.png     legacy launcher
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
  android/app/src/main/res/values/ic_launcher_background.xml
  web/icons/Icon-{192,512}.png                 PWA
  web/icons/Icon-maskable-{192,512}.png        PWA, safe-zone crop
  web/favicon.png                              browser tab
  web/manifest.json                            background and theme colour
  store/icon-1024.png            App Store  (no alpha)
  store/icon-512.png             Play       (alpha allowed)
  store/feature-graphic.png      Play       1024x500
  store/icon-themes/icon-1024-<theme>.png    all four
"""
import argparse
import json
import os
import re
import sys

try:
    import cairosvg
    import numpy as np
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    sys.exit("needs: pip install pillow cairosvg numpy")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, "assets/brand/shift-ai-lockup.svg")
# The ink the artwork is drawn in, swapped out per theme. Matches
# ShiftLockup._artInk in lib/widgets/common.dart.
ART_INK = "#F2F5FA"

# Straight off ShiftColors in lib/theme/tokens.dart. Keep them in step: a
# colour that drifts here makes the installed icon disagree with the app
# that opens behind it.
THEMES = {
    "dark": {"bg": "#0E1628", "text": "#F2F5FA", "accent": "#5B8CFF",
             "onAccent": "#0E1628"},
    "light": {"bg": "#F4F6FA", "text": "#0E1628", "accent": "#1F5AE6",
              "onAccent": "#FFFFFF"},
    "retro": {"bg": "#0A0A0F", "text": "#FFFFFF", "accent": "#FF1A8C",
              "onAccent": "#0A0A0F"},
    "retroLight": {"bg": "#F7F7F8", "text": "#0A0A0F", "accent": "#C4005F",
                   "onAccent": "#FFFFFF"},
}

# The theme a new account opens on, per ShiftThemeIdLabel.parse.
DEFAULT_THEME = "retro"

# Android adaptive icons are masked to the centre 66 of a 108 canvas.
ADAPTIVE_SAFE = 66 / 108


def _rgb(hex_colour):
    h = hex_colour.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _luminance(rgb):
    def channel(c):
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    """WCAG contrast ratio between two hex colours."""
    la, lb = _luminance(_rgb(a)), _luminance(_rgb(b))
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def _art():
    return open(BRAND).read()


def _view_box():
    m = re.search(r'viewBox="([-\d.\s]+)"', _art())
    return [float(v) for v in m.group(1).split()]


def _group(name):
    """One named group of the lockup, as (transform, inner markup)."""
    svg = _art()
    m = re.search(
        r'<g id="%s"(?:\s+transform="([^"]*)")?[^>]*>(.*?)</g>' % name,
        svg, re.S)
    if m is None:
        sys.exit(f"the lockup has no group id=\"{name}\": has it been redrawn?")
    return m.group(1) or "", m.group(2)


def glyph(box_px, colour="#FFFFFF"):
    """The lockup's lowercase "ai", cropped tight, scaled to fit box_px.

    Both letters are kept, the i's tittle included — unlike the S this
    replaced, which had to be split off at the first gap in S-H-I-F-T.
    """
    transform, inner = _group("ai")
    vx, vy, vw, vh = _view_box()
    # Render large, then crop and scale down: the glyph's ink does not
    # reach the edges of the viewBox, so its true size is only known
    # after rasterising.
    scale = (box_px * 3) / vh
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vx} {vy} {vw} {vh}" '
        f'width="{int(vw * scale)}" height="{int(vh * scale)}">'
        f'<g transform="{transform}" fill="{colour}">{inner}</g></svg>'
    )
    tmp = os.path.join(ROOT, "build", "_glyph.png")
    os.makedirs(os.path.dirname(tmp), exist_ok=True)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=tmp)
    im = Image.open(tmp).convert("RGBA")
    alpha = np.array(im)[:, :, 3]
    xs = np.where((alpha > 40).any(axis=0))[0]
    ys = np.where((alpha > 40).any(axis=1))[0]
    out = im.crop((xs[0], ys[0], xs[-1] + 1, ys[-1] + 1))
    os.remove(tmp)

    # Fit inside the box on whichever axis binds, so the mark never
    # overflows and never changes shape.
    w, h = out.size
    factor = min(box_px / w, box_px / h)
    return out.resize((max(1, round(w * factor)), max(1, round(h * factor))),
                      Image.LANCZOS)


def ground(size, theme):
    """Accent, deepening downward — enough to have a light source, not so
    much that it reads as a gradient at 40px."""
    top = _rgb(THEMES[theme]["accent"])
    bottom = tuple(round(c * 0.86) for c in top)
    im = Image.new("RGB", (size, size), top)
    draw = ImageDraw.Draw(im)
    for y in range(size):
        t = y / max(1, size - 1)
        draw.line(
            [(0, y), (size, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)),
        )
    return im


def _centre(base, mark, lift=0.0):
    w, h = mark.size
    base.paste(
        mark,
        ((base.size[0] - w) // 2, int((base.size[1] - h) / 2 - base.size[1] * lift)),
        mark,
    )
    return base


def master(theme, size=1024):
    """The full-bleed icon: the "ai" in onAccent on the accent ground. No
    transparency, no rounded corners — both platforms mask it themselves."""
    mark = glyph(int(size * 0.52), THEMES[theme]["onAccent"])
    return _centre(ground(size, theme), mark)


def adaptive_foreground(theme, size=1024):
    """Android's foreground layer: the mark alone, inside the safe circle,
    on transparency. The background layer is a flat colour."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mark = glyph(int(size * 0.58 * ADAPTIVE_SAFE), THEMES[theme]["onAccent"])
    return _centre(im, mark)


def maskable(theme, size=512):
    """The web manifest's maskable icon.

    A maskable icon is cropped by the browser to whatever shape the
    platform wants, and only the centre circle of 80% diameter is
    guaranteed to survive. The mark is therefore smaller than the
    full-bleed icon's, on the same opaque ground — a maskable icon with
    transparent corners gets them filled with black."""
    mark = glyph(int(size * 0.46), THEMES[theme]["onAccent"])
    return _centre(ground(size, theme), mark)


def feature_graphic(theme, w=1024, h=500):
    """Play's header image: the whole lockup on the app's own ground."""
    t = THEMES[theme]
    im = Image.new("RGB", (w, h), _rgb(t["bg"]))
    vx, vy, vw, vh = _view_box()
    scale = (w * 0.62) / vw
    # The whole lockup, inked to the theme exactly as the app inks it. The
    # badge keeps the brand gradient, so this is the real mark rather than
    # a two-tone reconstruction of it.
    svg = (
        _art()
        .replace(ART_INK, t["text"])
        .replace("<svg ", f'<svg width="{int(vw * scale)}" '
                          f'height="{int(vh * scale)}" ', 1)
    )
    tmp = os.path.join(ROOT, "build", "_lockup.png")
    os.makedirs(os.path.dirname(tmp), exist_ok=True)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=tmp)
    mark = Image.open(tmp).convert("RGBA")
    im.paste(mark, ((w - mark.size[0]) // 2, (h - mark.size[1]) // 2), mark)
    os.remove(tmp)
    return im


def install(theme):
    """Write the chosen theme's icon into both platforms and store/."""
    m = master(theme, 1024)

    # --- iOS: every filename Contents.json names -------------------------
    ios = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    meta = json.load(open(os.path.join(ios, "Contents.json")))
    for entry in meta["images"]:
        name = entry.get("filename")
        if not name:
            continue
        pt = float(entry["size"].split("x")[0])
        px = round(pt * float(entry["scale"].rstrip("x")))
        m.resize((px, px), Image.LANCZOS).save(os.path.join(ios, name))
    print(f"ios: {len(meta['images'])} icons")

    # --- Android ---------------------------------------------------------
    res = os.path.join(ROOT, "android/app/src/main/res")
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    fg = adaptive_foreground(theme, 1024)
    for bucket, px in legacy.items():
        folder = os.path.join(res, f"mipmap-{bucket}")
        os.makedirs(folder, exist_ok=True)
        m.resize((px, px), Image.LANCZOS).save(
            os.path.join(folder, "ic_launcher.png")
        )
        # The adaptive foreground is drawn on a 108dp canvas.
        side = round(px * 108 / 48)
        fg.resize((side, side), Image.LANCZOS).save(
            os.path.join(folder, "ic_launcher_foreground.png")
        )
    print(f"android: {len(legacy) * 2} icons")

    anydpi = os.path.join(res, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        open(os.path.join(anydpi, name), "w").write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background"/>\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            '    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>\n'
            "</adaptive-icon>\n"
        )
    values = os.path.join(res, "values")
    os.makedirs(values, exist_ok=True)
    open(os.path.join(values, "ic_launcher_background.xml"), "w").write(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">'
        f'{THEMES[theme]["accent"]}</color>\n</resources>\n'
    )

    # --- Web -------------------------------------------------------------
    # The PWA icons and the tab favicon. These were still Flutter's
    # template — a blue Flutter logo — because this script only ever wrote
    # the two native platforms.
    web = os.path.join(ROOT, "web")
    icons = os.path.join(web, "icons")
    os.makedirs(icons, exist_ok=True)
    for px in (192, 512):
        m.resize((px, px), Image.LANCZOS).save(
            os.path.join(icons, f"Icon-{px}.png")
        )
        maskable(theme, 1024).resize((px, px), Image.LANCZOS).save(
            os.path.join(icons, f"Icon-maskable-{px}.png")
        )
    # Flutter's template favicon is 16px, which is soft on a hidpi tab.
    m.resize((64, 64), Image.LANCZOS).save(os.path.join(web, "favicon.png"))
    print("web: 4 icons, favicon")

    # The manifest's colours are the splash the browser paints before the
    # app has drawn anything, so they follow the installed icon's theme.
    # Left behind, they flash the old theme's ground on every cold load.
    manifest_path = os.path.join(web, "manifest.json")
    manifest = json.load(open(manifest_path))
    manifest["background_color"] = THEMES[theme]["bg"]
    manifest["theme_color"] = THEMES[theme]["bg"]
    with open(manifest_path, "w") as fh:
        json.dump(manifest, fh, indent=4)
        fh.write("\n")
    print(f"web: manifest colours -> {THEMES[theme]['bg']}")

    # --- Store listings --------------------------------------------------
    store = os.path.join(ROOT, "store")
    os.makedirs(store, exist_ok=True)
    m.save(os.path.join(store, "icon-1024.png"))  # App Store, opaque
    m.resize((512, 512), Image.LANCZOS).save(os.path.join(store, "icon-512.png"))
    feature_graphic(theme).save(os.path.join(store, "feature-graphic.png"))
    print("store: icon-1024, icon-512, feature-graphic")


def write_all_themes():
    """Every theme's icon, for brand use and for comparing them."""
    out = os.path.join(ROOT, "store", "icon-themes")
    os.makedirs(out, exist_ok=True)
    for name in THEMES:
        master(name, 1024).save(os.path.join(out, f"icon-1024-{name}.png"))
        master(name, 256).save(os.path.join(out, f"icon-256-{name}.png"))
    print(f"store/icon-themes: {len(THEMES) * 2} icons")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--theme", choices=sorted(THEMES), default=DEFAULT_THEME,
                    help=f"which theme to install as the app icon "
                         f"(default: {DEFAULT_THEME})")
    ap.add_argument("--list", action="store_true",
                    help="print each theme's colours and contrast, write "
                         "nothing but store/icon-themes")
    args = ap.parse_args()

    # The App Store rejects a 1024 with an alpha channel, and a mark that
    # cannot be read at 40px is no icon at all. Both are cheap to check.
    for name, t in THEMES.items():
        ratio = contrast(t["onAccent"], t["accent"])
        print(f"{name:11} {t['accent']} ground, {t['onAccent']} mark "
              f"— contrast {ratio:.1f}:1")
        if ratio < 4.5:
            sys.exit(f"{name}: {ratio:.1f}:1 is below 4.5:1 — the mark would "
                     f"be hard to read at launcher size")

    write_all_themes()
    if args.list:
        return
    print(f"\ninstalling the {args.theme} icon")
    install(args.theme)


if __name__ == "__main__":
    main()
