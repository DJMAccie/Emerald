#!/usr/bin/env python3
"""Defect scan of the baked building models: faults on the faces bake_check.py never measures.

bake_check.py scores the south faces and the tops in the 45-degree view. The sides, the back
and the depth the drawing never shows are invented by the bake, so nothing measures them.
This scan reads every quad of data/buildings/*.lua and flags five kinds of fault. It reports
only: it gates nothing and writes nothing into the mod.

A face lands in the drawing where bake_check's 45-degree projection puts it (row = (H-1) -
(height + depth), column = x; art pixels). An upright face's footprint is the drawing pixels
it stands in front of; a side's footprint is its one column of the drawing at its edge.

    holes     an upright face where under 70% of its drawn footprint is opaque: it hangs
              over the background. A face wholly outside the drawing (a back wall behind a
              deep roof) has nothing to measure and is counted as unmeasured instead.
    ground    an upright face where over half its footprint is the ground's colours (the
              colours ref.building_mask's rule takes as ground: seen on the rectangle's
              ground and never on its building).
    thin      a connected group of faces (sharing corners) narrower than 8 px on the ground
              plan, under 16 px long, and taller than its longer plan side: a post or a
              chimney whose sides repeat its front.
    stretch   a run of side faces, touching along the depth, at least 4 px deep, carrying the
              colour of the south face at its front edge: one front colour smeared backwards.
    steps     the left or right edge of the 45-degree silhouette moving exactly 1 px per row
              for 4 rows or more: a stair; the faces owning those edge pixels are flagged.

Calibrated for this pipeline (2026-10-17), each rule a fault the eye sees, not a by-product:
    ground    south faces only. North, east and west faces face away from or run edge-on to the
              drawing's camera, and a deep building's back wall projects onto the ground behind it
              by construction (25 000 such flags, none visible). A flagged region must also cover
              GROUND_MIN_AREA drawing px: a 1-2 px corner sliver is not a wall on the lawn. Colours
              the ref mask calls ground that a building is made of (SHARED) are not ground there.
    stretch   not where the front row at that height is itself mostly that colour (a drawn stripe
              running round, the Center's mansard band); 12 px deep (STRETCH_DEPTH, was 4: planks
              6 px apart flagged every board) and a band:
              the smeared colour must cover STRETCH_ROWS consecutive heights of one side
              column. A roof rim or a course line 1-3 px tall running back along a side is that
              line continued, as drawn, not a front colour dragged backwards.
    steps     only where the drawing's own outline does not step the same way: a 45-degree
              chamfer (octagons, the gyms' and the Center's cut corners) is drawn as a pixel stair.

Adapted from the defect scanner of Emerald 3DS (3ds_port/scripts/voxel_defect_scan.py in
ZallaxDev/pokeemerald-3Ds-dualscreen, read in a shallow clone). Its checks are the idea; the
code here is written for flat-coloured quads. The 3DS licence:

MIT License

Copyright (c) 2026 Zallax and Emerald 3DS contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Usage: python3 defect_scan.py [name-substring ...] --out DIR [--dir BAKES] [--mask ref|alpha]
                              [--render] [--no-preview]
Writes DIR/<bake>/report.txt and DIR/<bake>/preview.png (drawing | flagged pixels), with
--render also DIR/<bake>/yaw.png (four views of the bake, flagged faces in their kind's
colour), and DIR/summary.md (the table over all bakes).
"""
import argparse
import glob
import math
import os
import sys
from collections import Counter, defaultdict

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bake_check as B  # noqa: E402  (parse(), DATA: the bake loader)
import bldmodel as M  # noqa: E402  (compose(): the drawing; SHADE: the game's face shading)
from gamecam import Camera  # noqa: E402

REF_DIR = os.path.join(HERE, '..', 'ortho45')
KINDS = ('holes', 'ground', 'thin', 'stretch', 'steps')
KIND_RGB = {'holes': (255, 0, 255), 'ground': (40, 120, 255), 'thin': (0, 230, 230),
            'stretch': (255, 40, 40), 'steps': (255, 220, 0)}
FACE = {1: 'south', 2: 'north', 3: 'top', 4: 'east', 5: 'west'}
UPRIGHT = (1, 2, 4, 5)
HOLE_MIN = 0.70        # opaque share of an upright face's footprint, below which it is a hole
GROUND_MAX = 0.50      # ground-colour share of an upright face's footprint, above which it is ground
THIN_PLAN = 8          # px: the narrower side of a group's ground plan
THIN_LONG = 16         # px: the longer side must stay under this (3DS: 2 x thin)
STRETCH_DEPTH = 12     # px of depth a side run needs (a side strip repeats every 4-16 px: a run inside
                       # one period, planks between their joints, is its texture, not a smear)
STEP_ROWS = 4          # rows in a run where an outline moves exactly 1 px per row
PLINTH = 8             # a stretch band starting at the ground and ending below this height is a plinth
STRETCH_ROWS = 4       # consecutive heights a smeared side colour must cover to be a band
STRIPE = 0.6           # share of the front row in the run's colour above which it is a drawn stripe
GROUND_MIN_AREA = 24   # drawing px a ground-flagged region must cover
# colours the ref mask takes for ground (seen on the plaza) that these buildings are made of
# (the Battle Tower's cream pilasters #b5b5a5 - 3140 drawing px, all of them tower - and the Frontier's
# white #dee6ef, its pavement and its buildings' walls alike)
SHARED = {'x_frontier_dome': {0xdee6ef}, 'x_frontier_tower': {0xb5b5a5}, 'x_frontier_factory': {0xdee6ef},
}
BG = (26, 28, 34)
MARK = 0.5             # overlay strength of a flagged pixel in preview.png
PANEL = 3              # preview scale


def span(a, b):
    """Units a..b-1, one unit at least: a degenerate face still stands for its unit."""
    return np.arange(a, max(b, a + 1))


def footprint(q, H, W):
    """(rows, cols) a face lands on in the drawing, unclipped: bake_check's projection
    (row = (H-1) - (height + depth), column = x). A side stands in the column of its edge."""
    f, x0, x1, h0, h1, z0, z1 = q[:7]
    if f in (1, 2):
        d = -(z0 if f == 1 else z1)
        rows = (H - 1) - (span(h0, h1)[:, None] + d)
        cols = span(x0, x1)[None, :]
    elif f in (4, 5):
        lo, hi = sorted((-z0, -z1))
        col = min(max(x1 - 1 if f == 4 else x0, 0), W - 1)
        rows = (H - 1) - (span(h0, h1)[None, :] + span(lo, hi)[:, None])
        cols = np.full(rows.shape, col)
    else:
        lo, hi = sorted((-z0, -z1))
        rows = (H - 1) - (h0 + span(lo, hi)[:, None])
        cols = span(x0, x1)[None, :]
    return np.broadcast_arrays(rows, cols)


def corners(q):
    """The four corners of a face, as (x, height, z)."""
    f, x0, x1, h0, h1, z0, z1 = q[:7]
    if f in (1, 2):
        z = z0 if f == 1 else z1
        return [(x0, h0, z), (x1, h0, z), (x1, h1, z), (x0, h1, z)]
    if f in (4, 5):
        x = x1 if f == 4 else x0
        return [(x, h0, z0), (x, h0, z1), (x, h1, z1), (x, h1, z0)]
    return [(x0, h0, z0), (x1, h0, z0), (x1, h0, z1), (x0, h0, z1)]


def codes(art):
    a = art[..., :3].astype(np.int64)
    return (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]


def load_mask_fn():
    sys.path.insert(0, REF_DIR)
    try:
        import ref
        return ref.building_mask, ''
    except Exception as e:  # ref.py is being rewritten: the ground check is then off
        return None, '%s: %s' % (type(e).__name__, e)


def over_layer(info, shape):
    """Drawing pixels painted by a tile's over-layer (drawn above the player in the cartridge)."""
    import layers, voxproto
    x0, y0, x1, y1 = info['rect']
    L = layers.load(info['pair']); W, H, cells = voxproto.map_cells(info['map'])
    m = np.zeros(shape, bool)
    if 'o' not in L:
        return m
    for yy in range(y1 - y0 + 1):
        for xx in range(x1 - x0 + 1):
            o = layers.tile(L, 'o', cells[(y0 + yy) * W + x0 + xx] & 0x3FF)
            if o is not None:
                m[yy * 16:(yy + 1) * 16, xx * 16:(xx + 1) * 16] = o[..., 3] >= 128
    return m


def under_ground(info, shape):
    """Drawing pixels a building cell shows only from its under layer, where that under layer is the same tile
    as a walkable ground cell's round the rectangle: the ground drawn beneath a building's over-layer art in
    a mixed tile (Pacifidlog's raft planks beside the hut's eave). Colour cannot tell them apart - the planks
    are the hut wall's own gold - but the tile layers can. Pixel by pixel: the same under-layer pixel in the
    same place as a ground tile's, with nothing drawn over it."""
    import layers, voxproto
    x0, y0, x1, y1 = info['rect']
    L = layers.load(info['pair']); W, H, cells = voxproto.map_cells(info['map'])
    m = np.zeros(shape, bool)
    if not all(k in L for k in 'umo'):
        return m
    ground = set()
    for yy in range(max(0, y0 - 2), min(H, y1 + 3)):
        for xx in range(max(0, x0 - 2), min(W, x1 + 3)):
            if x0 <= xx <= x1 and y0 <= yy <= y1:
                continue
            v = cells[yy * W + xx]
            if (v >> 10) & 3 == 0:
                u = layers.tile(L, 'u', v & 0x3FF)
                if u is not None:
                    ground.add(u.tobytes())
    grounds = [np.frombuffer(g, np.uint8).reshape(16, 16, 4) for g in ground]
    for yy in range(y1 - y0 + 1):
        for xx in range(x1 - x0 + 1):
            mid = cells[(y0 + yy) * W + x0 + xx] & 0x3FF
            u, mm, o = (layers.tile(L, k, mid) for k in 'umo')
            if u is None:
                continue
            # (pixel by pixel, as ref.building_mask matches its composites: the hut's corner tiles carry the
            # raft's planks in their own under-layer tile, the same pixels in the same places)
            same = np.zeros((16, 16), bool)
            for g in grounds:
                same |= (u == g).all(axis=2) & (g[..., 3] >= 128)
            only = same & (u[..., 3] >= 128)
            if mm is not None:   # (a middle layer repeating the under layer pixel for pixel draws nothing over it)
                only &= ~((mm[..., 3] >= 128) & ~(mm == u).all(axis=2))
            if o is not None:
                only &= o[..., 3] < 128
            m[yy * 16:(yy + 1) * 16, xx * 16:(xx + 1) * 16] = only
    return m


def ground_colours(info, art, mask_fn):
    """Colours the rectangle shows on its ground and never on its building (ref.py's split)."""
    x0, y0, x1, y1 = info['rect']
    full = mask_fn(info['map'], info['rect'], pair=info['pair'])
    bm = full[y0 * 16:(y1 + 1) * 16, x0 * 16:(x1 + 1) * 16]
    if bm.shape != art.shape[:2]:
        raise ValueError('mask %s vs drawing %s' % (bm.shape, art.shape[:2]))
    op = art[..., 3] >= 128
    cd = codes(art)
    # (not from a tile's over-layer: that is roof drawn over the cells behind a building - the herb shop's
    # top tile row, whose peach band is Lavaridge's sand colour - never the ground)
    over = over_layer(info, bm.shape)
    ground = set(np.unique(cd[op & ~bm & ~over]).tolist())
    building = set(np.unique(cd[op & bm]).tolist())
    ground -= SHARED.get(info['name'], set()) | SHARED.get(os.path.basename(info.get('path', '')).replace('.lua', ''), set())
    return np.array(sorted(ground - building), np.int64), bm


def stair_runs(edge):
    """Row runs (first, last, step) where the edge column moves exactly `step` = +-1 px per
    row, STEP_ROWS rows at least. edge[r] is None where the row is empty."""
    out, r, n = [], 0, len(edge)
    while r < n - 1:
        a, b = edge[r], edge[r + 1]
        if a is None or b is None or abs(b - a) != 1:
            r += 1
            continue
        step, first = b - a, r
        while r < n - 1 and edge[r] is not None and edge[r + 1] is not None and edge[r + 1] - edge[r] == step:
            r += 1
        if r - first + 1 >= STEP_ROWS:
            out.append((first, r, step))
    return out


def side_runs(quads, colour):
    """Runs of side faces touching along the depth: same side, same column and height
    band, same colour. Each run is a list of quad indices, back to front (by z0)."""
    groups = defaultdict(list)
    for i, q in enumerate(quads):
        if q[0] in (4, 5):
            groups[(q[0], q[1], q[3], q[4])].append(i)
    runs = []
    for ids in groups.values():
        ids.sort(key=lambda i: quads[i][5])
        cur = [ids[0]]
        for i in ids[1:]:
            if quads[i][5] == quads[cur[-1]][6] and colour(i) == colour(cur[0]):
                cur.append(i)
            else:
                runs.append(cur)
                cur = [i]
        runs.append(cur)
    return runs


def front_index(quads):
    """(x, height) -> [(z, quad)] of the south faces standing there."""
    idx = defaultdict(list)
    for i, q in enumerate(quads):
        if q[0] != 1:
            continue
        for x in span(q[1], q[2]):
            for h in span(q[3], q[4]):
                idx[(int(x), int(h))].append((q[5], i))
    return idx


def scan(info, mask_fn):
    """Flags every face of one bake. Returns the result dict used by the writers."""
    x0, y0, x1, y1 = info['rect']
    quads = info['quads']
    art = M.compose(info['pair'], info['map'], x0, y0, x1, y1)
    H, W = art.shape[:2]
    op = art[..., 3] >= 128
    cd = codes(art)
    n = len(quads)
    notes = []
    gset = np.zeros(0, np.int64)
    bmask = None
    if mask_fn is None:
        notes.append('ground check off: ref.py not importable (%s)' % MASK_NOTE)
    else:
        try:
            gset, bmask = ground_colours(info, art, mask_fn)
        except Exception as e:
            notes.append('ground check off: %s: %s' % (type(e).__name__, str(e)[:160]))

    faults = {k: defaultdict(list) for k in KINDS}
    marks = {k: np.zeros((H, W), bool) for k in KINDS}
    fp = [footprint(q, H, W) for q in quads]
    inside = [(r >= 0) & (r < H) & (c >= 0) & (c < W) for r, c in fp]

    def colour_of(i):
        q = quads[i]
        return int(cd[q[8], q[7]]) if 0 <= q[8] < H and 0 <= q[7] < W else -1

    # holes and ground: the upright faces' footprints, measured on the drawing only. A face
    # wholly above or beside the drawing (a back wall behind a deep roof) has no drawing to
    # measure: it is counted as unmeasured, not as a hole.
    unmeasured = 0
    gcand = []
    for i, q in enumerate(quads):
        if q[0] not in UPRIGHT:
            continue
        r, c = fp[i]
        v = inside[i]
        rv, cv = r[v], c[v]
        if rv.size == 0:
            unmeasured += 1
            continue
        share = op[rv, cv].sum() / rv.size
        if share < HOLE_MIN:
            faults['holes'][i].append('%d%% of its drawn footprint is opaque' % round(100 * share))
            marks['holes'][rv, cv] = True
        if gset.size and q[0] == 1:
            gshare = (op[rv, cv] & np.isin(cd[rv, cv], gset)).sum() / rv.size
            if gshare > GROUND_MAX:
                gcand.append((i, rv, cv, gshare))
    # a ground region counts once it covers GROUND_MIN_AREA drawing px
    if gcand:
        gm = np.zeros((H, W), bool)
        for i, rv, cv, _ in gcand:
            gm[rv, cv] = True
        lab = np.zeros((H, W), np.int64); area = {}; k = 0
        for r0 in range(H):
            for c0 in range(W):
                if gm[r0, c0] and not lab[r0, c0]:
                    k += 1; st = [(r0, c0)]; lab[r0, c0] = k; a = 0
                    while st:
                        r1, c1 = st.pop(); a += 1
                        for r2, c2 in ((r1 + 1, c1), (r1 - 1, c1), (r1, c1 + 1), (r1, c1 - 1)):
                            if 0 <= r2 < H and 0 <= c2 < W and gm[r2, c2] and not lab[r2, c2]:
                                lab[r2, c2] = k; st.append((r2, c2))
                    area[k] = a
        for i, rv, cv, gshare in gcand:
            if max(area[l] for l in lab[rv, cv]) >= GROUND_MIN_AREA:
                faults['ground'][i].append('%d%% of its footprint is ground colour' % round(100 * gshare))
                marks['ground'][rv, cv] = True

    # stretch: a side run that repeats the south face's colour at its front edge, in a band
    # STRETCH_ROWS heights tall (collected first, then kept by band)
    front = front_index(quads)
    scand = []
    for run in side_runs(quads, colour_of):
        q0, qn = quads[run[0]], quads[run[-1]]
        depth = qn[6] - q0[5]
        if depth < STRETCH_DEPTH:
            continue
        col = min(max(q0[2] - 1 if q0[0] == 4 else q0[1], 0), W - 1)
        hm = (q0[3] + q0[4]) // 2
        cands = front.get((col, hm), [])
        if not cands:
            continue
        zf = qn[6]
        _, fi = min(cands, key=lambda t: abs(t[0] - zf))
        if colour_of(fi) != colour_of(run[0]) or colour_of(fi) < 0:
            continue
        # a stripe the front itself draws (the front row at this height is mostly this colour, a
        # band running round the building) is continued, not smeared
        fr = [colour_of(i) for x in range(0, W) for (_, i) in front.get((x, hm), [])]
        if fr and fr.count(colour_of(run[0])) >= STRIPE * len(fr):
            continue
        scand.append((run, q0[0], col, q0[3], depth, q0[5], qn[6]))
    # (a band is one colour: horizontal courses of different colours continued round the building, a
    # striped stone base, are the front's own rows - a smear is one front colour dragged back over rows)
    band = defaultdict(set)
    for run, f, col, h, depth, za, zb in scand:
        band[(f, col, colour_of(run[0]))].add(h)
    for run, f, col, h, depth, za, zb in scand:
        hs = band[(f, col, colour_of(run[0]))]
        lo = h
        while lo - 1 in hs: lo -= 1
        hi = h
        while hi + 1 in hs: hi += 1
        if hi - lo + 1 < STRETCH_ROWS:
            continue
        # a band at the foot of the wall, under PLINTH px tall: a base course running round the
        # building as drawn on its front (the Center's and the gyms' grey plinth), not a smear
        if lo <= 2 and hi < PLINTH:
            continue
        for i in run:
            faults['stretch'][i].append('run of %d px depth (z %d..%d), band of %d rows, repeats the south face #%06x'
                                        % (depth, za, zb, hi - lo + 1, colour_of(i)))
            r, c = fp[i]
            marks['stretch'][r[inside[i]], c[inside[i]]] = True

    # thin: connected faces (sharing corners) that are a tall narrow part on the ground plan
    parent = list(range(n))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    seen = {}
    for i, q in enumerate(quads):
        for p in corners(q):
            j = seen.setdefault(p, i)
            if j != i:
                parent[find(i)] = find(j)
    groups = defaultdict(list)
    for i in range(n):
        groups[find(i)].append(i)
    for g in groups.values():
        pts = [p for i in g for p in corners(quads[i])]
        xs, hs, zs = [p[0] for p in pts], [p[1] for p in pts], [p[2] for p in pts]
        wx, wz, hy = max(xs) - min(xs), max(zs) - min(zs), max(hs) - min(hs)
        if min(wx, wz) < THIN_PLAN and max(wx, wz) < THIN_LONG and hy > max(wx, wz):
            for i in g:
                faults['thin'][i].append('group of %d faces: plan %d x %d px, %d px tall'
                                         % (len(g), wx, wz, hy))
                r, c = fp[i]
                marks['thin'][r[inside[i]], c[inside[i]]] = True

    # steps: the 45-degree silhouette's left and right edges, 1 px per row
    owner = np.full((H, W), -1, np.int64)
    for i in sorted(range(n), key=lambda i: -max(quads[i][5], quads[i][6])):   # front-most first
        r, c = fp[i]
        v = inside[i]
        rv, cv = r[v], c[v]
        free = owner[rv, cv] < 0
        owner[rv[free], cv[free]] = i
    left, right = [None] * H, [None] * H
    for r in range(H):
        cs = np.flatnonzero(owner[r] >= 0)
        if cs.size:
            left[r], right[r] = int(cs[0]), int(cs[-1])
    # the drawing's own outline (opaque building pixels): a stair it draws is no fault
    # (less what a cell shows only from a ground under layer: the raft beside Pacifidlog's hut eave)
    dm = op & bmask if bmask is not None else op
    try:
        dm = dm & ~under_ground(info, (H, W))
    except Exception as e:
        notes.append('under-layer ground off: %s: %s' % (type(e).__name__, str(e)[:120]))
    dleft, dright = [None] * H, [None] * H
    for r in range(H):
        cs = np.flatnonzero(dm[r])
        if cs.size:
            dleft[r], dright[r] = int(cs[0]), int(cs[-1])
    for edge, side, dedge in ((left, 'left', dleft), (right, 'right', dright)):
        for first, last, step in stair_runs(edge):
            rows_ = range(first, last + 1)
            same = sum(1 for r in rows_ if dedge[r] is not None and abs(dedge[r] - edge[r]) <= 1)
            if same >= .75 * len(rows_):
                continue
            # rows the drawing has no building in (a dome's crown risen past the drawing's top row): nothing
            # to compare a stair with - unmeasured, not a fault
            drawn = sum(1 for r in rows_ if dedge[r] is not None)
            if drawn < .75 * len(rows_):
                continue
            # where the drawing's own edge curves over these rows (it moves on half of them or more: a dome's
            # crown, a coil, a round roof) a 1 px stair is the curve laid in voxels; the fault is a stair
            # against a straight drawn edge
            moves = sum(1 for r in range(first, last) if dedge[r] is not None and dedge[r + 1] is not None
                        and dedge[r + 1] != dedge[r])
            if moves >= .5 * (last - first):
                continue
            for r in rows_:
                i = int(owner[r, edge[r]])
                faults['steps'][i].append('%s edge moves %+d px a row, rows %d-%d' % (side, step, first, last))
                marks['steps'][r, edge[r]] = True

    flagged = set()
    for k in KINDS:
        flagged.update(faults[k].keys())
    return dict(name=info['name'], map=info['map'], pair=info['pair'], rect=info['rect'], H=H, W=W,
                quads=quads, art=art, faults=faults, marks=marks, notes=notes, flagged=flagged,
                ground_n=int(gset.size), unmeasured=unmeasured)


def quad_line(i, q, art, details):
    """One report line for a face: its index, face, box, pixel and colour, then the detail."""
    H, W = art.shape[:2]
    rgb = int(codes(art[q[8]:q[8] + 1, q[7]:q[7] + 1])[0, 0]) if 0 <= q[8] < H and 0 <= q[7] < W else 0
    return '  #%-5d %-6s x %4d-%-4d h %4d-%-4d z %5d..%-5d px %4d,%-4d #%06x  %s' % (
        i, FACE[q[0]], q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8], rgb, details)


def write_report(res, path, mask_note):
    faults, quads, art = res['faults'], res['quads'], res['art']
    L = ['defect scan: %s' % res['name'],
         'map %s pair %s rect (%d,%d)-(%d,%d) drawing %dx%d px, %d faces' % (
             res['map'], res['pair'], res['rect'][0], res['rect'][1], res['rect'][2], res['rect'][3],
             res['W'], res['H'], len(quads)),
         'mask: %s; ground colours: %d' % (mask_note, res['ground_n'])]
    L += ['notes: ' + n for n in res['notes']]
    counts = {k: len(faults[k]) for k in KINDS}
    L.append('faults: ' + ', '.join('%s %d' % (k, counts[k]) for k in KINDS)
             + '; faces flagged %d (%.1f%%); upright faces unmeasured (outside the drawing) %d'
             % (len(res['flagged']), 100.0 * len(res['flagged']) / max(1, len(quads)), res['unmeasured']))
    for k in KINDS:
        L += ['', '%s (%d faces)' % (k, counts[k])]
        for i in sorted(faults[k]):
            L.append(quad_line(i, quads[i], art, '; '.join(sorted(set(faults[k][i])))))
        if not faults[k]:
            L.append('  none')
    open(path, 'w', encoding='utf-8').write('\n'.join(L) + '\n')


def preview(res, path):
    """The drawing (left) and the same with the flagged pixels tinted (right)."""
    art = res['art']
    a = art[..., 3:4].astype(float) / 255.0
    base = art[..., :3].astype(float) * a + np.array(BG, float) * (1 - a)
    over = base.copy()
    for k in KINDS:
        m = res['marks'][k]
        if m.any():
            over[m] = over[m] * (1 - MARK) + np.array(KIND_RGB[k], float) * MARK
    gap = np.tile(np.array(BG, float), (art.shape[0], 4, 1))
    img = np.concatenate([base, gap, over], axis=1).clip(0, 255).astype(np.uint8)
    im = Image.fromarray(img).resize((img.shape[1] * PANEL, img.shape[0] * PANEL), Image.NEAREST)
    legend = Image.new('RGB', (im.width, 40), BG)
    d = ImageDraw.Draw(legend)
    x = 6
    d.text((x, 4), '%s   holes ground thin stretch steps' % res['name'], fill=(220, 220, 220))
    x = 6
    for k in KINDS:
        d.rectangle([x, 22, x + 10, 32], fill=KIND_RGB[k])
        d.text((x + 14, 22), k, fill=(220, 220, 220))
        x += 14 + 8 * len(k) + 16
    out = Image.new('RGB', (im.width, im.height + legend.height), BG)
    out.paste(im, (0, 0))
    out.paste(legend, (0, im.height))
    out.save(path)


def render_views(res, path, yaws=(0, 90, 180, 270), vw=640, vh=480):
    """Four yaw views of the bake as flat quads: each face in its own pixel's colour, shaded
    as the game shades it; flagged faces in their first kind's colour. Painted far to near."""
    quads, art = res['quads'], res['art']
    H, W = art.shape[:2]
    zs = [q[5] for q in quads] + [q[6] for q in quads]
    cx, cz = W / 2.0, (max(zs) + min(zs)) / 2.0
    first_kind = {}
    for k in KINDS:
        for i in res['faults'][k]:
            first_kind.setdefault(i, k)
    panels = []
    for yaw in yaws:
        cam = Camera(vw, vh, 4, ground=0.0, cx=cx, cz=cz)
        cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        m = cam.mvp
        tris = []
        for i, q in enumerate(quads):
            if i in first_kind:
                rgb = KIND_RGB[first_kind[i]]
            else:
                px, py = q[7], q[8]
                if not (0 <= px < W and 0 <= py < H):
                    continue
                rgb = tuple(int(v) for v in np.clip(art[py, px, :3].astype(float) * M.SHADE[FACE[q[0]]], 0, 255))
            pts = []
            for (x, y, z) in corners(q):
                X, Z = x - cx, z - cz
                pts.append((cx + X * cy - Z * sy, y, cz + X * sy + Z * cy))
            for tri in ((pts[0], pts[1], pts[2]), (pts[0], pts[2], pts[3])):
                depth = sum(m[12] * x + m[13] * y + m[14] * z + m[15] for (x, y, z) in tri) / 3.0
                tris.append((depth, tri, rgb))
        tris.sort(key=lambda t: -t[0])
        canvas = np.tile(np.array(BG, np.uint8), (vh, vw, 1))
        for _, tri, rgb in tris:
            p2 = [cam.project(*p) for p in tri]
            _fill(canvas, p2, rgb)
        ys, xs = np.nonzero(np.any(canvas != np.array(BG, np.uint8), axis=2))
        if xs.size == 0:
            continue
        pad = 12
        crop = canvas[max(0, ys.min() - pad):ys.max() + pad, max(0, xs.min() - pad):xs.max() + pad]
        panels.append(Image.fromarray(crop))
    if not panels:
        return
    h = max(p.height for p in panels)
    w = sum(p.width for p in panels) + 8 * (len(panels) - 1)
    sheet = Image.new('RGB', (w, h), BG)
    x = 0
    for p in panels:
        sheet.paste(p, (x, 0))
        x += p.width + 8
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(path)


def _fill(canvas, p2, rgb):
    (ax, ay), (bx, by), (qx, qy) = p2
    vh, vw = canvas.shape[:2]
    xa, xb = max(0, int(math.floor(min(ax, bx, qx)))), min(vw - 1, int(math.ceil(max(ax, bx, qx))))
    ya, yb = max(0, int(math.floor(min(ay, by, qy)))), min(vh - 1, int(math.ceil(max(ay, by, qy))))
    if xb < xa or yb < ya:
        return
    det = (by - qy) * (ax - qx) + (qx - bx) * (ay - qy)
    if abs(det) < 1e-9:
        return
    xs, ys = np.meshgrid(np.arange(xa, xb + 1) + 0.5, np.arange(ya, yb + 1) + 0.5)
    w0 = ((by - qy) * (xs - qx) + (qx - bx) * (ys - qy)) / det
    w1 = ((qy - ay) * (xs - qx) + (ax - qx) * (ys - qy)) / det
    w2 = 1 - w0 - w1
    inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
    canvas[ya:yb + 1, xa:xb + 1][inside] = rgb


def summary(results, mask_note, path):
    L = ['# Defect scan (offline; reports only, gates nothing)', '',
         'Mask: %s. Bakes: %d. Checks: holes (footprint < 70%% opaque), ground (> 50%% ground colour), '
         'thin (group < 8 px plan, taller than wide), stretch (side run >= 4 px repeating the south colour), '
         'steps (outline 1 px per row, 4+ rows).' % (mask_note, len(results)), '',
         '| bake | faces | holes | ground | thin | stretch | steps | faces flagged | share | unmeasured |',
         '|---|---|---|---|---|---|---|---|---|---|']
    tot = Counter()
    for r in sorted(results, key=lambda r: (-len(r['flagged']), r['name'])):
        c = {k: len(r['faults'][k]) for k in KINDS}
        for k in KINDS:
            tot[k] += c[k]
        n = len(r['quads'])
        L.append('| %s | %d | %s | %d | %.1f%% | %d |' % (
            r['name'], n, ' | '.join(str(c[k]) for k in KINDS), len(r['flagged']),
            100.0 * len(r['flagged']) / max(1, n), r['unmeasured']))
    L.append('| **all** | %d | %s | %d | - | %d |' % (
        sum(len(r['quads']) for r in results), ' | '.join(str(tot[k]) for k in KINDS),
        sum(len(r['flagged']) for r in results), sum(r['unmeasured'] for r in results)))
    per_kind = ['', 'Bakes with at least one fault: ' + ', '.join(
        '%s %d' % (k, sum(1 for r in results if r['faults'][k])) for k in KINDS)]
    open(path, 'w', encoding='utf-8').write('\n'.join(L + per_kind) + '\n')
    return L + per_kind


MASK_NOTE = ''


def main():
    global MASK_NOTE
    ap = argparse.ArgumentParser(description='Defect scan of the baked building models (reports only).')
    ap.add_argument('names', nargs='*', help='bake name substrings (default: all bakes)')
    ap.add_argument('--out', required=True, help='output folder: one folder per bake, plus summary.md')
    ap.add_argument('--dir', default=B.DATA, help='folder of the bake .lua files')
    ap.add_argument('--mask', choices=['ref', 'alpha'], default='ref',
                    help='ref: ground colours from ref.building_mask; alpha: no ground check')
    ap.add_argument('--render', action='store_true', help='also write yaw.png for each bake with faults')
    ap.add_argument('--no-preview', action='store_true', help='skip preview.png')
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    mask_fn = None
    mask_note = 'alpha (no ground check)'
    if a.mask == 'ref':
        mask_fn, MASK_NOTE = load_mask_fn()
        mask_note = 'ref.building_mask ground colours' if mask_fn else 'alpha (ref.py unavailable)'
    files = sorted(p for p in glob.glob(os.path.join(a.dir, '*.lua')) if os.path.basename(p) != 'index.lua')
    if a.names:
        files = [p for p in files if any(s in os.path.basename(p) for s in a.names)]
    if not files:
        sys.exit('no bakes match in %s' % a.dir)
    results = []
    for p in files:
        info = B.parse(p)
        res = scan(info, mask_fn if a.mask == 'ref' else None)
        res['file'] = os.path.basename(p)
        folder = os.path.join(a.out, info['name'])
        os.makedirs(folder, exist_ok=True)
        write_report(res, os.path.join(folder, 'report.txt'), mask_note)
        if not a.no_preview:
            preview(res, os.path.join(folder, 'preview.png'))
        if a.render and res['flagged']:
            render_views(res, os.path.join(folder, 'yaw.png'))
        results.append(res)
        print('%-40s faces %6d  flagged %5d  %s' % (
            info['name'], len(res['quads']), len(res['flagged']),
            ' '.join('%s %d' % (k, len(res['faults'][k])) for k in KINDS if res['faults'][k])))
    lines = summary(results, mask_note, os.path.join(a.out, 'summary.md'))
    print()
    print('\n'.join(lines[2:]))
    print('outdir:', a.out)


if __name__ == '__main__':
    main()
