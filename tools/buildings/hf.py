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
        elif kind == 'gable':
            # A symmetric pitched roof as Gen 3 draws it: nf rows of front
            # slope up to the ridge line, then nb rows of the back slope seen
            # foreshortened above it (a point's screen row is height + depth,
            # so a slope falling away shows (1-s) rows per unit of depth).
            # Equal depths both sides give the pitch: s = (nf-nb)/(nf+nb).
            nf, nb = int(seg[1]), int(seg[2])
            sl = (nf - nb) / float(nf + nb)
            dd, dh = 1.0 / (1.0 + sl), sl / (1.0 + sl)
            for i in range(nf):
                dm, hm = d + (i + 0.5) * dd, h + (i + 0.5) * dh
                out.append((row - i, max(0, int(math.ceil(hm - 1e-6)) - 1), int(math.floor(dm + 1e-6)), 'slope'))
            d += nf * dd; h += nf * dh; row -= nf
            bd, bh = 1.0 / (1.0 - sl), -sl / (1.0 - sl)
            for i in range(nb):
                dm, hm = d + (i + 0.5) * bd, h + (i + 0.5) * bh
                out.append((row - i, max(0, int(math.ceil(hm - 1e-6)) - 1), int(math.floor(dm + 1e-6)), 'flat'))
            d += nb * bd; h += nb * bh; row -= nb
            continue
        elif kind == 'mirror':
            # done in build(), after the column is trimmed at the outline
            out.append((None, n, None, 'mirror'))
            continue
        elif kind == 'slope':
            s = seg[2]
            dd, dh = 1.0 / (1.0 + s), s / (1.0 + s)
            for i in range(n):
                dm, hm = d + (i + 0.5) * dd, h + (i + 0.5) * dh
                out.append((row - i, max(0, int(math.ceil(hm - 1e-6)) - 1), int(math.floor(dm + 1e-6)), 'slope'))
            d += n * dd
            h += n * dh
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
    for m in front:
        row = m[0]
        if trim and 0 <= row < img.shape[0] and img[row, m[4] if len(m) > 4 else 0, 3] < 128 and m[3] != 'wall':
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


def build(img, recipe):
    H, W = img.shape[:2]
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
    for pc in recipe['pieces']:
        xs = range(*pc['x'])
        tail = pc.get('tail', 0)
        for x in xs:
            smp, de, he = walk(pc, x)
            smp = [s if s[3] == 'mirror' else s + (x,) for s in smp]
            smp = trim_and_mirror(img, [s for s in smp if s[3] == 'mirror' or 0 <= s[0] < H], trim)
            smp = [s[:4] for s in smp]
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
    solid = np.full((W, HH, DD), pack((128, 128, 128)), np.int32)
    pix = {}       # (x,row) -> (hv, dv, kind)
    keys = {pack(k) for k in recipe.get('keys', [])}

    def pixcol(x, row):
        p = img[row, x]
        if p[3] < 128:
            return -1
        c = pack(p[:3])
        return -1 if c in keys else c

    for x, pc, smp, de, he, tail in [(x,) + e for x, es in cols.items() for e in es]:
        xs = range(*pc.get('fill', pc['x']))   # where the body's material is read
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
        # solid fill under the path
        cut = pc.get('cutout')
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
                if r is None:
                    continue
                # a painted chamfer is a staircase of 1-px steps: every step's
                # side is exposed, so every column gets the side art
                if side and (pc.get('paint') or x in (pc['x'][0], pc['x'][1] - 1)):
                    sa, sb = side
                    c = pixcol(sa + (dv - d_front) % (sb - sa), r)
                    if c >= 0:
                        colE[x, hh, di] = c
                if pc.get('back') == 'front' and dv == d_back:
                    c = pixcol(x, r)
                    if c >= 0:
                        colN[x, hh, di] = c
        paint = pc.get('paint')
        for (row, hv, dv, kind) in smp:
            di = dv + PAD
            # paint=(a,b): a chamfered corner's columns take the plain wall's
            # columns a..b-1 (cycled) instead of their own pixels, which are
            # the drawing's diagonal rim (vertical stripes in 3D)
            c = pixcol(paint[0] + (x - pc['x'][0]) % (paint[1] - paint[0]), row) if paint and kind == 'wall' else pixcol(x, row)
            if c >= 0:
                if kind in ('wall', 'slope'):
                    colS[x, hv, di] = c
                if kind in ('flat', 'slope'):
                    colT[x, hv, di] = c
            pix[(x, row)] = (hv, dv, kind)
        if last and tail:
            row, hv, dv, kind = last
            c = pixcol(x, row)
            dl = max(top_d) - tail
            for t in range(1, tail + 1):
                di = dl + t + PAD
                if c >= 0 and kind != 'wall':      # a wall's top row is not a roof: leave material
                    colT[x, hv, di] = c
    apply_relief(img, recipe.get('relief', []), pix, occ, colS, colT, solid)
    apply_prisms(img, recipe.get('prisms', []), occ, colS, colT, solid)
    return dict(occ=occ, colS=colS, colT=colT, colE=colE, colN=colN, solid=solid, W=W, HH=HH, DD=DD)


def apply_relief(img, rects, pix, occ, colS, colT, solid):
    off = {}
    for r in rects:
        xa, xb = r['x']
        ra, rb = r['rows']
        for x in range(xa, xb):
            for row in range(ra, rb):
                if (x, row) in pix:
                    off[(x, row)] = r['k']
    for (x, row), k in off.items():
        if k == 0:
            continue
        hv, dv, kind = pix[(x, row)]
        di = dv + PAD
        p = img[row, x]
        c = pack(p[:3]) if p[3] >= 128 else -1
        if kind in ('wall', 'slope'):
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
        for x in range(xa, xb):
            for d in range(d0, d1):
                if p.get('round') and ((x - cx) / rx) ** 2 + ((d - cd) / rd) ** 2 > 1.0:
                    continue
                di = d + PAD
                for h in range(h0, h1):
                    occ[x, h, di] = True
                    solid[x, h, di] = mat
                    colS[x, h, di] = -1
                    colT[x, h, di] = -1
                # front face: the first voxel of this column toward the viewer
                front = d == d0 or (p.get('round') and ((x - cx) / rx) ** 2 + ((d - 1 - cd) / rd) ** 2 > 1.0)
                if front:
                    for h in range(h0, h1):
                        colS[x, h, di] = art(x, B - h - d)
                colT[x, h1 - 1, di] = art(x, B - (h1 - 1) - d)


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
            c = pick(colE, x, h, d)
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
