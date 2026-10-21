#!/usr/bin/env python3
"""Heightfield-voxel building builder (offline lab).

A building drawing is an oblique projection: screen row = height + depth, one art
pixel = one world pixel.  So a column of the drawing is a *path* through (depth,
height) space read from the base line upward:

    wall  n          rows rise straight up        (front face, depth fixed)
    flat  n          rows run back at one height  (roof / ledge seen from above)
    slope n s        rows climb s voxels per voxel of depth

Every art pixel lands on exactly one voxel face of that path, 1:1, so nothing is
stretched and the head-on view reproduces the drawing by construction.  The solid
under the path is filled with the facade's own material colour (sides/back), and
`relief` rects push window/door/ledge pixels in or out by whole voxels.

Usage: python3 tools/buildings/hf.py <recipe> [--levels 4,7] [--yaws 0,90,180,270]
"""
import argparse, json, math, os, sys
from collections import Counter

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))

SHADE = {'top': 1.0, 'south': 0.92, 'north': 0.70, 'east': 0.84, 'west': 0.78}
PAD = 12            # voxel rows of room in front of depth 0 (protruding relief)
HPAD = 16


def pack(c):
    return (int(c[0]) << 16) | (int(c[1]) << 8) | int(c[2])


def unpack(v):
    return ((v >> 16) & 255, (v >> 8) & 255, v & 255)


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def mode_colour(img, row, xs):
    """Most common non-outline opaque colour of one drawing row over xs."""
    row = max(0, min(img.shape[0] - 1, row))
    cnt = Counter()
    for x in xs:
        p = img[row, x]
        if p[3] >= 128:
            cnt[(int(p[0]), int(p[1]), int(p[2]))] += 1
    if not cnt:
        return (128, 128, 128)
    light = [(c, n) for c, n in cnt.items() if lum(c) > 70]
    pool = light or list(cnt.items())
    return max(pool, key=lambda t: t[1])[0]


def steps(row, n, d, h, share):
    """n drawing rows up a slope as unit steps: every row is ONE riser (the
    south face of voxel hi at depth di, screen row hi + di) or ONE tread (the
    top of voxel hi - 1 at depth di, screen row hi + di), so height + depth
    grows by exactly one per row and each row lands on its own face. `share`
    is the part of the rows that rise (s / (1 + s) for a slope of s)."""
    di, hi, acc, out = int(math.floor(d + 1e-6)), int(math.ceil(h - 1e-6)), 0.0, []
    # `row` may be a list of art rows (a slope with repeated courses)
    rows = row if isinstance(row, list) else [row - i for i in range(n)]
    for r in rows:
        acc += share
        if acc >= 0.5 or hi <= 0:
            out.append((r, hi, di, 'rise')); hi += 1; acc -= 1.0
        else:
            out.append((r, hi - 1, di, 'tread')); di += 1
    return out, di, hi


def walk(pc, x):
    """Path samples for one column: (row, hv, dv, kind), plus end (d, h)."""
    d0 = pc.get('d0', 0)
    d = float(d0(x) if callable(d0) else d0)
    # h0: the piece stands on something h0 px up (a rocket on a roof deck);
    # its first row is h0 rows above its ground row
    h = float(pc.get('h0', 0))
    row = pc['B'] - int(round(d)) - int(round(h))
    out = []
    for seg in pc['segs']:
        kind = seg[0]
        n = seg[1]
        if n == 'top':
            n = row + 1
        n = int(n)
        if n <= 0:
            continue
        if kind == 'wall':
            for i in range(n):
                out.append((row - i, int(math.floor(h + i + 1e-6)), int(math.floor(d + 1e-6)), 'wall'))
            h += n
        elif kind == 'flat':
            hv = max(0, int(math.ceil(h - 1e-6)) - 1)
            for i in range(n):
                out.append((row - i, hv, int(math.floor(d + i + 1e-6)), 'flat'))
            d += n
        elif kind == 'flatx':
            # A flat roof deeper than it is drawn (the building's blocked
            # footprint is deeper than the drawing shows): after the front
            # rows down to art row m, e more rows repeat the P rows ending at
            # m (the roof's own courses, in phase), then the drawing's rows
            # carry on to the back edge. More courses, nothing stretched.
            m, e, P = int(seg[2]), int(seg[3]), int(seg[4])
            hv = max(0, int(math.ceil(h - 1e-6)) - 1)
            rows = [(r, 'flat') for r in range(row, m, -1)] + [(m - (j % P), 'flatr') for j in range(e)] \
                + [(r, 'flat') for r in range(m - (e % P), row - n, -1)]
            for i, (r, kd) in enumerate(rows):
                out.append((r, hv, int(math.floor(d + i + 1e-6)), kd))
            d += len(rows)
            row -= n
            continue
        elif kind == 'gable':
            # A symmetric pitched roof as Gen 3 draws it: nf rows of front
            # slope up to the ridge line, then nb rows of the back slope seen
            # foreshortened above it (a point's screen row is height + depth,
            # so a slope falling away shows (1-s) rows per unit of depth).
            # Equal depths both sides give the pitch: s = (nf-nb)/(nf+nb).
            nf, nb = int(seg[1]), int(seg[2])
            sl = (nf - nb) / float(nf + nb)
            # ('gable', nf, nb, e, m, P): e px deeper than drawn, half on each
            # slope. The front slope gets more of its own courses (the P rows
            # ending at art row m, repeated in its middle); the ridge rises
            # with it. The back slope gets the same depth, its far end laid
            # with the same courses.
            e = int(seg[3]) if len(seg) > 3 else 0
            eb = 0
            if e:
                m, P = int(seg[4]), int(seg[5])
                ef = int(round(e / 2.0 * (1.0 + sl)))
                eb = int(round(e / 2.0 * (1.0 - sl)))
                frows = list(range(row, m, -1)) + [m - (j % P) for j in range(ef)] + list(range(m - (ef % P), row - nf, -1))
                o, di, hi = steps(frows, 0, d, h, sl / (1.0 + sl))
            else:
                o, di, hi = steps(row, nf, d, h, sl / (1.0 + sl))
            out += o
            row -= nf
            # the back slope falls sl per unit of depth. A column that keeps
            # the height of the one before shows one more drawing row; a
            # column one lower hides exactly behind it (same screen row) and
            # takes that row's colour. Every column exists: no slits.
            brows = [row - i for i in range(nb)] + ([m - (j % P) for j in range(eb)] if eb else [])
            i, acc = 0, 0.0
            while i < len(brows):
                acc += sl
                kd = 'tread' if i < nb else 'flatr'
                if acc >= 0.5 and hi > 1:
                    hi -= 1; acc -= 1.0
                    out.append((brows[i], hi - 1, di, kd)); di += 1
                else:
                    out.append((brows[i], hi - 1, di, kd)); di += 1; i += 1
            d, h = float(di), float(hi); row -= nb
            continue
        elif kind == 'mirror':
            # done in build(), after the column is trimmed at the outline
            out.append((None, n, None, 'mirror'))
            continue
        elif kind == 'slope':
            s = seg[2]
            o, di, hi = steps(row, n, d, h, s / (1.0 + s))
            out += o
            d, h = float(di), float(hi)
        row -= n
    return out, d, h


def _opaque(img):
    o = img.copy(); o[..., 3] = 255
    return o


def trim_and_mirror(img, smp, trim=True):
    """Stop a column where its drawing ends (a transparent pixel above the
    walls: grass around a dome), then build the back half by reflecting the
    remaining roof over its ridge."""
    mirror = [m for m in smp if m[3] == 'mirror']
    front = [m for m in smp if m[3] != 'mirror']
    kept = []
    for i, m in enumerate(front):
        row = m[0]
        if trim and 0 <= row < img.shape[0] and img[row, m[4] if len(m) > 4 else 0, 3] < 128 and m[3] != 'wall':
            # a roof carried back with repeated courses goes on behind a
            # ragged ridge line: every column keeps its full depth (no teeth)
            if not any(f[3] == 'flatr' for f in front[i + 1:]):
                break
        kept.append(m)
    if mirror:
        n = min(mirror[0][1], sum(1 for m in kept if m[3] != 'wall')) if trim else min(mirror[0][1], len(kept))
        if n > 0:
            src = kept[-n:]
            dend = max(m[2] for m in src) + 1
            for m in reversed(src):
                kept.append((m[0], m[1], int(2 * dend - 1 - m[2]), 'slope'))
    return kept


EDGE_TRIM = 4      # at most this many edge columns a side are cut as ground (see build)
EDGE_GROUND = 0.7  # a column is ground when this share of its opaque drawing is not building


def ground_columns(src, img, rows=None):
    """Per drawing column: is it ground? Ground colours as the defect scanner takes them from
    ref.building_mask (tools/ortho45/ref.py): seen on the rectangle's ground, never on its building;
    a column is ground when EDGE_GROUND of its opaque pixels are those colours. None when ref.py is
    unavailable."""
    H, W = img.shape[:2]
    try:
        sys.path.insert(0, os.path.join(HERE, '..', 'ortho45'))
        import ref
        pair, mp, x0, y0, x1, y1 = src
        full = ref.building_mask(mp, [x0, y0, x1, y1], pair=pair)
        bm = full[y0 * 16:(y1 + 1) * 16, x0 * 16:(x1 + 1) * 16]
    except Exception:
        return None
    if bm.shape != (H, W):
        return None
    a = img[..., :3].astype(np.int64)
    cd = (a[..., 0] << 16) | (a[..., 1] << 8) | a[..., 2]
    op = img[..., 3] >= 128
    gset = set(np.unique(cd[op & ~bm]).tolist()) - set(np.unique(cd[op & bm]).tolist())
    isg = np.isin(cd, np.array(sorted(gset), np.int64)) & op
    r0, r1 = rows or (0, H)
    out = []
    for x in range(W):
        n = op[r0:r1, x].sum()
        out.append(bool(n) and isg[r0:r1, x].sum() >= EDGE_GROUND * n)
    return out


def build(img, recipe):
    H, W = img.shape[:2]
    img0 = img
    # key colours (the ground around the building) are not building
    keys0 = {tuple(k) for k in recipe.get('keys', [])}
    trim = recipe.get('trim', False)
    if recipe.get('bgmask') is not None:          # precomputed ground (autorecipe)
        img = img.copy(); img[recipe['bgmask'], 3] = 0
    if recipe.get('bgtiles'):
        # ground = pixels identical to one of these tiles AT THE SAME POSITION,
        # reached from outside the drawing (leaves that share the canopy's
        # colours but not its pattern stay)
        sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
        import voxproto, layers
        L_ = layers.load(recipe['src'][0])
        pos = np.zeros((H, W), bool)
        im3 = img[..., :3].astype(int)
        for t in recipe['bgtiles']:
            tt = np.tile(voxproto.art(L_, t).astype(int), (H // 16, W // 16, 1))
            pos |= (np.abs(im3 - tt).sum(2) == 0)
        seen = np.zeros((H, W), bool)
        st = [(yy, xx) for yy in range(H) for xx in (0, W - 1)] + [(yy, xx) for xx in range(W) for yy in (0, H - 1)]
        while st:
            yy, xx = st.pop()
            if yy < 0 or xx < 0 or yy >= H or xx >= W or seen[yy, xx] or not pos[yy, xx]: continue
            seen[yy, xx] = True
            st += [(yy + 1, xx), (yy - 1, xx), (yy, xx + 1), (yy, xx - 1)]
        img = img.copy(); img[seen, 3] = 0
    if keys0 and trim:
        # ground is what can be reached from outside the drawing through key
        # colours: a wall painted the path's colour inside its outline stays
        img = img.copy()
        isk = np.array([[tuple(int(v) for v in img[yy, xx, :3]) in keys0 for xx in range(W)] for yy in range(H)])
        if recipe.get('flood', False):
            seen = np.zeros((H, W), bool)
            st = [(yy, xx) for yy in range(H) for xx in (0, W - 1)] + [(yy, xx) for xx in range(W) for yy in (0, H - 1)]
            while st:
                yy, xx = st.pop()
                if yy < 0 or xx < 0 or yy >= H or xx >= W or seen[yy, xx] or not isk[yy, xx]: continue
                seen[yy, xx] = True
                st += [(yy + 1, xx), (yy - 1, xx), (yy, xx + 1), (yy, xx - 1)]
            isk = seen
        img[isk, 3] = 0
    cols = {}
    dmax = hmax = 0
    for vol in recipe.get('volumes', []):           # volumes set the model's room as well as pieces do
        _, vd1, vh1 = volume_extent(vol)
        dmax, hmax = max(dmax, vd1 + 2), max(hmax, vh1 + 2)
    for pc in recipe.get('pieces', []):
        xs = range(*pc['x'])
        tail = pc.get('tail', 0)
        for x in xs:
            smp, de, he = walk(pc, x)
            smp = [s if s[3] == 'mirror' else s + (x,) for s in smp]
            smp = trim_and_mirror(img, [s for s in smp if s[3] == 'mirror' or 0 <= s[0] < H], trim)
            smp = [s[:4] for s in smp]
            # rowcap: the column's roof stops rising at the first sample above this drawing row
            # (a low wing beside a tall vault, whose extra courses would climb on behind its
            # drawn top edge over the cliff). It keeps its depth: the rest is carried back level
            # at that height (no higher than the roof it replaces), laid with the RC rows under
            # the drawn top edge.
            cap = pc.get('rowcap', {}).get(x)
            if cap is not None:
                cut = next((i for i, s_ in enumerate(smp) if s_[3] != 'wall' and s_[0] < cap), None)
                if cut is not None and cut > 0:
                    hc = max(s_[1] for s_ in smp[:cut])
                    rc = pc.get('rowcap_rows', (2, 8))
                    smp = smp[:cut] + [(cap + rc[0] + j % rc[1], min(s_[1], hc), s_[2], 'flatr')
                                       for j, s_ in enumerate(smp[cut:])]
            # a column whose whole facade is ground (cut away) is not building
            if trim and smp and all(img[s_[0], x, 3] < 128 for s_ in smp if s_[3] == 'wall' and 0 <= s_[0] < H):
                continue
            if smp:
                de = max(s[2] for s in smp) + 1
            tl = tail
            if 'depth' in pc:
                smp = [s for s in smp if s[2] < pc['depth']]
                de = (max(s[2] for s in smp) + 1) if smp else pc['depth']
                tl = max(0, pc['depth'] - int(de))
            # a column may carry several pieces (a rocket standing behind a
            # building on the same columns): later pieces add, never replace
            cols.setdefault(x, []).append((pc, smp, de, he, tl))
            tail = pc.get('tail', 0)
            dmax = max(dmax, int(de) + tl + 2, max((s[2] for s in smp), default=0) + tl + 2)
            hmax = max(hmax, int(he) + 2, max((s[1] for s in smp), default=0) + 2)
    lift = max([-r['k'] for r in recipe.get('relief', [])] + [0])
    DD, HH = dmax + PAD + 4, hmax + HPAD + lift
    occ = np.zeros((W, HH, DD), bool)
    colS = np.full((W, HH, DD), -1, np.int32)
    colT = np.full((W, HH, DD), -1, np.int32)
    colE = np.full((W, HH, DD), -1, np.int32)     # east/west faces
    colN = np.full((W, HH, DD), -1, np.int32)     # back faces
    sideE = np.full((W, HH, DD), -1, np.int32)    # the side art at every wall cell (see below)
    solid = np.full((W, HH, DD), pack((128, 128, 128)), np.int32)
    pix = {}       # (x,row) -> (hv, dv, kind)
    keys = {pack(k) for k in recipe.get('keys', [])}

    def pixcol(x, row):
        p = img[row, x]
        if p[3] < 128:
            return -1
        c = pack(p[:3])
        return -1 if c in keys else c

    # each piece's outermost standing columns: where a drawing's outline column
    # is cut away (ground), the column inside it is the side wall, and it takes
    # the side art (it used to take the row's flat band colour: a plain slab)
    ends = {}
    for x, es in cols.items():
        for e in es:
            a_, b_ = ends.get(id(e[0]), (x, x))
            ends[id(e[0])] = (min(a_, x), max(b_, x))
    for x, pc, smp, de, he, tail in [(x,) + e for x, es in cols.items() for e in es]:
        xs = range(*pc.get('fill', pc['x']))   # where the body's material is read
        edge = x in (pc['x'][0], pc['x'][1] - 1) or x in ends[id(pc)]
        bands = {}
        wallrow = {}
        for (row, hv, dv, kind) in smp:
            if hv not in bands:
                bands[hv] = pack(mode_colour(img, row, xs))
            if kind == 'wall' and hv not in wallrow:
                wallrow[hv] = row
        top_d = {}
        for (row, hv, dv, kind) in smp:
            top_d[dv] = max(top_d.get(dv, -1), hv)
        last = smp[-1] if smp else None
        if last and tail:
            dl = max(top_d)
            for t in range(1, tail + 1):
                top_d[dl + t] = top_d[dl]
        d_front = min(top_d) if top_d else 0
        d_back = max(top_d) if top_d else 0
        side = pc.get('side')
        # wall rows a gable end repeats: the upper wall, without its top two
        # rows (the eave's shadow line)
        wr = [wallrow[k] for k in sorted(wallrow)]
        gable_rows = wr[-10:-2] or wr[:]
        # solid fill under the path
        cut = pc.get('cutout')
        if cut and 'towers' not in pc:
            # a card of its own pixels (gantries, a rocket) is towers and gaps:
            # each run of columns that is drawn through most of the card's rows
            # is one tower, and its sides cycle its own columns (a lattice tower
            # shows its lattice all round, not the row's average colour)
            rows_ = sorted(set(wallrow.values()))
            op = [np.mean([img[r_, xx, 3] >= 128 for r_ in rows_]) if rows_ else 0 for xx in range(W)]
            tw, xx = [], pc['x'][0]
            while xx < pc['x'][1]:
                if op[xx] < .3: xx += 1; continue
                a_ = xx
                while xx < pc['x'][1] and op[xx] >= .3: xx += 1
                tw.append((a_, xx))
            pc['towers'] = tw
        for dv, hv in top_d.items():
            di = dv + PAD
            for hh in range(hv + 1):
                # cutout: a card of its own pixels (gantry lattice, a rocket):
                # only the heights whose wall pixel is drawn are solid
                if cut and (wallrow.get(hh) is None or img[wallrow[hh], x, 3] < 128):
                    continue
                occ[x, hh, di] = True
                solid[x, hh, di] = bands.get(hh, bands.get(max(bands) if bands else 0, pack((128, 128, 128))))
                r = wallrow.get(hh)
                if cut and r is not None:
                    t_ = [t for t in pc['towers'] if t[0] <= x < t[1]]
                    c = pixcol(t_[0][0] + (dv - d_front) % (t_[0][1] - t_[0][0]), r) if t_ else -1
                    c = c if c >= 0 else pixcol(x, r)
                    if c >= 0:
                        colE[x, hh, di] = c
                if r is None:
                    # above the walls (a gable end): the side takes more
                    # courses of the wall itself, not bands of roof colour
                    if side and gable_rows and edge:
                        sa, sb = pc.get('gside') or side   # (plain wall courses, no window bay)
                        c = pixcol(sa + (dv - d_front) % (sb - sa), gable_rows[hh % len(gable_rows)])
                        if c >= 0:
                            colE[x, hh, di] = c
                    continue
                # a painted chamfer is a staircase of 1-px steps: every step's
                # side is exposed, so every column gets the side art
                if side:
                    sa, sb = side
                    c = pixcol(sa + (dv - d_front) % (sb - sa), r)
                    if c >= 0:
                        sideE[x, hh, di] = c
                        if pc.get('paint') or edge:
                            colE[x, hh, di] = c
                if pc.get('back') == 'front' and dv == d_back:
                    c = pixcol(x, r)
                    if c >= 0:
                        colN[x, hh, di] = c
                elif side and dv == d_back:
                    # a plain back wall: the side's own columns laid across it
                    sa, sb = side
                    c = pixcol(sa + (x - pc['x'][0]) % (sb - sa), r)
                    if c >= 0:
                        colN[x, hh, di] = c
        paint = pc.get('paint')
        for (row, hv, dv, kind) in smp:
            di = dv + PAD
            # paint=(a,b): a chamfered corner's columns take the plain wall's
            # columns a..b-1 (cycled) instead of their own pixels, which are
            # the drawing's diagonal rim (vertical stripes in 3D)
            c = pixcol(paint[0] + (x - pc['x'][0]) % (paint[1] - paint[0]), row) if paint and kind == 'wall' else pixcol(x, row)
            # plainx=(xa, xb, shift): repeated roof rows under a roof fitting
            # (a vent) take the plain roof `shift` px to the side instead of
            # repeating the fitting
            px_ = pc.get('plainx')
            if kind == 'flatr' and px_ and px_[0] <= x < px_[1] and 0 <= x - px_[2] < W:
                c = pixcol(x - px_[2], row)
            if c >= 0:
                if kind in ('wall', 'slope', 'rise'):
                    colS[x, hv, di] = c
                if kind in ('flat', 'flatr', 'slope', 'tread'):
                    colT[x, hv, di] = c
            pix.setdefault((x, row), []).append((hv, dv, kind))   # a repeated roof row lands on several cells
        if last and tail:
            row, hv, dv, kind = last
            c = pixcol(x, row)
            # roofRow: the roof behind takes this drawing row's colour (a red
            # roof deck behind a railing), the column's own pixel
            rr = pc.get('roofRow')
            if rr is not None:
                c = pixcol(x, rr)
            dl = max(top_d) - tail
            for t in range(1, tail + 1):
                di = dl + t + PAD
                if c >= 0 and (kind != 'wall' or rr is not None):   # a wall's top row is not a roof: leave material
                    colT[x, hv, di] = c
    # edge columns that are ground in the drawing are not building: a house drawn a few px in from its
    # cells' edge (its outline at column 2, lawn at 0-1) stood that much wider than its picture, the
    # front's first columns painted over the lawn (defect_scan 'ground'). Only piece-built models
    # (autorecipe, explicit.py); hand volumes carve themselves.
    # (the wall's rows only: a roof drawn over those columns stays, an eave over the lawn)
    if recipe.get('pieces') and (recipe.get('src') or recipe.get('inv')) and EDGE_TRIM:
        pc0 = recipe['pieces'][0]
        wall = sum(sg[1] for sg in pc0.get('segs', []) if sg[0] == 'wall')
        B0 = pc0.get('B', H - 1)
        gcols = ground_columns(art_src(recipe), img0, (max(0, B0 - wall + 1), B0 + 1)) if wall else None
        if gcols is not None:
            for xs in (range(0, EDGE_TRIM), range(W - 1, W - 1 - EDGE_TRIM, -1)):
                for x in xs:
                    if not gcols[x]: break
                    occ[x, :wall] = False; colS[x, :wall] = -1; colT[x, :wall] = -1; colE[x, :wall] = -1; colN[x, :wall] = -1
    # a wall cell whose side is open though its column is not a piece's end (an
    # upper storey set back from the one below, a notch in the footprint) takes
    # the side art too, not the row's flat band colour
    open_ = np.zeros_like(occ)
    open_[1:] |= ~occ[:-1]; open_[:-1] |= ~occ[1:]; open_[0] = True; open_[-1] = True
    m_ = occ & open_ & (colE < 0) & (sideE >= 0)
    colE[m_] = sideE[m_]
    apply_relief(img, recipe.get('relief', []), pix, occ, colS, colT, solid)
    apply_prisms(img, recipe.get('prisms', []), occ, colS, colT, solid)
    apply_volumes(img, recipe.get('volumes', []), occ, colS, colT, colE, colN, solid)
    return dict(occ=occ, colS=colS, colT=colT, colE=colE, colN=colN, solid=solid, W=W, HH=HH, DD=DD)


# ---------------------------------------------------------------- volumes
# Solids of any plan the drawing implies, after Emerald 3DS's PlanPrism, PlanPyramid, lathe and
# superellipse slab (3ds_port/scripts/voxel_building.py; MIT, Copyright (c) 2026 Zallax and Emerald 3DS
# contributors): an octagonal base, an eight-sided spire, a round hut's thatch cone. Coordinates are
# ours: x = art column, d = depth (0 = the front at the foot), h = height; a voxel shows art row
# B - h - d. Converting a 3DS spec: x = X, h = Y, d = B - Z.
def _inside_poly(px, py, poly):
    inside, n = False, len(poly)
    for i in range(n):
        (x1, y1), (x2, y2) = poly[i], poly[(i + 1) % n]
        if (y1 > py) != (y2 > py) and px < x1 + (py - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


def _profile(profs, t):
    """The radius at height t over a lathe's foot: the widest of its profiles [(dh, r), ...]."""
    best = None
    for prof in profs:
        for (h0, r0), (h1, r1) in zip(prof, prof[1:]):
            if h0 <= t <= h1:
                r = r0 + (r1 - r0) * ((t - h0) / (h1 - h0) if h1 > h0 else 0)
                best = r if best is None else max(best, r)
    return best


def _catmull(pts, n):
    """n+1 points on a uniform Catmull-Rom curve through pts (tuples, every component
    interpolated; the ends repeated)."""
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(n + 1):
        f = i / float(n) * (len(pts) - 1)
        k = min(int(f), len(pts) - 2); t = f - k
        p0, p1, p2, p3 = P[k], P[k + 1], P[k + 2], P[k + 3]
        out.append(tuple(.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - e) * t * t + (-a + 3 * b - 3 * c + e) * t ** 3)
                         for a, b, c, e in zip(p0, p1, p2, p3)))
    return out


def volume_inside(v):
    s = v['shape']
    if s == 'plan':           # a prism standing on a polygon plan: poly=[(x, d), ...], h=(h0, h1)
        poly, (h0, h1) = v['poly'], v['h']
        return lambda x, d, h: h0 <= h < h1 and _inside_poly(x + .5, d + .5, poly)
    if s == 'pyramid':        # the polygon shrinking to apex=(x, d, h) from its base at h0
        poly, h0, (ax, ad, ah) = v['poly'], v['h0'], v['apex']

        def pyr(x, d, h):
            if not (h0 <= h < ah):
                return False
            k = 1 - (h + .5 - h0) / (ah - h0)
            return k > 0 and _inside_poly(ax + (x + .5 - ax) / k, ad + (d + .5 - ad) / k, poly)
        return pyr
    if s == 'lathe':          # round, centre c=(x, d), foot h0, radius by profile(s); squash = depth/width
        (cx, cd), h0, sq = v['c'], v['h0'], v.get('squash', .5)
        profs = v['prof'] if isinstance(v['prof'][0][0], (list, tuple)) else [v['prof']]

        def lathe(x, d, h):
            r = _profile(profs, h + .5 - h0)
            return bool(r and r > 0) and ((x + .5 - cx) / r) ** 2 + ((d + .5 - cd) / (r * sq)) ** 2 <= 1.0
        return lathe
    if s == 'super':          # a rounded wall: superellipse plan c=(x, d), r=(rx, rd), exponent p, h=(h0, h1)
        (cx, cd), (rx, rd), p, (h0, h1) = v['c'], v['r'], v.get('p', 8.0), v['h']
        return lambda x, d, h: h0 <= h < h1 and abs((x + .5 - cx) / rx) ** p + abs((d + .5 - cd) / rd) ** p <= 1.0
    if s == 'dome':           # a superellipse dome: plan c=(x, d), r=(rx, rd), exponent p, crown height top
        (cx, cd), (rx, rd), p, top = v['c'], v['r'], v.get('p', 2.0), v['top']
        pl, pr = v.get('pl', p), v.get('pr', p)   # the x term's exponent west / east of the centre and the
        rxr = v.get('rxr', rx)                    # east radius (a dome drawn fuller on one side)

        def dome(x, d, h):        # (fuller than 3DS's S^(2/p) + (h/top)^2 <= 1: the Battle Dome's drawn
            u = (x + .5 - cx) / (rx if x + .5 < cx else rxr)                     # shell is boxy, 13% off vs 15%)
            S_ = abs(u) ** (pl if u < 0 else pr) + abs((d + .5 - cd) / rd) ** p
            return S_ < 1 and S_ + ((h + .5) / top) ** 2 <= 1.0
        return dome
    if s == 'union':          # 3DS's Volume: parts ('tube', [(x, h, d, r), ...]) (a Catmull-Rom curve),
        fs = []               # ('dome', cx, cd, rx, rd, top, p), ('box', x0, x1, h0, h1, d0, d1)
        for part in v['parts']:
            if part[0] == 'tube':
                path = _catmull(part[1], 48)
                segs = list(zip(path, path[1:]))

                def tube(x, d, h, segs=segs):
                    q = (x + .5, h + .5, d + .5)
                    for a, b in segs:
                        dv = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
                        dd = dv[0] ** 2 + dv[1] ** 2 + dv[2] ** 2 or 1e-9
                        t = max(0.0, min(1.0, sum((q[k] - a[k]) * dv[k] for k in range(3)) / dd))
                        r = a[3] + (b[3] - a[3]) * t
                        if sum((q[k] - a[k] - dv[k] * t) ** 2 for k in range(3)) <= r * r:
                            return True
                    return False
                fs.append(tube)
            elif part[0] == 'dome':
                fs.append(volume_inside(dict(shape='dome', c=part[1:3], r=part[3:5], top=part[5], p=part[6])))
            elif part[0] == 'box':
                x0, x1, h0, h1, d0, d1 = part[1:]
                fs.append(lambda x, d, h, b=(x0, x1, h0, h1, d0, d1): b[0] <= x < b[1] and b[2] <= h < b[3] and b[4] <= d < b[5])
        return lambda x, d, h: any(f(x, d, h) for f in fs)
    raise ValueError('unknown volume shape %r' % s)


def volume_extent(v):
    """(d0, d1, h1): the depth range and the top a volume may reach (for the model's room)."""
    s = v['shape']
    if s in ('plan', 'pyramid'):
        ds = [q[1] for q in v['poly']]
        top = v['h'][1] if s == 'plan' else v['apex'][2]
        return int(math.floor(min(ds))), int(math.ceil(max(ds))), int(math.ceil(top))
    if s == 'lathe':
        profs = v['prof'] if isinstance(v['prof'][0][0], (list, tuple)) else [v['prof']]
        rmax = max(r for prof in profs for _, r in prof)
        hmax = max(dh for prof in profs for dh, _ in prof)
        cd, sq = v['c'][1], v.get('squash', .5)
        return int(math.floor(cd - rmax * sq)), int(math.ceil(cd + rmax * sq)), int(math.ceil(v['h0'] + hmax))
    if s == 'super':
        cd, rd = v['c'][1], v['r'][1]
        return int(math.floor(cd - rd)), int(math.ceil(cd + rd)), int(v['h'][1])
    if s == 'dome':
        cd, rd = v['c'][1], v['r'][1]
        return int(math.floor(cd - rd)), int(math.ceil(cd + rd)), int(math.ceil(v['top']))
    if s == 'union':
        lo, hi, top = [], [], []
        for part in v['parts']:
            if part[0] == 'tube':
                lo += [q[2] - q[3] for q in part[1]]; hi += [q[2] + q[3] for q in part[1]]; top += [q[1] + q[3] for q in part[1]]
            elif part[0] == 'dome':
                lo.append(part[2] - part[4]); hi.append(part[2] + part[4]); top.append(part[5])
            else:
                lo.append(part[5]); hi.append(part[6]); top.append(part[4])
        return int(math.floor(min(lo))), int(math.ceil(max(hi))), int(math.ceil(max(top)))
    raise ValueError('unknown volume shape %r' % s)


def apply_volumes(img, vols, occ, colS, colT, colE, colN, solid):
    """Each volume's voxels are filled, and every face the camera can see is painted by projecting
    it back onto the drawing (art row B - h - d), so head-on the solid is exactly the drawing.
    Faces the drawing never shows take the building's OWN pixels, never another tile's:
      side=(u0, u1[, r0, r1]) the facade columns u0..u1 repeated along the hidden face, each at the
                             drawing row of the front at that height (3DS's side strip), the rows
                             optionally kept in r0..r1 (the clean wall, not the shadow at its foot);
      wrap=(u0, u1, r0, r1)  that strip of the drawing run round a round solid by angle (thatch);
      neither                the volume's material colour `mat`=(x, row).
      mirror=dm              a round solid's far half (depth past dm) takes the drawing of the near
                             half at the mirrored depth 2*dm - d (3DS's mirror_z): a dome seen from
                             behind shows its own ribs and rim, not one flat material;
      corner=(c0, c1)        with side: a hidden wall cell k px (plan distance) from one of the plan
                             polygon's vertices takes facade column c0+k while k < c1-c0, so every
                             vertical edge wears the outline, highlight and shadow the drawing gives
                             its front corners (a white stucco wall is framed, not a flat slab).
    v: shape (see volume_inside), B, rows=(r0, r1) its own art rows, mat."""
    H, W = img.shape[:2]
    for v in vols:
        inside, B = volume_inside(v), v['B']
        r0, r1 = v.get('rows', (0, H))
        mat = pack(img[v['mat'][1], v['mat'][0], :3])
        roofc = pack(img[v['roof'][1], v['roof'][0], :3]) if v.get('roof') else mat
        side, wrap = v.get('side'), v.get('wrap')
        corner = v.get('corner') if v.get('poly') else None
        # repeat=P: a tower taller than its drawing. A drawing row above the top (row < 0) is the row
        # P rows below it, so the drawing's facade module (window row + plain row) runs on up the front
        # and the hidden walls; the flat top of the solid takes `roof` (default `mat`).
        rep = v.get('repeat')

        def art(x, row):
            if rep and row < 0:
                row %= rep
            if not (r0 <= row < r1 and 0 <= row < H and 0 <= x < W):
                return -1
            q = img[row, x]
            return pack(q[:3]) if q[3] >= 128 else -1
        d0, d1, h1 = volume_extent(v)
        cells = {(x, d, h) for x in range(W) for d in range(d0 - 1, d1 + 2) for h in range(0, h1 + 1)
                 if d + PAD >= 0 and inside(x, d, h)}
        if v.get('carve'):
            # silhouette carving: a cell whose exposed front or top projects onto the ground (a
            # transparent / keyed pixel inside the drawing) is not there - the solid shrinks to the
            # drawn outline (a dome wider than the head it stands for loses its flare)
            for _ in range(200):
                gone = [c for c in cells if 0 <= B - c[2] - c[1] < H and art(c[0], B - c[2] - c[1]) < 0
                        and ((c[0], c[1] - 1, c[2]) not in cells or (c[0], c[1], c[2] + 1) not in cells)]
                if not gone:
                    break
                cells.difference_update(gone)
        if not cells:
            continue
        # recess=[(xa, xb, ra, rb, k)]: the drawing's pixels x in xa..xb-1, rows ra..rb-1 (rows above the top
        # count, with `repeat`) sit k voxels back from a front plane at depth 0 -- a window in its wall.
        # The set-back face keeps its pixel at the height it is drawn at (painted below); the notch's sides
        # and sill are the usual hidden-face paint.
        for (xa, xb, ra, rb, k) in v.get('recess', []):
            for row in range(ra, rb):
                for x in range(xa, xb):
                    for d in range(k):
                        cells.discard((x, d, B - row))
        front = {}                                   # the front plane's depth at each height
        tops = {}                                    # the top cell of each column (x, d)
        for (x, d, h) in cells:
            front[h] = min(front.get(h, d), d)
            tops[(x, d)] = max(tops.get((x, d), -1), h)
        cx = (min(c[0] for c in cells) + max(c[0] for c in cells)) / 2.0
        cd = (min(c[1] for c in cells) + max(c[1] for c in cells)) / 2.0

        mir = v.get('mirror')

        carry = v.get('carry')

        def hidden(x, d, h, wall=False):
            if carry is not None:
                # carry=(axis x, k): a round body's hidden faces wear what its back shows from above
                # at the point k of the way out from the axis (a snake's sides continue its back)
                xc = int(carry[0] + (x + .5 - carry[0]) * carry[1])
                hh = tops.get((xc, d))
                if hh is not None:
                    c = art(xc, B - hh - d)
                    if c >= 0:
                        return c
                return mat
            if v['shape'] == 'dome' and mir is not None:
                # the side quarters (|u| > |w|) carry on what the front shows at that height: the
                # front surface's colour at a column near the silhouette, inside it (the belt and the
                # shell run round the dome; the drawing's own edge column is outline and lawn)
                (cx_, cd_), (rx_, rd_), p_, top_ = v['c'], v['r'], v.get('p', 2.0), v['top']
                if x + .5 >= cx_:
                    rx_ = v.get('rxr', rx_)
                u_, w_ = (x + .5 - cx_) / rx_, (d + .5 - cd_) / rd_
                if abs(u_) > abs(w_):
                    px_ = v.get('pl', p_) if u_ < 0 else v.get('pr', p_)
                    lim = max(0.0, 1 - ((h + .5) / top_) ** 2)   # the plan's S at this height
                    us = min(.85, .9 * lim ** (1 / px_))
                    q_ = lim - us ** px_
                    if q_ > 0:
                        df = cd_ - rd_ * q_ ** (1 / p_)
                        c = art(int(cx_ + math.copysign(us * rx_, u_)), int(round(B - h - df)))
                        if c >= 0:
                            return c
                    return mat
            if mir is not None:
                c = art(x, B - h - (2 * mir - d if d > mir else d))
                if c >= 0:
                    return c
            if wrap:
                u0, u1, w0, w1 = wrap
                ang = math.atan2(d - cd, x - cx)
                u = u0 + int((ang + math.pi) / (2 * math.pi) * 4 * max(1, u1 - u0)) % (u1 - u0)
                q = img[w0 + (h1 - h) % (w1 - w0), u]
                return pack(q[:3]) if q[3] >= 128 else mat
            if side:
                u0, u1 = side[0], side[1]
                row = B - h - front[h]
                if rep and row < 0:
                    row %= rep
                if len(side) == 4:                   # (u0, u1, r0, r1): rows kept inside the clean wall band,
                    row = min(max(row, side[2]), side[3] - 1)   # not the ground shadow drawn at its foot
                if wall and corner:
                    k = int(min(math.hypot(x + .5 - px_, d + .5 - pd_) for px_, pd_ in v['poly']))
                    if k < corner[1] - corner[0]:
                        c = art(corner[0] + k, row)
                        if c >= 0:
                            return c
                c = art(u0 + (d + x) % (u1 - u0), row)
                return c if c >= 0 else mat
            return mat
        for (x, d, h) in cells:
            di = d + PAD
            occ[x, h, di] = True
            solid[x, h, di] = mat
            colS[x, h, di] = colT[x, h, di] = colE[x, h, di] = colN[x, h, di] = -1
        def far(x, d):
            # a round solid's far half and side quarters are not in the drawing at all: every face
            # there takes the mirrored / carried-round colour (the drawing row a far cell's top
            # projects to is the crown or the sky above it, which speckled the shell white)
            # (the side quarters' tops and fronts stay the drawing: the play camera sees them)
            return mir is not None and d > mir
        for (x, d, h) in cells:
            di = d + PAD
            fr = far(x, d)
            # above the drawing's top edge (a crown the cell rect cuts off) there is no drawing:
            # the solid's own material, not a mirrored row
            top_ = mir is not None and B - h - d < 0
            if (x, d - 1, h) not in cells:           # seen head-on: the drawing at its own row
                c = mat if top_ else -1 if fr else art(x, B - h - d)
                colS[x, h, di] = c if c >= 0 else hidden(x, d, h)
            if (x, d, h + 1) not in cells:           # seen from above: the drawing at its own row
                c = mat if top_ else -1 if fr else art(x, B - h - d)
                if rep and tops[(x, d)] == h and B - h - d < 0:
                    c = roofc                        # the top of a repeated tower is its roof, not a facade row
                colT[x, h, di] = c if c >= 0 else hidden(x, d, h)
            if (x - 1, d, h) not in cells or (x + 1, d, h) not in cells:
                colE[x, h, di] = hidden(x, d, h, True)
            if (x, d + 1, h) not in cells:
                colN[x, h, di] = hidden(x, d, h, True)
        for (xa, xb, ra, rb, k) in v.get('recess', []):
            for row in range(ra, rb):
                for x in range(xa, xb):
                    c = art(x, row)
                    if c >= 0 and (x, k, B - row) in cells and (x, k - 1, B - row) not in cells:
                        colS[x, B - row, k + PAD] = c


def apply_relief(img, rects, pix, occ, colS, colT, solid):
    off = {}
    for r in rects:
        xa, xb = r['x']
        ra, rb = r['rows']
        for x in range(xa, xb):
            for row in range(ra, rb):
                if (x, row) in pix:
                    off[(x, row)] = r['k']
    # a drawing pixel that landed on several cells: the last one, as before,
    # plus every repeated-course copy of it (a parapet over a deepened roof)
    cellsof = lambda key: list(dict.fromkeys([c for c in pix[key] if c[2] == 'flatr'] + [pix[key][-1]]))
    for ((x, row), k), (hv, dv, kind) in [(it, cell) for it in off.items() for cell in cellsof(it[0])]:
        if k == 0:
            continue
        di = dv + PAD
        p = img[row, x]
        c = pack(p[:3]) if p[3] >= 128 else -1
        if kind in ('wall', 'slope', 'rise'):
            if k > 0:
                for t in range(k):
                    occ[x, hv, di + t] = False
                    colS[x, hv, di + t] = -1
                    colT[x, hv, di + t] = -1
                if di + k < occ.shape[2] and occ[x, hv, di + k] and c >= 0:
                    colS[x, hv, di + k] = c
            else:
                m = -k
                for t in range(1, m + 1):
                    occ[x, hv, di - t] = True
                    solid[x, hv, di - t] = c if c >= 0 else solid[x, hv, di]
                colS[x, hv, di] = -1
                if c >= 0:
                    colS[x, hv, di - m] = c
        else:
            if k > 0:
                for t in range(k):
                    occ[x, hv - t, di] = False
                    colS[x, hv - t, di] = -1
                    colT[x, hv - t, di] = -1
                if hv - k >= 0 and c >= 0:
                    colT[x, hv - k, di] = c
            else:
                m = -k
                for t in range(1, m + 1):
                    occ[x, hv + t, di] = True
                    solid[x, hv + t, di] = c if c >= 0 else solid[x, hv, di]
                colT[x, hv, di] = -1
                if c >= 0:
                    colT[x, hv + m, di] = c


def apply_prisms(img, prisms, occ, colS, colT, solid):
    """Solid boxes standing on the model (a vent on the ridge, a chimney).
    Each face is painted by projecting it back onto the drawing: a voxel at
    height h and depth d shows art row B - h - d (Gen 3's oblique view), so the
    box looks exactly like the drawing head-on and has real depth turned.
    Pixels outside the prism's own art (roof showing round a round vent) and
    hidden faces take its material colour `mat`.
    p: x=(a,b), d=(d0,d1), h=(h0,h1), B=bottom art row, mat=(x,row),
       rows=(r0,r1) its art rows, round=True for an elliptic footprint."""
    H = img.shape[0]
    for p in prisms:
        xa, xb = p['x']; d0, d1 = p['d']; h0, h1 = p['h']; B = p['B']
        r0, r1 = p.get('rows', (0, H))
        mat = pack(img[p['mat'][1], p['mat'][0], :3])
        grey = p.get('grey')

        def art(x, row):
            if not (r0 <= row < r1) or not (0 <= row < H):
                return mat
            q = img[row, x]
            if q[3] < 128:
                return mat
            if grey is not None:
                r, g, b = (int(v) for v in q[:3])
                if max(r, g, b) - min(r, g, b) > grey:   # roof colour, not the vent
                    return mat
            return pack(q[:3])
        cx, cd = (xa + xb - 1) / 2.0, (d0 + d1 - 1) / 2.0
        rx, rd = (xb - xa) / 2.0, (d1 - d0) / 2.0
        # wrap=(u0, u1, r0, r1): a round prism is painted all the way round
        # with the drawing's strip u0..u1 x rows r0..r1, laid along its
        # circumference (thatch or weave running round a hut, not a picture
        # projected onto its front and draped over its top)
        wrap = p.get('wrap')

        def wrapped(x, d, h):
            u0, u1, w0, w1 = wrap
            ang = math.atan2(d - cd, x - cx)
            circ = 2 * math.pi * max(rx, rd)
            u = u0 + int(((ang + math.pi) / (2 * math.pi)) * circ) % (u1 - u0)
            r = w0 + (h1 - 1 - h) % (w1 - w0)
            q = img[r, u]
            return pack(q[:3]) if q[3] >= 128 else mat
        for x in range(xa, xb):
            for d in range(d0, d1):
                if p.get('round') and ((x - cx) / rx) ** 2 + ((d - cd) / rd) ** 2 > 1.0:
                    continue
                di = d + PAD
                for h in range(h0, h1):
                    occ[x, h, di] = True
                    solid[x, h, di] = wrapped(x, d, h) if wrap else mat
                    colS[x, h, di] = -1
                    colT[x, h, di] = -1
                # front face: the first voxel of this column toward the viewer
                front = d == d0 or (p.get('round') and ((x - cx) / rx) ** 2 + ((d - 1 - cd) / rd) ** 2 > 1.0)
                if front:
                    for h in range(h0, h1):
                        colS[x, h, di] = wrapped(x, d, h) if wrap else art(x, B - h - d)
                colT[x, h1 - 1, di] = wrapped(x, d, h1 - 1) if wrap else art(x, B - (h1 - 1) - d)


# ---------------------------------------------------------------- meshing
def mesh(v):
    occ, colS, colT, solid = v['occ'], v['colS'], v['colT'], v['solid']
    colE, colN = v['colE'], v['colN']
    W, HH, DD = occ.shape
    quads = []

    def emit(face, x, h, di, n, c):
        zf = -(di - PAD)
        if face == 'south':
            q = [(x, h, zf), (x + n, h, zf), (x + n, h + 1, zf), (x, h + 1, zf)]
        elif face == 'north':
            zb = zf - 1
            q = [(x + n, h, zb), (x, h, zb), (x, h + 1, zb), (x + n, h + 1, zb)]
        elif face == 'top':
            q = [(x, h + 1, zf), (x + n, h + 1, zf), (x + n, h + 1, zf - 1), (x, h + 1, zf - 1)]
        elif face == 'east':
            q = [(x + 1, h, zf), (x + 1, h, zf - n), (x + 1, h + 1, zf - n), (x + 1, h + 1, zf)]
        else:
            q = [(x, h, zf - n), (x, h, zf), (x, h + 1, zf), (x, h + 1, zf - n)]
        quads.append((face, q, c))

    def pick(prim, x, h, d):
        c = prim[x, h, d]
        return int(c) if c >= 0 else int(solid[x, h, d])

    sh = lambda a, ax: np.roll(a, ax[0], axis=ax[1])
    front_free = ~sh(occ, (1, 2))        # neighbour at di-1 empty
    front_free[:, :, 0] = True
    back_free = ~sh(occ, (-1, 2)); back_free[:, :, -1] = True
    top_free = ~sh(occ, (-1, 1)); top_free[:, -1, :] = True
    east_free = ~sh(occ, (-1, 0)); east_free[-1, :, :] = True
    west_free = ~sh(occ, (1, 0)); west_free[0, :, :] = True
    # runs along x for south / north / top
    for face, free, prim in (('south', front_free, colS), ('north', back_free, colN), ('top', top_free, colT)):
        m = occ & free
        idx = np.argwhere(m)
        # sort by (h, d, x)
        order = np.lexsort((idx[:, 0], idx[:, 2], idx[:, 1]))
        idx = idx[order]
        run = None
        for (x, h, d) in idx:
            c = pick(prim, x, h, d)
            if run and run[1] == h and run[2] == d and run[0] + run[3] == x and run[4] == c:
                run[3] += 1
            else:
                if run:
                    emit(face, run[0], run[1], run[2], run[3], run[4])
                run = [x, h, d, 1, c]
        if run:
            emit(face, run[0], run[1], run[2], run[3], run[4])
    for face, free in (('east', east_free), ('west', west_free)):
        m = occ & free
        idx = np.argwhere(m)
        order = np.lexsort((idx[:, 2], idx[:, 1], idx[:, 0]))
        idx = idx[order]
        run = None
        for (x, h, d) in idx:
            # an unpainted side (a step of a slanted wall, a window's reveal)
            # takes the colour of its own front face before the body's material
            c = int(colE[x, h, d]) if colE[x, h, d] >= 0 else (int(colS[x, h, d]) if colS[x, h, d] >= 0 else int(solid[x, h, d]))
            if run and run[0] == x and run[1] == h and run[2] + run[3] == d and run[4] == c:
                run[3] += 1
            else:
                if run:
                    emit(face, run[0], run[1], run[2], run[3], run[4])
                run = [x, h, d, 1, c]
        if run:
            emit(face, run[0], run[1], run[2], run[3], run[4])
    return quads


# ---------------------------------------------------------------- rendering
from gamecam import Camera


def render(quads, v, level=4, yaw=0.0, vw=640, vh=560, bg=(26, 28, 34), scale=2):
    W, HH, DD = v['W'], v['HH'], v['DD']
    cx, cz = W / 2.0, -(DD / 2.0 - PAD)
    cyw, syw = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cam = Camera(vw, vh, level, ground=0.0, cx=0.0, cz=0.0)
    m = cam.mvp
    canvas = np.zeros((vh, vw, 3), np.uint8)
    canvas[:, :] = bg
    zb = np.full((vh, vw), 1e18)

    def tr(p):
        x, y, z = p[0] - cx, p[1], p[2] - cz
        return (x * cyw - z * syw, y, x * syw + z * cyw)

    for face, q, c in quads:
        pts = [tr(p) for p in q]
        scr, zs = [], []
        for (x, y, z) in pts:
            w = m[12] * x + m[13] * y + m[14] * z + m[15]
            sx = ((m[0] * x + m[1] * y + m[2] * z + m[3]) / w + 1) * 0.5 * vw
            sy = ((m[4] * x + m[5] * y + m[6] * z + m[7]) / w + 1) * 0.5 * vh
            scr.append((sx, sy))
            zs.append((m[8] * x + m[9] * y + m[10] * z + m[11]) / w)
        # facing test: skip back-facing quads under yaw
        (ax, ay), (bx, by), (dx, dy) = scr[0], scr[1], scr[3]
        if (bx - ax) * (dy - ay) - (by - ay) * (dx - ax) == 0:
            continue
        colr = np.array(unpack(c), float) * SHADE[face]
        colr = np.clip(colr, 0, 255).astype(np.uint8)
        for tri in ((0, 1, 2), (0, 2, 3)):
            P = [scr[i] for i in tri]
            Z = [zs[i] for i in tri]
            xa = max(0, int(math.floor(min(p[0] for p in P))))
            xb = min(vw - 1, int(math.ceil(max(p[0] for p in P))))
            ya = max(0, int(math.floor(min(p[1] for p in P))))
            yb = min(vh - 1, int(math.ceil(max(p[1] for p in P))))
            if xb < xa or yb < ya:
                continue
            (x0, y0), (x1, y1), (x2, y2) = P
            det = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
            if abs(det) < 1e-9:
                continue
            gx, gy = np.meshgrid(np.arange(xa, xb + 1) + 0.5, np.arange(ya, yb + 1) + 0.5)
            w0 = ((y1 - y2) * (gx - x2) + (x2 - x1) * (gy - y2)) / det
            w1 = ((y2 - y0) * (gx - x2) + (x0 - x2) * (gy - y2)) / det
            w2 = 1 - w0 - w1
            e = -1e-3
            inside = (w0 >= e) & (w1 >= e) & (w2 >= e)
            if not inside.any():
                continue
            z = w0 * Z[0] + w1 * Z[1] + w2 * Z[2]
            sub = zb[ya:yb + 1, xa:xb + 1]
            ok = inside & (z < sub)
            if ok.any():
                sub[ok] = z[ok]
                canvas[ya:yb + 1, xa:xb + 1][ok] = colr
    im = Image.fromarray(canvas)
    return im


def crop_to_content(im, bg=(26, 28, 34), pad=8):
    a = np.array(im)
    mask = (a != np.array(bg)).any(axis=2)
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return im
    return im.crop((max(0, xs.min() - pad), max(0, ys.min() - pad),
                    min(im.width, xs.max() + pad), min(im.height, ys.max() + pad)))


def art_src(recipe):
    """(pair, map, x0, y0, x1, y1) of a recipe's drawing: its own src, or its inventory box and crop."""
    if 'src' in recipe:
        return recipe['src']
    cat = {e['n']: e for e in json.load(open(os.path.join(ROOT, 'shots_inv/catalogue.json')))}
    e = cat[recipe['inv']]
    x0, y0, x1, y1 = e['box']
    dx0, dy0, dx1, dy1 = recipe.get('crop', (0, 0, 0, 0))
    return (e['pair'], e['map'], x0 + dx0, y0 + dy0, x1 + dx1, y1 + dy1)


def load_art(recipe):
    import bldmodel as M
    if 'src' in recipe:                      # explicit (pair, map, x0, y0, x1, y1)
        return M.compose(*recipe['src'])
    cat = {e['n']: e for e in json.load(open(os.path.join(ROOT, 'shots_inv/catalogue.json')))}
    e = cat[recipe['inv']]
    x0, y0, x1, y1 = e['box']
    dx0, dy0, dx1, dy1 = recipe.get('crop', (0, 0, 0, 0))
    return M.compose(e['pair'], e['map'], x0 + dx0, y0 + dy0, x1 + dx1, y1 + dy1)


def export(name, rec, img, quads, v, path):
    """Geometry-only model for the game (lib/BuildingVoxels.lua).

    Every face colour came from a pixel of the drawing, so each quad records
    the coordinates of a pixel with that colour instead of the colour: the
    game paints it from the player's own tiles. Nothing ROM-derived is
    written. Faces: 1 south, 2 north, 3 top, 4 east, 5 west; x and h in art
    pixels, z = -(depth) from the facade line at the building's front edge."""
    if 'src' in rec:
        pair_, map_, x0, y0, x1, y1 = rec['src']
        e = {'map': map_, 'pair': pair_}
    else:
        cat = {e['n']: e for e in json.load(open(os.path.join(ROOT, 'shots_inv/catalogue.json')))}
        e = cat[rec['inv']]
        x0, y0, x1, y1 = e['box']
        dx0, dy0, dx1, dy1 = rec.get('crop', (0, 0, 0, 0))
        x0, y0, x1, y1 = x0 + dx0, y0 + dy0, x1 + dx1, y1 + dy1
    H, W = img.shape[:2]
    where = {}
    for yy in range(H):
        for xx in range(W):
            p = img[yy, xx]
            if p[3] >= 128:
                where.setdefault(pack(p[:3]), (xx, yy))
    code = {'south': 1, 'north': 2, 'top': 3, 'east': 4, 'west': 5}
    out, missing = [], 0
    for face, q, c in quads:
        px, py = where.get(int(c), (None, None))
        if px is None:
            # a fill colour the drawing shows only under a key colour: take
            # the drawing's nearest colour instead of leaving a hole
            r, g, b = unpack(int(c))
            best = min(where, key=lambda k: sum((a - b2) ** 2 for a, b2 in zip(unpack(k), (r, g, b))))
            px, py = where[best]
            missing += 1
        xs = [p[0] for p in q]; hs = [p[1] for p in q]; zs = [p[2] for p in q]
        out.append('%d,%d,%d,%d,%d,%d,%d,%d,%d,%d' % (code[face], min(xs), max(xs), min(hs), max(hs),
                                                   min(zs), max(zs), px, py, 0))
    # the anchor: the building's facade cells must match for the model to apply
    import bldmodel as M
    W_, H_, cells = M.map_cells(e['map']) if hasattr(M, 'map_cells') else (None, None, None)
    sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
    import voxproto
    MW, MH, mc = voxproto.map_cells(e['map'])
    # anchor on the two rows above the facade's bottom row: towns redraw a
    # building's ground-level corners over their own paving (Rustboro's
    # Center), never its roof band
    skip = set(rec.get('bgtiles', [])) | set(rec.get('anchor_skip', []))
    anchor = [(x, y, mc[y * MW + x] & 0x3ff) for y in (y1 - 2, y1 - 1) for x in range(x0, x1 + 1)
              if (mc[y * MW + x] & 0x3ff) not in skip and (x - x0, y - y0) not in rec.get('anchor_skip_cells', [])]
    with open(path, 'w') as f:
        f.write('-- generated by tools/buildings/hf.py --export %s (geometry only)\n' % name)
        f.write('return {name=%r,map=%r,pair=%r,x0=%d,y0=%d,x1=%d,y1=%d,\n' % (name, e['map'], e['pair'], x0, y0, x1, y1))
        f.write(' anchor={%s},\n' % ','.join('{%d,%d,%d}' % a for a in anchor))
        # the source drawing's tiles: a family model is painted from these
        # (shared primary tiles) wherever it stands, not from local redraws
        tiles = [(x - x0, y - y0, mc[y * MW + x] & 0x3ff) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]
        f.write(' tiles={%s},\n' % ','.join('{%d,%d,%d}' % t for t in tiles))
        if rec.get('indoor'):
            f.write(' indoor=true,\n')
        if rec.get('claimBlocked'):
            f.write(' claimBlocked=true,\n')
        if rec.get('claimFrom'):
            # rows above this one (relative) are drawn by the model but stay
            # their own cells (the sea and grass under the Space Center rocket)
            f.write(' claimFrom=%d,\n' % rec['claimFrom'])
        if rec.get('standOn'):
            # the map cell whose floor the building stands on (a tower on a
            # plateau behind a cliff, whose own cells read the canyon floor)
            f.write(' standOn={%d,%d},\n' % tuple(rec['standOn']))
        f.write(' quads={\n')
        for i in range(0, len(out), 6):
            f.write('  ' + ','.join(out[i:i + 6]) + ',\n')
        f.write(' }}\n')
    print('exported', path, len(out), 'quads;', missing, 'painted by their nearest drawing colour')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('recipe')
    ap.add_argument('--levels', default='4,7')
    ap.add_argument('--yaws', default='0,90,180,270')
    ap.add_argument('--out', default=os.path.join(ROOT, 'shots_bld', 'hf'))
    ap.add_argument('--scale', type=int, default=3)
    ap.add_argument('--export', help='write the model as geometry-only Lua data (no colours)')
    args = ap.parse_args()
    import hf_recipes
    rec = hf_recipes.RECIPES[args.recipe]
    img = load_art(rec)
    print('art', img.shape)
    v = build(img, rec)
    q = mesh(v)
    print('voxels', int(v['occ'].sum()), 'quads', len(q))
    if args.export:
        export(args.recipe, rec, img, q, v, args.export)
    os.makedirs(args.out, exist_ok=True)
    for lv in [int(s) for s in args.levels.split(',')]:
        for yaw in [float(s) for s in args.yaws.split(',')]:
            im = crop_to_content(render(q, v, level=lv, yaw=yaw))
            im = im.resize((im.width * args.scale, im.height * args.scale), Image.NEAREST)
            p = os.path.join(args.out, '%s_l%d_y%03d.png' % (args.recipe, lv, yaw))
            im.save(p)
            print('wrote', p)
    # drawing for comparison
    bgc = Image.new('RGBA', (img.shape[1], img.shape[0]), (26, 28, 34, 255))
    bgc.alpha_composite(Image.fromarray(img))
    bgc.convert('RGB').resize((img.shape[1] * args.scale, img.shape[0] * args.scale), Image.NEAREST).save(
        os.path.join(args.out, '%s_art.png' % args.recipe))


if __name__ == '__main__':
    main()
