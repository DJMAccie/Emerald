#!/usr/bin/env python3
"""Trim an installed bake's edge columns that stand over ground in the drawing.

A model can stand 1-4 px wider than its drawn wall: its first or last columns cover lawn or sand at the
wall's rows (defect_scan 'ground'). hf.build trims this for generated bakes (ground_columns); hand-adjusted
bakes cannot be regenerated, so this edits their quads directly:
  - every face of the edge strip (x < t on the left, x >= W - t on the right) whose drawing footprint is
    ground is removed;
  - the strip's side faces are removed with them, and a new side face closes the solid at the trim line,
    from its front to its back, for each height a removed front face covered, painted like the front
    face beside it.
Faces whose footprint is building (a roof drawn over the lawn: an eave) are kept.

    python3 trim_edges.py <bake.lua> <out.lua> [--max 4]
The header is kept byte for byte; only the quads change.
"""
import sys, os, re, argparse
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import bake_check as B, bldmodel as M, defect_scan as D

ap = argparse.ArgumentParser()
ap.add_argument('src'); ap.add_argument('out'); ap.add_argument('--max', type=int, default=4)
a = ap.parse_args()
info = B.parse(a.src)
x0, y0, x1, y1 = info['rect']
art = M.compose(info['pair'], info['map'], x0, y0, x1, y1)
H, W = art.shape[:2]
mask_fn, _ = D.load_mask_fn()
gcodes, bm = D.ground_colours(info, art, mask_fn)
cd = D.codes(art); op = art[..., 3] >= 128
ground = (np.isin(cd, gcodes) & op) | ~op          # ground colour, or nothing drawn
quads = [list(q) for q in info['quads']]


def footprint_ground(q):
    """True when every drawing pixel the face stands in front of is ground (bake_check's projection)."""
    f, xa, xb, ha, hb, za, zb = q[:7]
    xs = range(xa, max(xb, xa + 1)) if f in (1, 2, 3) else [min(max(xa - (1 if f == 4 else 0), 0), W - 1)]
    hs = range(ha, max(hb, ha + 1))
    d = -zb if f in (1, 3) else -za
    ok = 0
    for x in xs:
        for h in hs:
            r = (H - 1) - (h + d)
            if 0 <= r < H and 0 <= x < W:
                if not ground[r, x]:
                    return False
                ok += 1
    return ok > 0


def strip(side):
    """Edge columns, counted in from one side, whose wall rows are ground for the front faces there."""
    t = 0
    for k in range(a.max):
        x = k if side == 'L' else W - 1 - k
        fronts = [q for q in quads if q[0] == 1 and q[1] <= x < max(q[2], q[1] + 1)]
        if not fronts or not any(footprint_ground(q) for q in fronts):
            break
        t = k + 1
    return t


out = quads
for side in ('L', 'R'):
    t = strip(side)
    if not t:
        continue
    lo, hi = (0, t) if side == 'L' else (W - t, W)
    line = t if side == 'L' else W - t
    inside = lambda xa, xb: xa >= lo and max(xb, xa + 1) <= hi
    removed, keep, moved = [], [], 0
    for q in out:
        f, xa, xb = q[0], q[1], q[2]
        if f in (1, 2, 3) and inside(xa, xb) and footprint_ground(q):
            removed.append(q); continue
        keep.append(q)
    # the side faces of the strip move in to the trim line, keeping their own paint (the side's art);
    # inner side faces of the strip (facing into it) are dropped
    outer = 5 if side == 'L' else 4
    cut = set((r[3], r[4]) for r in removed if r[0] == 1)
    hs = set(h for r in removed if r[0] == 1 for h in range(r[3], max(r[4], r[3] + 1)))
    final = []
    for q in keep:
        f, xa = q[0], q[1]
        if f in (4, 5) and lo <= xa <= hi and xa != line and q[3] in hs:
            if f == outer:
                q = list(q); q[1] = q[2] = line; moved += 1
            else:
                removed.append(q); continue
        final.append(q)
    keep = final
    seen = hs
    print('%s side: %d columns, %d faces removed, %d side faces moved in' % (side, t, len(removed), moved))
    out = keep

txt = open(a.src).read()
head, rest = txt.split('quads={', 1)
tail = rest[rest.index('}'):]
nums = [str(v) for q in out for v in q]
lines = []
for i in range(0, len(nums), 60):
    lines.append('   ' + ','.join(nums[i:i + 60]) + ',')
open(a.out, 'w').write(head + 'quads={\n' + '\n'.join(lines) + '\n ' + tail)
print('%s: %d -> %d quads' % (os.path.basename(a.out), len(quads), len(out)))
