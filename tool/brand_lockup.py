"""Build assets/brand/shift-ai-lockup.svg from the brand PDF.

The letterforms come out of the PDF as real curves — that is the whole
point of the PDF, and it is why nothing here is traced any more. The glow
does not: PDF has no blur, so the export flattened it into sixteen masked
raster images. Those are dropped and the badge is redrawn instead, as
concentric strokes at falling opacity around the same rounded rectangle
the PDF strokes for the tube core. Crisp at any size, no base64, and no
SVG masks for flutter_svg to get wrong.
"""
import pymupdf

SRC = '/root/.claude/uploads/abf10957-3aad-5655-92d3-40d2a90c812d/bdc73034-shift-ai-on-dark.pdf'
INK = '#F2F5FA'          # stand-in, swapped per theme by ShiftLockup
NEON = ('#EC01E7', '#0061F1')   # sampled off the artwork's own glow

doc = pymupdf.open(SRC)
drawings = doc[0].get_drawings()
ring = next(d for d in drawings if d['type'] == 's')
ink = next(d for d in drawings if d['type'] == 'f' and len(d['items']) > 50)

def f(v):
    return f'{v:.2f}'.rstrip('0').rstrip('.')

def subpaths(items):
    """PDF hands back a flat run of segments; a new subpath starts wherever
    one does not begin where the last ended."""
    out, cur, at = [], [], None
    for it in items:
        kind, pts = it[0], it[1:]
        start = pts[0]
        if at is None or abs(start.x - at.x) > 1e-6 or abs(start.y - at.y) > 1e-6:
            if cur: out.append(cur)
            cur = [f'M{f(start.x)},{f(start.y)}']
        if kind == 'c':
            _, c1, c2, end = pts
            cur.append(f'C{f(c1.x)},{f(c1.y)} {f(c2.x)},{f(c2.y)} {f(end.x)},{f(end.y)}')
            at = end
        elif kind == 'l':
            end = pts[1]
            cur.append(f'L{f(end.x)},{f(end.y)}')
            at = end
        else:
            raise SystemExit(f'unhandled segment {kind}')
    if cur: out.append(cur)
    return out

def bbox(d):
    import re
    xs, ys = [], []
    for m in re.finditer(r'(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)', d):
        xs.append(float(m.group(1))); ys.append(float(m.group(2)))
    return min(xs), min(ys), max(xs), max(ys)

# Centreline of the tube, and its radius from the corner curve.
rx0, ry0 = ring['items'][0][1].x, ring['items'][0][1].y
rect = ring['rect']
w = ring['width']
bx, by = rect.x0 + w/2, rect.y0 + w/2
bw, bh = rect.width - w, rect.height - w
radius = ring['items'][1][4].y - ring['items'][1][1].y

# The "ai" lives inside the badge; SHIFT is everything to its left.
paths = [''.join(sp) + 'Z' for sp in subpaths(ink['items'])]
word, ai = [], []
for d in paths:
    x0, _, _, _ = bbox(d)
    (ai if x0 > bx else word).append(d)
print(f'{len(word)} wordmark subpaths, {len(ai)} in the badge')

GLOW = 7.4                              # sampled reach beyond the centreline
bloom = [(GLOW*2, 0.10), (GLOW*1.45, 0.16), (GLOW, 0.30), (GLOW*0.58, 0.55),
         (w*1.3, 0.90)]

ix0 = min(bbox(d)[0] for d in paths); iy0 = min(bbox(d)[1] for d in paths)
ix1 = max(bbox(d)[2] for d in paths); iy1 = max(bbox(d)[3] for d in paths)
x0 = min(ix0, bx - GLOW); y0 = min(iy0, by - GLOW)
x1 = max(ix1, bx + bw + GLOW); y1 = max(iy1, by + bh + GLOW)

def rrect(sw, stroke, op=None):
    o = f' opacity="{op}"' if op is not None else ''
    return (f'    <rect x="{f(bx)}" y="{f(by)}" width="{f(bw)}" height="{f(bh)}"'
            f' rx="{f(radius)}" fill="none" stroke="{stroke}"'
            f' stroke-width="{f(sw)}"{o}/>')

L = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{f(x0)} {f(y0)} {f(x1-x0)} {f(y1-y0)}">',
     '  <!-- SHIFT ai, from the brand PDF. The letterforms are the export\'s',
     '       own curves. The glow is redrawn rather than carried over: the PDF',
     '       flattened it into masked rasters, and concentric strokes stay',
     f'       crisp at any size. Ink is {INK} throughout and is swapped for the',
     '       live theme\'s text by ShiftLockup; the neon gradient is the',
     '       brand\'s and is never themed. Groups are named because',
     '       tool/make_icons.py lifts the "ai" out of here. -->',
     '  <defs>',
     f'    <linearGradient id="neon" x1="{f(bx)}" y1="0" x2="{f(bx+bw)}" y2="0"'
     ' gradientUnits="userSpaceOnUse">',
     f'      <stop offset="0" stop-color="{NEON[0]}"/>',
     f'      <stop offset="1" stop-color="{NEON[1]}"/>',
     '    </linearGradient>',
     '  </defs>',
     f'  <g id="wordmark" fill="{INK}" fill-rule="evenodd">']
L += [f'    <path d="{d}"/>' for d in word]
L += ['  </g>', f'  <g id="ai" fill="{INK}" fill-rule="evenodd">']
L += [f'    <path d="{d}"/>' for d in ai]
L += ['  </g>', '  <g id="badge">']
L += [rrect(sw, 'url(#neon)', op) for sw, op in bloom[:-1]]
L += [rrect(bloom[-1][0], 'url(#neon)', bloom[-1][1]), rrect(w, INK)]
L += ['  </g>', '</svg>', '']
svg = '\n'.join(L)
open('shift-ai-lockup.svg','w').write(svg)
print(f'viewBox {f(x0)} {f(y0)} {f(x1-x0)} {f(y1-y0)}  ratio {(x1-x0)/(y1-y0):.6f}')
print('bytes', len(svg))
