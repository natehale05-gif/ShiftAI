#!/usr/bin/env python3
"""Writes every app icon both stores ask for, from the brand artwork.

The letter is the SHIFT wordmark's own S — lifted out of
assets/brand/shift-ai-on-dark.svg rather than typed in a similar font, so
the icon and the lockup are the same drawing.

    python3 tool/make_icons.py

Writes:
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png   every size in Contents.json
  android/app/src/main/res/mipmap-*/ic_launcher.png     legacy launcher
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
  android/app/src/main/res/values/ic_launcher_background.xml
  store/icon-1024.png        App Store  (no alpha)
  store/icon-512.png         Play       (alpha allowed)
  store/feature-graphic.png  Play       1024x500
"""
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
BRAND = os.path.join(ROOT, "assets/brand/shift-ai-on-dark.svg")

# Straight off ShiftColors.dark — the icon and the app open the same colour.
ACCENT = (91, 140, 255)
ACCENT_DEEP = (63, 111, 224)
BG = (14, 22, 40)
WHITE = (255, 255, 255)

# Android adaptive icons are masked to the centre 66 of a 108 canvas.
ADAPTIVE_SAFE = 66 / 108


def _paths():
    svg = open(BRAND).read()
    return re.findall(r'd="([^"]+)"', svg)


def letter(height_px, color="#FFFFFF"):
    """The wordmark's S, cropped tight, at the height asked for."""
    d = _paths()[0]
    scale = height_px / 68.0  # 68 is the S's cap height in viewBox units
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 589.6 71.55" '
        f'width="{int(589.6 * scale)}" height="{int(71.55 * scale)}">'
        f'<g transform="translate(0,1.38)"><path d="{d}" fill="{color}"/></g></svg>'
    )
    tmp = os.path.join(ROOT, "build", "_glyph.png")
    os.makedirs(os.path.dirname(tmp), exist_ok=True)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=tmp)
    im = Image.open(tmp).convert("RGBA")
    alpha = np.array(im)[:, :, 3]
    xs = np.where((alpha > 40).any(axis=0))[0]
    ys = np.where((alpha > 40).any(axis=1))[0]
    # Everything after the first gap is H-I-F-T; keep only the S.
    gaps = np.where(np.diff(xs) > 3)[0]
    x1 = xs[gaps[0]] if len(gaps) else xs[-1]
    out = im.crop((xs[0], ys[0], x1 + 1, ys[-1] + 1))
    os.remove(tmp)
    return out


def ground(size):
    """Accent, deepening downward — enough to have a light source, not so
    much that it reads as a gradient at 40px."""
    im = Image.new("RGB", (size, size), ACCENT)
    top, bottom = ACCENT, ACCENT_DEEP
    draw = ImageDraw.Draw(im)
    for y in range(size):
        t = y / max(1, size - 1)
        draw.line(
            [(0, y), (size, y)],
            fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)),
        )
    return im


def _centre(base, glyph, lift=0.0):
    w, h = glyph.size
    base.paste(
        glyph,
        ((base.size[0] - w) // 2, int((base.size[1] - h) / 2 - base.size[1] * lift)),
        glyph,
    )
    return base


def master(size=1024):
    """The full-bleed icon: white S on accent. No transparency, no rounded
    corners — both platforms mask it themselves."""
    # Lifted a touch: the S's optical centre sits below its box centre.
    return _centre(ground(size), letter(int(size * 0.60)), lift=0.005)


def adaptive_foreground(size=1024):
    """Android's foreground layer: the S alone, inside the safe circle, on
    transparency. The background layer is a flat colour."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    return _centre(im, letter(int(size * 0.68 * ADAPTIVE_SAFE)), lift=0.005)


def feature_graphic(w=1024, h=500):
    """Play's header image: the whole lockup on the app's own ground."""
    im = Image.new("RGB", (w, h), BG)
    d = _paths()
    scale = (w * 0.62) / 589.6
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 589.6 71.55" '
        f'width="{int(589.6 * scale)}" height="{int(71.55 * scale)}">'
        '<g transform="translate(0,1.38)">'
        f'<path d="{d[0]}" fill="#F2F5FA"/>'
        # The divider between SHIFT and ai is a rect in the artwork.
        '<rect x="448.2" y="-1.38" width="6.0" height="71.55" fill="#5B8CFF"/>'
        f'<path d="{d[1]}" fill="#5B8CFF"/>'
        "</g></svg>"
    )
    tmp = os.path.join(ROOT, "build", "_lockup.png")
    os.makedirs(os.path.dirname(tmp), exist_ok=True)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=tmp)
    mark = Image.open(tmp).convert("RGBA")
    im.paste(mark, ((w - mark.size[0]) // 2, (h - mark.size[1]) // 2), mark)
    os.remove(tmp)
    return im


def main():
    m = master(1024)

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
    fg = adaptive_foreground(1024)
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
        '    <color name="ic_launcher_background">#5B8CFF</color>\n</resources>\n'
    )

    # --- Store listings --------------------------------------------------
    store = os.path.join(ROOT, "store")
    os.makedirs(store, exist_ok=True)
    m.save(os.path.join(store, "icon-1024.png"))  # App Store, opaque
    m.resize((512, 512), Image.LANCZOS).save(os.path.join(store, "icon-512.png"))
    feature_graphic().save(os.path.join(store, "feature-graphic.png"))
    print("store: icon-1024, icon-512, feature-graphic")


if __name__ == "__main__":
    main()
