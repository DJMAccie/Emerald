#!/usr/bin/env python3
"""Carve a bake's plan corners back where the drawing shows ground at the building's foot.

The art often draws a building with chamfered or rounded plan corners (the contest lobby's octagon, the
Fallarbor tent's dome, the league's east wall turning away): at the drawing's bottom rows the corner
columns show lawn or sand. A bake built as a box stands a square corner there, its front faces over the
drawn ground (defect_scan 'ground'). trim_edges.py removes whole edge columns 1-4 px wide; this sets each
corner column back in plan instead, by as many px as the drawing shows ground at its foot:

  - the bake is voxelized (south/north faces bound each (x, h) row along the depth), so the solid is known;
  - column x loses its solid at depths < c(x), at every height, where c(x) is the run of ground pixels at the
    bottom of the drawing's column x (only columns whose old front face at h=0 stands over that ground);
  - faces of the solid that survive keep their quad and paint; faces the carve exposes are added: the new
    front of a column takes the paint the old front had at the same (x, h), so a wall's art moves back with
    it instead of shifting; a new side face (a step between columns set back by different depths) takes
    the paint of the front face beside it.

    python3 carve_corners.py <bake.lua> <out.lua> [--max 24] [--x0 A --x1 B] [--hmax H]
--x0/--x1 limit the carve to drawing columns [A, B); --hmax H carves only heights below H (a recessed ground
floor under a storey that stays: its ceiling is closed in the --under shade, percent). The header is kept byte for byte; only the quads change.
"""
import sys, os, argparse
from collections import defaultdict
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import bake_check as B, bldmodel as M, defect_scan as D

ap = argparse.ArgumentParser()
ap.add_argument('src'); ap.add_argument('out')
ap.add_argument('--max', type=int, default=24)
ap.add_argument('--hmax', type=int, default=None)
ap.add_argument('--under', type=int, default=55)
ap.add_argument('--x0', type=int, default=None); ap.add_argument('--x1', type=int, default=None)
a = ap.parse_args()
info = B.parse(a.src)
x0, y0, x1, y1 = info['rect']
art = M.compose(info['pair'], info['map'], x0, y0, x1, y1)
H, W = art.shape[:2]
mask_fn, _ = D.load_mask_fn()
gcodes, _ = D.ground_colours(info, art, mask_fn)
cd = D.codes(art); op = art[..., 3] >= 128
ground = (np.isin(cd, gcodes) & op) | ~op
quads = [list(q) for q in info['quads']]

XM = max(max(q[1], q[2]) for q in quads) + 2
HM = max(max(q[3], q[4]) for q in quads) + 2
DM = max(-min(q[5], q[6]) for q in quads) + 2

# ---- unit faces of the input: key (f, x, h, k) -> (quad index); f 1 south, 2 north, 3 top, 4 east, 5 west
# (x, h, k are the cell the face belongs to: the solid cell behind it)
unit = {}
def cells(q):
    f, xa, xb, ha, hb, za, zb = q[:7]
    if f == 1:
        k = -zb
        return [(f, x, h, k) for x in range(xa, xb) for h in range(ha, hb)]
    if f == 2:
        k = -za - 1
        return [(f, x, h, k) for x in range(xa, xb) for h in range(ha, hb)]
    if f == 3:
        return [(f, x, ha - 1, k) for x in range(xa, xb) for k in range(-zb, -za)]
    if f == 4:
        return [(f, xa - 1, h, k) for h in range(ha, hb) for k in range(-zb, -za)]
    return [(f, xa, h, k) for h in range(ha, hb) for k in range(-zb, -za)]

for i, q in enumerate(quads):
    for c in cells(q):
        unit[c] = i

# ---- solid by parity along the depth: a south face opens a run, a north face closes it
S = np.zeros((XM, HM, DM), bool)
opens = defaultdict(list); closes = defaultdict(list)
for (f, x, h, k) in unit:
    if f == 1: opens[(x, h)].append(k)
    elif f == 2: closes[(x, h)].append(k)
bad = 0
for xh, ks in opens.items():
    ce = sorted(closes.get(xh, []))
    for k in sorted(ks):
        e = next((c for c in ce if c >= k), None)
        if e is None: bad += 1; continue
        S[xh[0], xh[1], k:e + 1] = True

def boundary(S):
    out = set()
    xs, hs, ks = np.nonzero(S)
    P = np.pad(S, 1)
    for x, h, k in zip(xs, hs, ks):
        X, Hh, K = x + 1, h + 1, k + 1
        if not P[X, Hh, K - 1]: out.add((1, x, h, k))
        if not P[X, Hh, K + 1]: out.add((2, x, h, k))
        if not P[X, Hh + 1, K]: out.add((3, x, h, k))
        if not P[X + 1, Hh, K]: out.add((4, x, h, k))
        if not P[X - 1, Hh, K]: out.add((5, x, h, k))
    return out

B0 = boundary(S)
U0 = set(unit)
print('voxels %d, unpaired runs %d; faces from solid %d, from quads %d, common %d' %
      (int(S.sum()), bad, len(B0), len(U0), len(B0 & U0)))

# ---- carve depth per drawing column
front = {}                                   # (x, h) -> k of the frontmost south face, and its quad
for (f, x, h, k), i in unit.items():
    if f == 1 and ((x, h) not in front or k < front[(x, h)][0]):
        front[(x, h)] = (k, i)
cdep = {}
lo = a.x0 if a.x0 is not None else 0
hi = a.x1 if a.x1 is not None else W
for x in range(max(lo, 0), min(hi, W)):
    c = 0
    while c < a.max and c < H and ground[H - 1 - c, x]:
        c += 1
    if c and (x, 0) in front and front[(x, 0)][0] < c:
        cdep[x] = c
if not cdep:
    print('nothing to carve'); sys.exit(1)
print('carve columns', min(cdep), '-', max(cdep), 'depths', dict(sorted(cdep.items())))

S2 = S.copy()
for x, c in cdep.items():
    S2[x, :a.hmax, :c] = False
B1 = boundary(S2)

# ---- re-mesh: quads whose unit faces all survive stay as they were; the rest are cut into the
# surviving unit faces; new faces get paint
keep_q = set()
partial = defaultdict(list)
byq = defaultdict(list)
for c, i in unit.items():
    byq[i].append(c)
for i, cs in byq.items():
    alive = [c for c in cs if c in B1]
    if len(alive) == len(cs):
        keep_q.add(i)
    elif alive:
        partial[i] = alive
new = sorted(B1 - U0)

def paint_front(x, h):
    """Paint of the old front face at (x, h), or the nearest one up/down the same column."""
    for dh in range(0, HM):
        for hh in (h - dh, h + dh):
            if (x, hh) in front:
                q = quads[front[(x, hh)][1]]
                return q[7], q[8], q[9] if len(q) > 9 else 0
    return 0, 0, 0

units = []                                   # (f, x, h, k, px, py, sh)
for i, cs in partial.items():
    q = quads[i]
    for c in cs:
        units.append(c + (q[7], q[8], q[9] if len(q) > 9 else 0))
nf = defaultdict(int)
for c in new:
    f, x, h, k = c
    if f in (1, 4, 5):
        px, py, sh = paint_front(x, h)
    else:                                    # a north or top face the carve exposed (should not happen)
        px, py, sh = paint_front(x, h)
    nf[f] += 1
    units.append(c + (px, py, sh))
# a carve under a kept storey (--hmax) leaves that storey overhanging: close it with a ceiling, a top-type
# face at the carve's height (meshes are drawn without culling) in the underside shade, painted like the
# wall above it
if a.hmax:
    for x, c in cdep.items():
        for k in range(c):
            if S[x, a.hmax, k] and S2[x, a.hmax, k]:
                px, py, _ = paint_front(x, a.hmax)
                units.append((3, x, a.hmax - 1, k, px, py, a.under))
                nf['ceiling'] += 1
print('kept quads %d, cut quads %d, new unit faces %s' % (len(keep_q), len(partial), dict(nf)))

# merge equal-paint unit faces of one plane into rectangles (greedy: along the first axis, then the second)
def axes(u):
    f, x, h, k = u[:4]
    if f in (1, 2): return (f, k), x, h
    if f == 3: return (f, h), x, k
    return (f, x), k, h

def rect(f, plane, a0, a1, b0, b1, px, py, sh):
    if f == 1: return [1, a0, a1, b0, b1, -plane, -plane, px, py, sh]
    if f == 2: return [2, a0, a1, b0, b1, -(plane + 1), -(plane + 1), px, py, sh]
    if f == 3: return [3, a0, a1, plane + 1, plane + 1, -b1, -b0, px, py, sh]
    if f == 4: return [4, plane + 1, plane + 1, b0, b1, -a1, -a0, px, py, sh]
    return [5, plane, plane, b0, b1, -a1, -a0, px, py, sh]

groups = defaultdict(set)
for u in units:
    (f, plane), ua, ub = axes(u)
    groups[(f, plane, u[4], u[5], u[6])].add((ua, ub))
runs = []
for (f, plane, px, py, sh), cs in groups.items():
    left = set(cs)
    for (ua, ub) in sorted(cs, key=lambda c: (c[1], c[0])):
        if (ua, ub) not in left: continue
        a1 = ua
        while (a1 + 1, ub) in left: a1 += 1
        b1 = ub
        while all((t, b1 + 1) in left for t in range(ua, a1 + 1)): b1 += 1
        for t in range(ua, a1 + 1):
            for v in range(ub, b1 + 1): left.discard((t, v))
        runs.append(rect(f, plane, ua, a1 + 1, ub, b1 + 1, px, py, sh))

out = [quads[i] for i in range(len(quads)) if i in keep_q] + runs
txt = open(a.src).read()
head, rest = txt.split('quads={', 1)
tail = rest[rest.index('}'):]
nums = [str(v) for q in out for v in q]
lines = ['   ' + ','.join(nums[i:i + 60]) + ',' for i in range(0, len(nums), 60)]
open(a.out, 'w').write(head + 'quads={\n' + '\n'.join(lines) + '\n ' + tail)
print('%s: %d -> %d quads' % (os.path.basename(a.out), len(quads), len(out)))
