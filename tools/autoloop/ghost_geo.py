#!/usr/bin/env python3
"""Ghost, geometry senses on a map's geo.gz + cells (tools/autoloop/em_geo_driver.lua output). Needs numpy and PIL: run WITHOUT -I.

  ghost_geo.py <ghost dir> [--map EM_ROUTE112]   reads <dir>/geo/<map>.{geo.gz,cells} and <dir>/senses.csv
                                                 writes <dir>/geo_senses.json (map-wide findings) and adds the columns
                                                 orphan / plates / camblock / camkinds / camin to <dir>/senses.csv (one value per frame)

Senses:
  (a) orphan  a foliage plate (Gen3Canopy mesh, 'canopy' upload; the cell is the TILE it is drawn from, the mesh stands 31 px south) hanging >= 8 px over the ground of its cell with no
              tree-kind cell within one cell of it: a crown with no trunk and nothing under it (F035 class, ghost card G1).
              Per frame (levels 6/7): orphan = plate cells ahead of the eye (within +-50 deg of the yaw, <= 14 cells); plates =
              how many of them show against the sky in the frame (plate_boxes projects the plate triangles with the player camera,
              green_boxes keeps the boxes that are foliage green with sky round them, so a plate hidden behind rock or trees does not count).
  (b) camera  the eye of the player camera (level 6) and the low camera (level 7), computed as in Gen3Scene.draw
              (cx,cz = cell*16+8; L6 eye = ground + EYE_H; L7 eye = 75 px behind at ground+48): camblock = triangles of terrain /
              buildings / canopy crossed by the segment player-head -> eye (a wall or a glass pane between you and the
              camera), camin = how many 'model' (building) triangles lie above the eye in its column (odd = eye inside a
              closed building volume). The orbit camera (level 4) is not modelled.
  (c) wallrun  runs of >= 3 cliff cells of one tile in a line where that tile is a foliage drawing (Gen3Canopy lifts it as a
              crown somewhere on the map): the same bush art stacked up a rock face (ghost card G2). Map-wide list only.
"""
import sys, os, re, csv, json, math, collections
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import detect

KIND_OF = {}            # tag id -> kind, filled by kinds()
REACH = {6: 14, 7: 14}  # cells ahead in which a plate counts as "in the frame" (levels 6/7 only: the orbit camera is not modelled)
HALF_FOV = math.radians(50)   # horizontal half angle: fov 62 deg vertical at 16:9 is ~ 98 deg across
EYE_H = 15.0            # level-6 eye above the ground (SpriteAnchor.eyeHeight of a 32 px Gen 3 frame is 14.5)
GAP_MIN = 8.0
SETBACK = 26 * math.tan(math.radians(50))   # Gen3Canopy pushes a crown south by HEIGHT*tan(TILT) px: its mesh stands ~2 cells south of its tile


def kinds(tags, libdir):
    src = detect.source_lines(libdir)
    return {t: detect.tag_kind(src, v['tag']) for t, v in tags.items()}


def tri_cells(a):
    cx = np.floor((a[:, 1] + a[:, 4] + a[:, 7]) / 48).astype(int)
    cz = np.floor((a[:, 3] + a[:, 6] + a[:, 9]) / 48).astype(int)
    return cx, cz


def orphan_canopy(a, kd, cells):
    """[{'cell','y','ground','gap','tile','kind'}] for foliage plate cells with no trunk, nothing under them"""
    t = a[:, 0].astype(int)
    kk = np.array([kd.get(int(x)) for x in t])
    cx, cz = tri_cells(a)
    ylo = np.minimum(np.minimum(a[:, 2], a[:, 5]), a[:, 8])
    yhi = np.maximum(np.maximum(a[:, 2], a[:, 5]), a[:, 8])
    gnd = {}
    sel = kk == 'under'
    for x, z, y in zip(cx[sel].tolist(), cz[sel].tolist(), yhi[sel].tolist()):
        if y > gnd.get((x, z), -1e9):
            gnd[(x, z)] = y
    can = {}
    sel = kk == 'canopy'
    czs = np.floor(((a[:, 3] + a[:, 6] + a[:, 9]) / 3 - SETBACK) / 16).astype(int)    # the tile the crown is drawn from
    for x, z, y in zip(cx[sel].tolist(), czs[sel].tolist(), ylo[sel].tolist()):
        can[(x, z)] = min(y, can.get((x, z), 1e9))
    out = []
    for (x, z), y in sorted(can.items()):
        near_tree = any(cells.get((x + dx, z + dz), {}).get('kind') == 'tree' for dx in (-1, 0, 1) for dz in (-1, 0, 1))
        g = gnd.get((x, z))
        if g is None or near_tree or y - g < GAP_MIN:
            continue
        c = cells.get((x, z), {})
        out.append({'cell': [x, z], 'y': round(y, 1), 'ground': round(g, 1), 'gap': round(y - g, 1),
                    'tile': c.get('tile'), 'kind': c.get('kind'), 'blocked': c.get('coll') not in (None, 'nil', '0')})
    return out


def wall_runs(cells, foliage, min_run=3):
    """runs of >= min_run adjacent cliff cells of one tile along x or y, where the tile is a foliage drawing (a tile that
    Gen3Canopy also lifts as a crown somewhere on the map): the same bush art stacked up a rock face"""
    out = []
    for axis in (0, 1):
        for (x, y), c in sorted(cells.items(), key=lambda kv: (kv[0][1 - axis], kv[0][axis])):
            if c.get('kind') != 'cliff' or c.get('tile') not in foliage:
                continue
            px, py = (x - 1, y) if axis == 0 else (x, y - 1)
            p = cells.get((px, py))
            if p and p.get('kind') == 'cliff' and p.get('tile') == c.get('tile') and p.get('base') == c.get('base'):
                continue                      # not the start of a run
            n = 0
            while True:
                q = cells.get((x + n, y) if axis == 0 else (x, y + n))
                if q and q.get('kind') == 'cliff' and q.get('tile') == c.get('tile') and q.get('base') == c.get('base'):
                    n += 1
                else:
                    break
            if n >= min_run:
                out.append({'start': [x, y], 'axis': 'x' if axis == 0 else 'y', 'len': n, 'tile': c.get('tile'), 'base': c.get('base')})
    return out


def seg_hits(tris, p0, p1):
    """count of triangles (N,9) crossed by the open segment p0->p1 (Moller-Trumbore, both faces)"""
    p0 = np.array(p0, np.float64); d = np.array(p1, np.float64) - p0
    lo = np.minimum(p0, p0 + d) - 1.0; hi = np.maximum(p0, p0 + d) + 1.0
    A, B, C = tris[:, 0:3].astype(np.float64), tris[:, 3:6].astype(np.float64), tris[:, 6:9].astype(np.float64)
    tmin = np.minimum(np.minimum(A, B), C); tmax = np.maximum(np.maximum(A, B), C)
    m = np.all((tmax >= lo) & (tmin <= hi), axis=1)
    if not m.any():
        return 0
    A, B, C = A[m], B[m], C[m]
    e1, e2 = B - A, C - A
    h = np.cross(d, e2)
    det = (e1 * h).sum(1)
    ok = np.abs(det) > 1e-9
    inv = np.where(ok, 1.0 / np.where(ok, det, 1), 0)
    s = p0 - A
    u = (s * h).sum(1) * inv
    q = np.cross(s, e1)
    v = (q @ d) * inv
    t = (e2 * q).sum(1) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0.02) & (t < 0.98)
    return int(hit.sum())


def up_hits(tris, x, y, z):
    """triangles above the point (x,y,z) crossed by the ray going straight up (parity: odd = inside a closed volume)"""
    A, B, C = tris[:, 0:3], tris[:, 3:6], tris[:, 6:9]
    m = (np.minimum(np.minimum(A[:, 0], B[:, 0]), C[:, 0]) <= x) & (np.maximum(np.maximum(A[:, 0], B[:, 0]), C[:, 0]) >= x) \
        & (np.minimum(np.minimum(A[:, 2], B[:, 2]), C[:, 2]) <= z) & (np.maximum(np.maximum(A[:, 2], B[:, 2]), C[:, 2]) >= z)
    if not m.any():
        return 0
    A, B, C = A[m].astype(np.float64), B[m].astype(np.float64), C[m].astype(np.float64)
    d = np.array([0, 1.0, 0]); p = np.array([x, y, z], np.float64)
    e1, e2 = B - A, C - A
    h = np.cross(d, e2); det = (e1 * h).sum(1)
    ok = np.abs(det) > 1e-9
    inv = np.where(ok, 1.0 / np.where(ok, det, 1), 0)
    s = p - A; u = (s * h).sum(1) * inv
    q = np.cross(s, e1); v = (q @ d) * inv; t = (e2 * q).sum(1) * inv
    return int((ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0.02)).sum())


def eyes(x, y, yaw, level, ground):
    cx, cz = x * 16 + 8, y * 16 + 8
    dx, dz = math.sin(yaw), -math.cos(yaw)
    if level == 6:
        return (cx, ground + EYE_H, cz), (cx, ground + EYE_H, cz)
    if level == 7:
        return (cx, ground + EYE_H, cz), (cx - dx * 75, ground + 48, cz - dz * 75)
    return None, None


def _camera(x, y, yaw, level, ground, pitch=0.16):
    """eye and orthonormal (right, up, forward) of the level 6/7 player camera (Gen3Scene.draw: focus 24 / 70 px ahead, pitch .16)"""
    p, e = eyes(x, y, yaw, level, ground)
    if p is None:
        return None
    fx, fz = math.sin(yaw), -math.cos(yaw)
    fd = 24 if level == 6 else 70
    cx, cz = x * 16 + 8, y * 16 + 8
    foc = np.array([cx + fx * fd, e[1] - fd * math.tan(pitch), cz + fz * fd])
    eye = np.array(e, float)
    f = foc - eye; f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1.0, 0]); r /= np.linalg.norm(r)
    return eye, r, np.cross(r, f), f


def plate_boxes(a, kk, x, y, yaw, level, ground, only=None, pad=10, min_area=120, w=1280, h=720):
    """screen boxes (x0,y0,x1,y1) of the foliage plates (canopy mesh) in the level 6/7 frame of the player at cell (x,y):
    every canopy triangle is projected (vertical fov 62 deg, 16:9) and overlapping triangle boxes are merged. No occlusion test:
    look at the frame before trusting a box. only = set of source cells (the orphan_canopy cells): other plates are left out."""
    cam = _camera(x, y, yaw, level, ground)
    if cam is None:
        return []
    eye, r, u, f = cam
    ca = a[kk == 'canopy']
    if only is not None:
        sx_ = np.floor((ca[:, 1] + ca[:, 4] + ca[:, 7]) / 48).astype(int)
        sz_ = np.floor(((ca[:, 3] + ca[:, 6] + ca[:, 9]) / 3 - SETBACK) / 16).astype(int)
        ca = ca[[(i, j) in only for i, j in zip(sx_.tolist(), sz_.tolist())]]
    t = ca[:, 1:10].astype(np.float64).reshape(-1, 3, 3)
    d = t - eye
    z = d @ f
    ok = (z > 4).all(axis=1)
    d, z = d[ok], z[ok]
    k = 1 / math.tan(math.radians(31))
    sx = (d @ r) / z * k / (w / h) * (w / 2) + w / 2
    sy = h / 2 - (d @ u) / z * k * (h / 2)
    bx = np.stack([sx.min(1), sy.min(1), sx.max(1), sy.max(1)], 1)
    bx = bx[(bx[:, 2] > 0) & (bx[:, 0] < w) & (bx[:, 3] > 0) & (bx[:, 1] < h)]
    boxes = [list(b) for b in bx]
    merged = True
    while merged:
        merged = False
        out = []
        for b in boxes:
            for o in out:
                if b[0] <= o[2] + 3 and b[2] >= o[0] - 3 and b[1] <= o[3] + 3 and b[3] >= o[1] - 3:
                    o[0], o[1], o[2], o[3] = min(o[0], b[0]), min(o[1], b[1]), max(o[2], b[2]), max(o[3], b[3])
                    merged = True
                    break
            else:
                out.append(b)
        boxes = out
    res = []
    for b in boxes:
        if (b[2] - b[0]) * (b[3] - b[1]) >= min_area:
            res.append((int(max(0, b[0] - pad)), int(max(0, b[1] - pad)), int(min(w, b[2] + pad)), int(min(h, b[3] + pad))))
    return res


def green_boxes(path, boxes, share=0.25, pad=10, sky_share=0.3):
    """keep the boxes that show a foliage plate in the frame: mostly foliage green inside (without the padding) and sky blue
    round it. A plate hidden behind rock, ground or the trees of a grove (instanced trees are not in the dump, so the
    projection cannot see them occlude) shows no sky round it and is left out; plates in front of rock are missed on purpose.
    Needs PIL: run without -I."""
    from PIL import Image
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.int16)
    h, w, _ = im.shape
    keep = []
    for (x0, y0, x1, y1) in boxes:
        c = im[y0 + pad:max(y0 + pad + 1, y1 - pad), x0 + pad:max(x0 + pad + 1, x1 - pad)]   # the box without its padding
        if c.size == 0:
            continue
        r, g, b = c[..., 0], c[..., 1], c[..., 2]
        if ((g > r * 1.15) & (g > b * 1.15)).mean() < share:
            continue
        o = im[max(0, y0 - pad):min(h, y1 + pad), max(0, x0 - pad):min(w, x1 + pad)]
        m = np.ones(o.shape[:2], bool)
        m[min(o.shape[0], y0 + pad - max(0, y0 - pad)):min(o.shape[0], y1 - pad - max(0, y0 - pad)),
          min(o.shape[1], x0 + pad - max(0, x0 - pad)):min(o.shape[1], x1 - pad - max(0, x0 - pad))] = False   # the ring only
        ring = o[m]
        if len(ring) and ((ring[:, 2] > ring[:, 0] + 40) & (ring[:, 2] > ring[:, 1])).mean() >= sky_share:
            keep.append((x0, y0, x1, y1))
    return keep


def load_geo(G, mp, libdir=None):
    """(a, kk, cells) of a ghost run's geometry dump: a = triangle rows, kk = mesh kind per row"""
    libdir = libdir or os.environ.get('GHOST_LIB') or os.path.join(os.path.expanduser('~'), 'Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK/lib')
    P = os.path.join(G, 'geo', mp)
    head, tags, a = detect.load(P + '.geo.gz')
    kd = kinds(tags, libdir)
    kk = np.array([kd.get(int(x)) for x in a[:, 0].astype(int)])
    return a, kk, detect.load_cells(P + '.cells')


def main():
    G = sys.argv[1]
    mp = sys.argv[sys.argv.index('--map') + 1] if '--map' in sys.argv else 'EM_ROUTE112'
    libdir = os.environ.get('GHOST_LIB') or os.path.join(os.path.expanduser('~'), 'Library/Application Support/pokemon-love2d/mods/BATTLE_ART_VOXEL_FORK/lib')
    P = os.path.join(G, 'geo', mp)
    head, tags, a = detect.load(P + '.geo.gz')
    cells = detect.load_cells(P + '.cells')
    kd = kinds(tags, libdir)
    t = a[:, 0].astype(int)
    kk = np.array([kd.get(int(x)) for x in t])
    orphans = orphan_canopy(a, kd, cells)
    sel = kk == 'canopy'
    ccx, _ = tri_cells(a[sel])
    ccz = np.floor(((a[sel][:, 3] + a[sel][:, 6] + a[sel][:, 9]) / 3 - SETBACK) / 16).astype(int)
    foliage = {cells[(x, z)]['tile'] for x, z in zip(ccx.tolist(), ccz.tolist()) if (x, z) in cells}
    runs = wall_runs(cells, foliage)
    solid = {k: a[kk == k][:, 1:10] for k in ('under', 'over', 'model', 'roof', 'canopy')}
    model = a[kk == 'model'][:, 1:10]
    json.dump({'map': mp, 'orphan_canopy': orphans, 'wall_runs': runs}, open(os.path.join(G, 'geo_senses.json'), 'w'), indent=1)
    print('orphan canopy cells', len(orphans), '(blocked cells %d)' % sum(1 for o in orphans if o['blocked']), 'foliage wall runs', len(runs))
    gnd_of = lambda x, y: float(cells.get((x, y), {}).get('base') or 0)
    rows = list(csv.DictReader(open(os.path.join(G, 'senses.csv'))))
    oc = [tuple(o['cell']) for o in orphans]
    only = set(oc)
    for r in rows:
        x, y, lv = int(r['x']), int(r['y']), int(r['level'])
        yaw = 0.8 if r['yaw'] == 'y08' else 3.9
        p, e = eyes(x, y, yaw, lv, gnd_of(x, y))
        if p is None:
            r['orphan'] = ''; r['plates'] = ''
        else:
            r['plates'] = len(green_boxes(os.path.join(G, r['frame']), plate_boxes(a, kk, x, y, yaw, lv, gnd_of(x, y), only=only)))
            fx, fz = math.sin(yaw), -math.cos(yaw)
            ex, ez = e[0], e[2]
            n = 0
            for (cx, cz) in oc:
                vx, vz = cx * 16 + 8 - ex, cz * 16 + 8 - ez
                d = math.hypot(vx, vz) / 16
                if d < .5 or d > REACH[lv]:
                    continue
                if math.acos(max(-1, min(1, (vx * fx + vz * fz) / (d * 16))) ) <= HALF_FOV:
                    n += 1
            r['orphan'] = n
        if p is None:
            r['camblock'] = ''; r['camin'] = ''; r['camkinds'] = ''
            continue
        hits = {k: seg_hits(v, p, e) for k, v in solid.items()} if p != e else {}
        r['camblock'] = sum(hits.values())
        r['camkinds'] = ' '.join('%s:%d' % kv for kv in hits.items() if kv[1])
        r['camin'] = up_hits(model, e[0], e[1], e[2])
    fields = list(rows[0].keys())
    with open(os.path.join(G, 'senses.csv'), 'w', newline='') as fh:
        wr = csv.DictWriter(fh, fieldnames=fields)
        wr.writeheader(); wr.writerows(rows)
    print('senses.csv now has', fields)


if __name__ == '__main__':
    main()
