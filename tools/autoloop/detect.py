#!/usr/bin/env python3
"""Autoloop detectors on the geometry dumps of tools/autoloop/em_geo_driver.lua (docs/AUTOLOOP.md).

  detect.py air   GEO.gz [GEO.gz ...] [--json OUT] [--min-gap 3] [--min-area 8] [--box x0,y0,x1,y1] [--tags]
  detect.py tags  GEO.gz                       list mesh origins with triangle counts and y range

D1/D2 "air": a surface with OPEN air under it and ground below that air - something you can see under: a floating
rock, a plate hanging over a drop, a wall that stops short of the ground. Method: the selected triangles are
voxelised (2 px across, 1 px tall) as thin shells, the air is labelled into connected pieces, and only air that
reaches the sky counts as open (the closed inside of a cliff does not). Every column is scanned for a solid voxel
with open air right under it and another solid voxel lower down; the run of air between is the gap. Flagged
columns are grouped into regions (8-connected, per map); each region is one candidate fault.
Things that are meant to have air under them (tree crowns, roofs, awnings, bridges, fence rails) are left out by
mesh origin (only ground/rock 'under' and civic meshes are read, see TERRAIN) and by cell flags (bridge, rail).
Run with python3 -I. Needs numpy and scipy.
"""
import gzip, json, math, re, sys, collections
import numpy as np
from scipy import ndimage

SX, SY, SZ = 2.0, 1.0, 2.0          # voxel size in px (x, y up, z)
CORE, OVER = 16, 4                  # tile core and overlap, in cells
STEP = 0.6                          # surface sample spacing in px (below the smallest voxel side)

# Mesh origins that are terrain. Tags look like 'Gen3Scene.lua:2571<Gen3Scene.lua:2589': the second line is the
# upload('<kind>', ...) call. Filled from a smoke dump: see TERRAIN_KINDS and tag_kind().
TERRAIN_KINDS = {'under', 'civic', 'water'}   # water: a lower surface (rock floating over a pond)


def load(path):
    head = {}
    tags = {}
    rows = []
    with gzip.open(path, 'rt') as f:
        for line in f:
            if line.startswith('T '):
                rows.append(line[2:])
            elif line.startswith('TAG '):
                p = line.split()
                tags[int(p[1])] = {'tag': p[2], 'fn': p[3], 'meshes': int(p[4]), 'verts': int(p[5])}
            elif line.startswith('MAP '):
                p = line.split()
                head = {'map': p[1], 'W': int(p[2]), 'H': int(p[3])}
    a = np.array(' '.join(rows).split(), dtype=np.float32).reshape(-1, 10) if rows else np.zeros((0, 10), np.float32)
    return head, tags, a


def load_cells(path):
    cells = {}
    try:
        for l in open(path):
            f = l.split()
            if len(f) < 5:
                continue
            kv = dict(x.split('=', 1) for x in f[5:] if '=' in x)
            kv['tile'] = f[3]
            kv['kind'] = f[4]
            cells[(int(f[1]), int(f[2]))] = kv
    except FileNotFoundError:
        pass
    return cells


def tag_kind(src_lines, tag):
    """'under'/'roof'/... for Gen3Scene field meshes (read from the upload call's source line), else a short name."""
    m = re.match(r'([^:]+):(\d+)<([^:]+):(\d+)', tag)
    if not m:
        return tag
    f1, l1, f2, l2 = m.group(1), int(m.group(2)), m.group(3), int(m.group(4))
    src = src_lines.get(f2)
    if src and 0 < l2 <= len(src):
        line = src[l2 - 1]
        k = re.search(r"upload\('(\w+)'", line)
        if k:
            return k.group(1)
        if 'Civic' in line or 'civic' in line:
            return 'civic'
    src1 = src_lines.get(f1)
    if src1 and 0 < l1 <= len(src1):
        line = src1[l1 - 1]
        if 'cache.wood' in line or 'cache.leaves' in line:
            return 'tree'
        if 'part.waters' in line:
            return 'water'
        if 'part.mesh' in line and 'Civic' in line:
            return 'civic'
    return '%s:%d' % (f1, l1)


def source_lines(libdir):
    import os
    out = {}
    if libdir and os.path.isdir(libdir):
        for n in os.listdir(libdir):
            if n.endswith('.lua'):
                out[n] = open(os.path.join(libdir, n), encoding='utf-8', errors='replace').read().split('\n')
    return out


def bary(n):
    """barycentric sample grid for a triangle cut into n steps per side"""
    u, v = [], []
    for i in range(n + 1):
        for j in range(n + 1 - i):
            u.append(i / n)
            v.append(j / n)
    return np.array(u, np.float32), np.array(v, np.float32)


_BARY = {}


def sample(tris):
    """points on every triangle, spaced at most STEP px; tris (N,9) -> (M,3)"""
    A, B, C = tris[:, 0:3], tris[:, 3:6], tris[:, 6:9]
    L = np.maximum(np.maximum(np.linalg.norm(B - A, axis=1), np.linalg.norm(C - A, axis=1)), np.linalg.norm(C - B, axis=1))
    n = np.clip(np.ceil(L / STEP), 1, 160).astype(int)
    out = []
    for k in np.unique(n):
        sel = n == k
        if k not in _BARY:
            _BARY[k] = bary(int(k))
        u, v = _BARY[k]
        a, b, c = A[sel][:, None, :], B[sel][:, None, :], C[sel][:, None, :]
        p = a + u[None, :, None] * (b - a) + v[None, :, None] * (c - a)
        out.append(p.reshape(-1, 3))
    return np.concatenate(out) if out else np.zeros((0, 3), np.float32)


def air_columns(tris, x0, z0, nx, nz, min_gap_vox):
    """flag columns of one tile. tris (N,9) already selected. Returns (gap, top) arrays (nx,nz): gap in voxels
    (0 = not flagged) and the y (px) of the solid voxel over the gap."""
    if len(tris) == 0:
        return np.zeros((nx, nz), np.int32), np.zeros((nx, nz), np.float32)
    ys = tris[:, [1, 4, 7]]
    y0 = math.floor(float(ys.min())) - 2
    ny = int(math.ceil((float(ys.max()) - y0) / SY)) + 4
    S = np.zeros((nx, ny, nz), bool)
    for chunk in range(0, len(tris), 4000):
        p = sample(tris[chunk:chunk + 4000])
        ix = np.floor((p[:, 0] - x0) / SX).astype(np.int64)
        iy = np.floor((p[:, 1] - y0) / SY).astype(np.int64)
        iz = np.floor((p[:, 2] - z0) / SZ).astype(np.int64)
        ok = (ix >= 0) & (ix < nx) & (iz >= 0) & (iz < nz) & (iy >= 0) & (iy < ny)
        S[ix[ok], iy[ok], iz[ok]] = True
    lab, n = ndimage.label(~S, structure=ndimage.generate_binary_structure(3, 1))
    sky = np.unique(lab[:, ny - 1, :])
    sky = sky[sky > 0]
    O = np.isin(lab, sky)
    # highest solid voxel at or below each y, per column
    yi = np.arange(ny)[None, :, None]
    last = np.maximum.accumulate(np.where(S, yi, -1), axis=1)
    # bottom of a solid run with open air right under it
    bottom = np.zeros_like(S)
    bottom[:, 1:, :] = S[:, 1:, :] & ~S[:, :-1, :] & O[:, :-1, :]
    below = np.full_like(last, -1)
    below[:, 1:, :] = last[:, :-1, :]
    gap = np.where(bottom & (below >= 0), yi - below - 1, 0)
    gap = np.where(gap >= min_gap_vox, gap, 0)
    g = gap.max(axis=1)
    top = np.where(g > 0, (np.argmax(gap, axis=1) * SY + y0), 0).astype(np.float32)
    return g.astype(np.int32), top


def detect_air(path, min_gap=3.0, min_area=8.0, box=None, libdir=None, verbose=False, margin=6):
    head, tags, a = load(path)
    cells = load_cells(path.replace('.geo.gz', '.cells'))
    src = source_lines(libdir)
    kinds = {t: tag_kind(src, v['tag']) for t, v in tags.items()}
    keep = np.array([kinds.get(int(t)) in TERRAIN_KINDS for t in a[:, 0]], bool) if len(a) else np.zeros(0, bool)
    tris = a[keep][:, 1:10]
    if len(tris) == 0:
        return {'map': head.get('map'), 'tris': 0, 'regions': [], 'kinds': collections.Counter(kinds.values())}
    xs, zs = tris[:, [0, 3, 6]], tris[:, [2, 5, 8]]
    W, H = head['W'], head['H']
    # the boundary fill outside the map is seen from the map (Route 112's floating roof plate stands 3-6 cells west
    # of the edge), so look `margin` cells out; the dump holds 8 (em_geo_driver EM_MARGIN)
    cx0, cz0 = -margin, -margin
    cx1, cz1 = W + margin, H + margin
    if box:
        cx0, cz0, cx1, cz1 = box
    vx, vz = int(16 / SX), int(16 / SZ)
    GW, GH = (cx1 - cx0) * vx, (cz1 - cz0) * vz
    gapall = np.zeros((GW, GH), np.int32)
    topall = np.zeros((GW, GH), np.float32)
    tmin_x, tmax_x = xs.min(axis=1), xs.max(axis=1)
    tmin_z, tmax_z = zs.min(axis=1), zs.max(axis=1)
    min_gap_vox = int(math.ceil(min_gap / SY))
    for tz in range(cz0, cz1, CORE):
        for tx in range(cx0, cx1, CORE):
            ex0, ez0 = (tx - OVER) * 16.0, (tz - OVER) * 16.0
            ex1, ez1 = (tx + CORE + OVER) * 16.0, (tz + CORE + OVER) * 16.0
            sel = (tmax_x >= ex0) & (tmin_x <= ex1) & (tmax_z >= ez0) & (tmin_z <= ez1)
            nx, nz = int((ex1 - ex0) / SX), int((ez1 - ez0) / SZ)
            g, top = air_columns(tris[sel], ex0, ez0, nx, nz, min_gap_vox)
            # copy the core into the map grid
            ox, oz = OVER * vx, OVER * vz
            cw = min(CORE, cx1 - tx) * vx
            ch = min(CORE, cz1 - tz) * vz
            gx, gz = (tx - cx0) * vx, (tz - cz0) * vz
            gapall[gx:gx + cw, gz:gz + ch] = g[ox:ox + cw, oz:oz + ch]
            topall[gx:gx + cw, gz:gz + ch] = top[ox:ox + cw, oz:oz + ch]
    # A surface at or below its cell's floor is the ground itself (or lower): the air under it is underground and
    # cannot be seen from any camera above the floor (skirts reach 8 px below the ground to hide seams; holes such as
    # water cells connect that space to the sky in the voxel grid). Calibration 2026-10-20: 28 of 85 Route 112 regions.
    base = np.full((GW, GH), -1e9, np.float32)
    for (cx, cy), c in cells.items():
        if cx0 <= cx < cx1 and cz0 <= cy < cz1:
            try:
                b = float(c.get('base', 'nan'))
            except ValueError:
                continue
            if b == b:
                base[(cx - cx0) * vx:(cx - cx0 + 1) * vx, (cy - cz0) * vz:(cy - cz0 + 1) * vz] = b
    gapall[(gapall > 0) & (topall <= base + 1.0)] = 0
    # cells that are meant to have air under parts of them
    for (cx, cy), c in cells.items():
        if c.get('bridge') == '1' or c.get('rail') == '1':
            if cx0 <= cx < cx1 and cz0 <= cy < cz1:
                gapall[(cx - cx0) * vx:(cx - cx0 + 1) * vx, (cy - cz0) * vz:(cy - cz0 + 1) * vz] = 0
    lab, n = ndimage.label(gapall > 0, structure=np.ones((3, 3), bool))
    regions = []
    for r, sl in enumerate(ndimage.find_objects(lab), 1):
        m = lab[sl] == r
        cnt = int(m.sum())
        area = cnt * SX * SZ
        if area < min_area:
            continue
        gv = gapall[sl][m] * SY
        tv = topall[sl][m]
        ix0, iz0 = sl[0].start, sl[1].start
        ix1, iz1 = sl[0].stop, sl[1].stop
        c_x0, c_x1 = cx0 + ix0 // vx, cx0 + (ix1 - 1) // vx
        c_z0, c_z1 = cz0 + iz0 // vz, cz0 + (iz1 - 1) // vz
        # the cell holding most flagged columns
        ii, jj = np.nonzero(m)
        cc = collections.Counter(zip((cx0 + (ii + ix0) // vx).tolist(), (cz0 + (jj + iz0) // vz).tolist()))
        (mx, mz), _ = cc.most_common(1)[0]
        mc = cells.get((mx, mz), {})
        regions.append({
            'cell': [int(mx), int(mz)], 'box': [int(c_x0), int(c_z0), int(c_x1), int(c_z1)],
            'area_px': round(area), 'gap_max': round(float(gv.max()), 1), 'gap_med': round(float(np.median(gv)), 1),
            'y_top': round(float(np.median(tv)), 1), 'cells': len(cc),
            'inside_map': bool(0 <= mx < W and 0 <= mz < H),
            'cell_info': {k: mc.get(k) for k in ('tile', 'kind', 'base', 'coll', 'ledge', 'stairs', 'mass') if k in mc},
            'score': round(area * float(gv.max()))})
    regions.sort(key=lambda r: -r['score'])
    return {'map': head['map'], 'W': W, 'H': H, 'tris': int(len(tris)), 'regions': regions,
            'kinds': dict(collections.Counter(kinds[int(t)] for t in a[:, 0]))}


def step_faces(geo_path, libdir=None):
    """vertical ground faces on cell edges: {('x'|'z', boundary, cell along): (ymin, ymax)} from 'under' meshes"""
    head, tags, a = load(geo_path)
    src = source_lines(libdir)
    kinds = {t: tag_kind(src, v['tag']) for t, v in tags.items()}
    out = {}
    if not len(a):
        return out
    keep = np.array([kinds.get(int(t)) == 'under' for t in a[:, 0]], bool)
    t = a[keep][:, 1:10].reshape(-1, 3, 3)
    n = np.cross(t[:, 1] - t[:, 0], t[:, 2] - t[:, 0])
    L = np.linalg.norm(n, axis=1) + 1e-9
    n = n / L[:, None]
    vert = np.abs(n[:, 1]) < 0.05
    for tri, nn in zip(t[vert], n[vert]):
        h = float(tri[:, 1].max() - tri[:, 1].min())
        if h < 0.5:
            continue
        if abs(nn[0]) > 0.9:
            xb = float(tri[:, 0].mean()) / 16
            if abs(xb - round(xb)) < 0.05:
                k = ('x', int(round(xb)), int(np.floor(tri[:, 2].mean() / 16)))
            else:
                continue
        elif abs(nn[2]) > 0.9:
            zb = float(tri[:, 2].mean()) / 16
            if abs(zb - round(zb)) < 0.05:
                k = ('z', int(round(zb)), int(np.floor(tri[:, 0].mean() / 16)))
            else:
                continue
        else:
            continue
        lo, hi = out.get(k, (1e9, -1e9))
        out[k] = (min(lo, float(tri[:, 1].min())), max(hi, float(tri[:, 1].max())))
    return out


def detect_steps(cells_path, max_step=8.0, min_run=2, faces=None):
    """D3 mini-stairs: walkable ground (coll=0, not stairs, ledge, bridge or water) whose floor steps by a small
    height (0 < step < max_step px) between neighbouring cells, again and again in one direction. Each such edge is
    a small vertical face; two or more in a row read as a little staircase where the drawing has none (F002 Route
    115 22,71-73: 0 -> 2 -> 5 -> 8 px over three rows). Regions = connected cells touching such edges; reported when
    the longest same-direction run of steps is >= min_run."""
    cl = load_cells(cells_path)
    W = max((k[0] for k in cl), default=0)
    H = max((k[1] for k in cl), default=0)

    def walk(c):
        return (c and c.get('coll') == '0' and c.get('kind') != 'water' and c.get('stairs') != '1'
                and c.get('ledge') != '1' and c.get('bridge') != '1')

    def base(c):
        try:
            return float(c.get('base'))
        except (TypeError, ValueError):
            return None
    edges = []
    for (x, y), c in cl.items():
        if not walk(c):
            continue
        b0 = base(c)
        for dx, dy in ((1, 0), (0, 1)):
            n = cl.get((x + dx, y + dy))
            if not walk(n):
                continue
            b1 = base(n)
            if b0 is None or b1 is None:
                continue
            d = b1 - b0
            if 0.5 < abs(d) < max_step:
                # drawn as a step only if a vertical face stands on that cell edge (a ramp drawn as a slope is fine:
                # Oldale's 0-2-5-8 ramp at 8,22-25 is sloped, Route 115's at 20-22,71-75 is 61 small faces)
                if faces is not None:
                    k = ('x', x + 1, y) if dx else ('z', y + 1, x)
                    if k not in faces:
                        continue
                edges.append(((x, y), (x + dx, y + dy), d, dx, dy))
    # run length: consecutive same-sign steps along one axis
    step = {}
    for a, b, d, dx, dy in edges:
        step[(a, dx, dy)] = d
    def run_from(a, dx, dy, sign):
        n, p = 0, a
        while (p, dx, dy) in step and (step[(p, dx, dy)] > 0) == sign:
            n += 1
            p = (p[0] + dx, p[1] + dy)
        return n
    # group cells touching step edges
    parent = {}
    def find(u):
        while parent.setdefault(u, u) != u:
            parent[u] = parent[parent[u]]
            u = parent[u]
        return u
    for a, b, d, dx, dy in edges:
        parent[find(a)] = find(b)
    groups = collections.defaultdict(list)
    for a, b, d, dx, dy in edges:
        groups[find(a)].append((a, b, d, dx, dy))
    regions = []
    for g in groups.values():
        best = 0
        for a, b, d, dx, dy in g:
            best = max(best, run_from(a, dx, dy, d > 0))
        if best < min_run:
            continue
        xs = [p[0] for e in g for p in e[:2]]
        ys = [p[1] for e in g for p in e[:2]]
        inside = [e for e in g if 0 <= e[0][0] <= W - 8 and 0 <= e[0][1] <= H - 8]
        regions.append({'box': [min(xs), min(ys), max(xs), max(ys)], 'steps': len(g), 'run': best,
                        'heights': sorted(set(round(base(cl[p]), 1) for e in g for p in e[:2])),
                        'cell': list(g[0][0]), 'score': len(g) * best})
    regions.sort(key=lambda r: -r['score'])
    return regions


def main(argv):
    import argparse, os
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=['air', 'tags', 'steps'])
    ap.add_argument('geo', nargs='+')
    ap.add_argument('--json')
    ap.add_argument('--min-gap', type=float, default=3.0)
    ap.add_argument('--min-area', type=float, default=8.0)
    ap.add_argument('--box')
    ap.add_argument('--lib', default=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), '.autoloop', 'rc', 'lib'))
    ap.add_argument('--top', type=int, default=15)
    o = ap.parse_args(argv)
    if o.cmd == 'tags':
        src = source_lines(o.lib)
        for p in o.geo:
            head, tags, a = load(p)
            print(head)
            for t, v in sorted(tags.items()):
                sel = a[:, 0] == t
                ys = a[sel][:, [2, 5, 8]]
                xs = a[sel][:, [1, 4, 7]]
                zs = a[sel][:, [3, 6, 9]]
                rng = lambda q: '%.0f..%.0f' % (q.min(), q.max()) if q.size else '-'
                print('%3d %-8s %-48s %-10s tris %7d  x %s y %s z %s' % (t, tag_kind(src, v['tag']), v['tag'], v['fn'], int(sel.sum()), rng(xs), rng(ys), rng(zs)))
        return 0
    if o.cmd == 'steps':
        res = []
        for p in o.geo:
            cp = p.replace('.geo.gz', '.cells')
            regs = detect_steps(cp, faces=step_faces(p, o.lib))
            res.append({'map': os.path.basename(cp).replace('.cells', ''), 'regions': regs})
            print('%-32s step regions %3d' % (res[-1]['map'], len(regs)))
            for g in regs[:o.top]:
                print('   box %-18s steps %3d run %d heights %s' % (g['box'], g['steps'], g['run'], g['heights'][:10]))
        if o.json:
            json.dump(res, open(o.json, 'w'), indent=1)
        return 0
    box = tuple(int(v) for v in o.box.split(',')) if o.box else None
    res = []
    for p in o.geo:
        r = detect_air(p, o.min_gap, o.min_area, box, o.lib)
        res.append(r)
        print('%-32s tris %7d  regions %3d' % (r['map'], r['tris'], len(r['regions'])))
        for g in r['regions'][:o.top]:
            print('   cell %3d,%3d box %s area %5d px2 gap max %5.1f med %5.1f y %6.1f %s %s' % (
                g['cell'][0], g['cell'][1], g['box'], g['area_px'], g['gap_max'], g['gap_med'], g['y_top'],
                '' if g['inside_map'] else '(outside map)', g['cell_info']))
    if o.json:
        json.dump(res, open(o.json, 'w'), indent=1)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
