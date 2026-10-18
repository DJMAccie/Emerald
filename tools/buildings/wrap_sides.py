#!/usr/bin/env python3
"""Repaint a bake's stretched side bands with the front's own art at that height, wrapped round the corner.

defect_scan 'stretch' flags a side run that carries one colour of the south face at its edge back over
12+ px of depth, in a band of 4+ heights: one front colour smeared backwards. This repaints each flagged
side face cell by cell: the cell t px back from the corner takes the paint of the front face t px in from
that corner at the same height (mirrored at the end of the corner's wall segment: up to the first dark
column, an outline, door or frame, so a door is never carried round), so the side
reads as the front's pattern carried round the building -- glass panels, frames, wall shading -- instead
of a plain slab. Geometry is unchanged; equal-paint cells are merged again.

    python3 wrap_sides.py <bake.lua> <out.lua>
The header is kept byte for byte; only the quads change.
"""
import sys, os
from collections import defaultdict
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import bake_check as B, defect_scan as D

src, dst = sys.argv[1], sys.argv[2]
info = B.parse(src); info['path'] = src
mask_fn, _ = D.load_mask_fn()
res = D.scan(info, mask_fn)
flag = sorted(res['faults']['stretch'])
if not flag:
    print('no stretch faces'); sys.exit(1)
quads = [list(q) for q in info['quads']]

# frontmost south face per (x, h)
front = {}
for i, q in enumerate(quads):
    if q[0] != 1: continue
    for x in range(q[1], q[2]):
        for h in range(q[3], q[4]):
            if (x, h) not in front or -q[5] < -quads[front[(x, h)]][5]:
                front[(x, h)] = i

import bldmodel as M
x0, y0, x1, y1 = info['rect']
ART = M.compose(info['pair'], info['map'], x0, y0, x1, y1)
DARK = 0.35


def lum(q):
    r, g, b = ART[min(max(q[8], 0), ART.shape[0] - 1), min(max(q[7], 0), ART.shape[1] - 1), :3] / 255.0
    return 0.299 * r + 0.587 * g + 0.114 * b


out_add = []
drop = set()
n_cells = 0
for i in flag:
    q = quads[i]
    f, xa, xb, ha, hb, za, zb = q[:7]
    if f not in (4, 5): continue
    col = xa - 1 if f == 4 else xa                     # the drawing column at this side's edge
    inward = -1 if f == 4 else 1                       # east side: walk west along the front
    cells = []
    for h in range(ha, max(hb, ha + 1)):
        row = sorted(x for (x, hh) in front if hh == h)
        if not row: continue
        lo, hi = row[0], row[-1]
        # the wrap stays on the wall segment at this corner: from the edge in to the first dark column (an
        # outline, a door, a window frame), so a door is never carried round; a segment under 3 px wraps
        # the whole row instead
        seg = 0
        x = min(max(col, lo), hi)
        while lo <= x <= hi and (x, h) in front and lum(quads[front[(x, h)]]) >= DARK:
            seg += 1; x += inward
        if seg >= 3:
            if inward < 0: lo = col - seg + 1
            else: hi = col + seg - 1
        span = hi - lo + 1
        for z in range(za, zb):                        # z cells [z, z+1), front edge at zb
            t = zb - 1 - z                             # px back from the corner
            k = t % (2 * span)
            k = k if k < span else 2 * span - 1 - k    # mirror at the far end
            x = col + inward * k
            x = min(max(x, lo), hi)
            j = front.get((x, h))
            if j is None:
                j = front.get((col, h), i)
            cells.append((h, z, quads[j][7], quads[j][8]))
    drop.add(i)
    # merge along the depth, then emit one quad per run (one height each)
    cells.sort()
    run = None
    for h, z, px, py in cells:
        if run and run[0] == h and run[2] == z and (run[3], run[4]) == (px, py):
            run[2] = z + 1; continue
        if run: out_add.append([f, xa, xa, run[0], run[0] + 1, run[1], run[2], run[3], run[4], q[9] if len(q) > 9 else 0])
        run = [h, z, z + 1, px, py]
        n_cells += 1
    if run: out_add.append([f, xa, xa, run[0], run[0] + 1, run[1], run[2], run[3], run[4], q[9] if len(q) > 9 else 0])

out = [q for k, q in enumerate(quads) if k not in drop] + out_add
txt = open(src).read()
head, rest = txt.split('quads={', 1)
tail = rest[rest.index('}'):]
nums = [str(v) for q in out for v in q]
lines = ['   ' + ','.join(nums[i:i + 60]) + ',' for i in range(0, len(nums), 60)]
open(dst, 'w').write(head + 'quads={\n' + '\n'.join(lines) + '\n ' + tail)
print('%s: %d stretch faces repainted as %d runs; %d -> %d quads' % (
    os.path.basename(dst), len(drop), len(out_add), len(quads), len(out)))
