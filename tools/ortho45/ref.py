#!/usr/bin/env python3
"""Original 2D map art for an ortho45 window, from the gen1recomp cache.

  python3 ref.py <MAP_ID> <x> <y> <out.png> [--scale 2] [--size 1280x720]

Renders the plain art (layers u, m, o composited in that order; no labels, no
grid) for the screen window centred on map cell (x, y): world pixel
(x*16+8, y*16+8) at S screen px per map px, north up.  Screen pixel (sx, sy)
shows map pixel (cx + (sx - W/2)/S, cy + (sy - H/2)/S), floored.  Pixels
outside the map (or on a metatile with no art) are alpha 0.

Map id -> cache lookup (EM_LITTLEROOT_TOWN style):
  1. <cache>/native/layout_files.lua  "[n] = \"EM_...\"" lists layout n's id.
  2. <cache>/map_tree/census.json     maps[] gives every slot (e.g. "0_9").
  3. <cache>/map_tree/maps/<slot>/header.json  layoutId == n -> that slot;
     width/height and grid.bin (u16 cells) come from the same slot.
  4. pair: <world.json> entry with the same "id" (key "pair", e.g.
     general__petalburg; key "slot" is checked against step 2).  Overrides:
     --cache, --slot, --pair, --world.
Native pair files (mids.idx, atlas_*.rgba) are zlib-compressed in the cache
and are inflated here; raw files are read as-is.
"""
import os, sys, re, json, zlib, struct, glob, argparse
import numpy as np
from PIL import Image

CACHE = os.path.expanduser('~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba')
WORLD = os.path.expanduser('~/Documents/gen1recomp-modwork/world.json')
_MAPS = {}

def unz(b):
    if len(b) > 2 and b[0] & 0x0F == 8 and ((b[0] << 8) | b[1]) % 31 == 0:
        try:
            return zlib.decompress(b)
        except zlib.error:
            pass
    return b

def read_idx(path):
    b = unz(open(path, 'rb').read())
    assert b[:4] == b'SVMI', "bad mids.idx magic"
    count, cols, rows = struct.unpack_from('<HHH', b, 6)
    ids = struct.unpack_from('<%dH' % count, b, 12)
    return count, cols, rows, ids

def read_rgba(path, w, h):
    b = unz(open(path, 'rb').read())
    assert len(b) == w * h * 4, "atlas size mismatch %d != %d" % (len(b), w * h * 4)
    return np.frombuffer(b, np.uint8).reshape(h, w, 4)

def composite(layers):
    # same rule as mapsheet.px: u is the base, m and o are alpha-blended on top;
    # a pixel is opaque if any layer has alpha there
    base = layers[0]
    rgb = base[..., :3].astype(np.float64)
    alpha = base[..., 3] > 0
    for L in layers[1:]:
        if L is None:
            continue
        a = L[..., 3].astype(np.float64)
        sel = a > 0
        k = (a / 255.0)[..., None]
        rgb = np.where(sel[..., None], L[..., :3] * k + rgb * (1 - k), rgb)
        alpha |= sel
    out = np.zeros(base.shape, np.uint8)
    out[..., :3] = np.clip(np.floor(rgb), 0, 255).astype(np.uint8)
    out[..., 3] = np.where(alpha, 255, 0)
    return out

def layout_names(cache):
    src = open(os.path.join(cache, 'native', 'layout_files.lua')).read()
    return {int(n): name for n, name in re.findall(r'\[(\d+)\]\s*=\s*"(EM_[A-Z0-9_]+)"', src)}

def find_slot(cache, map_id):
    want = {n for n, name in layout_names(cache).items() if name == map_id}
    if not want:
        raise SystemExit('no layout named %s in %s' % (map_id, cache))
    census = json.load(open(os.path.join(cache, 'map_tree', 'census.json')))
    for m in census['maps']:
        hp = os.path.join(cache, 'map_tree', 'maps', m['slot'], 'header.json')
        if not os.path.exists(hp):
            continue
        h = json.load(open(hp))
        if h.get('layoutId') in want:
            return m['slot'], h
    raise SystemExit('no map_tree slot has layout %s' % map_id)

def find_pair(world, map_id, slot):
    if not os.path.exists(world):
        raise SystemExit('no world.json at %s (pass --pair)' % world)
    for m in json.load(open(world))['maps']:
        if m['id'] == map_id:
            if m.get('slot') != slot:
                print('warning: world.json slot %s != cache slot %s' % (m.get('slot'), slot), file=sys.stderr)
            return m['pair']
    raise SystemExit('%s not in world.json (pass --pair)' % map_id)

def load_map(map_id, cache=None, slot=None, pair=None, world=None):
    cache = cache or CACHE
    key = (map_id, cache, slot, pair, world)
    if key in _MAPS:
        return _MAPS[key]
    hdr = None
    if slot is None:
        slot, hdr = find_slot(cache, map_id)
    mdir = os.path.join(cache, 'map_tree', 'maps', slot)
    if hdr is None:
        hdr = json.load(open(os.path.join(mdir, 'header.json')))
    W, H = hdr['width'], hdr['height']
    grid = open(os.path.join(mdir, 'grid.bin'), 'rb').read()
    assert len(grid) == W * H * 2, "grid size %d != %dx%dx2" % (len(grid), W, H)
    v = np.frombuffer(grid, '<u2').reshape(H, W).astype(np.int64)
    if pair is None:
        pair = find_pair(world or WORLD, map_id, slot)
    d = os.path.join(cache, 'native', pair)
    count, cols, rows, ids = read_idx(os.path.join(d, 'mids.idx'))
    aw, ah = cols * 16, rows * 16
    layers = []
    for tag in ('u', 'm', 'o'):
        f = glob.glob(os.path.join(d, 'atlas_%s_*.rgba' % tag))
        layers.append(read_rgba(f[0], aw, ah) if f else None)
    comp = composite(layers)
    mid_to_slot = {mid: i for i, mid in enumerate(ids)}
    img = np.zeros((H * 16, W * 16, 4), np.uint8)
    mid = v & 0x3FF
    for cy in range(H):
        for cx in range(W):
            s = mid_to_slot.get(int(mid[cy, cx]))
            if s is None:
                continue
            sx, sy = (s % cols) * 16, (s // cols) * 16
            img[cy * 16:cy * 16 + 16, cx * 16:cx * 16 + 16] = comp[sy:sy + 16, sx:sx + 16]
    m = {'id': map_id, 'slot': slot, 'pair': pair, 'W': W, 'H': H, 'img': img,
         'mid': mid, 'coll': (v >> 10) & 3, 'elev': (v >> 12) & 0xF}
    _MAPS[key] = m
    return m

def window(map_id, x, y, scale=2, w=1280, h=720, dx=0, dy=0, cache=None, slot=None, pair=None, world=None):
    """Original art for the ortho45 window.  dx,dy: screen offset, so
    rgba[sy,sx] shows the reference at screen (sx+dx, sy+dy).
    Returns dict: rgba (h,w,4) uint8, alpha 0 outside map / no art;
    cx (w,), cy (h,): map cell column/row of each screen column/row (may be
    outside the map); inside (h,w) bool: pixel lies on the map;
    map: the loaded map (mid/coll/elev grids (H,W), id, slot, pair, W, H)."""
    m = load_map(map_id, cache, slot, pair, world)
    cx0, cy0 = x * 16 + 8, y * 16 + 8
    sx = np.arange(w) + dx
    sy = np.arange(h) + dy
    mx = np.floor(cx0 + (sx - w / 2.0) / scale).astype(np.int64)
    my = np.floor(cy0 + (sy - h / 2.0) / scale).astype(np.int64)
    pw, ph = m['W'] * 16, m['H'] * 16
    inx = (mx >= 0) & (mx < pw)
    iny = (my >= 0) & (my < ph)
    rgba = m['img'][np.clip(my, 0, ph - 1)[:, None], np.clip(mx, 0, pw - 1)[None, :]].copy()
    inside = iny[:, None] & inx[None, :]
    rgba[~inside, 3] = 0
    return {'rgba': rgba, 'cx': mx // 16, 'cy': my // 16, 'inside': inside, 'map': m}

def screen_map_px(x, y, scale=2, w=1280, h=720, dx=0, dy=0):
    """Map pixel (mx, my) under each screen column/row of window(x, y, ...): same formula."""
    cx0, cy0 = x * 16 + 8, y * 16 + 8
    mx = np.floor(cx0 + ((np.arange(w) + dx) - w / 2.0) / scale).astype(np.int64)
    my = np.floor(cy0 + ((np.arange(h) + dy) - h / 2.0) / scale).astype(np.int64)
    return mx, my

def building_mask(map_id, rect, cache=None, slot=None, pair=None, world=None):
    """BUILDING pixels of a rectangle (x0,y0,x1,y1 map cells, inclusive), from the original art only.
    Returns (H*16, W*16) bool over map pixels, True only inside the rectangle.
    Ring = map cells within 2 of the rectangle, outside it. Ground set = metatiles of walkable ring
    cells (collision 0) plus blocked ring metatiles seen at least 4 times in the ring (repeating
    terrain); a blocked id seen 1-3 times (a neighbouring wall) is not ground.
    Candidate ground pixel = opaque and equal to the same in-cell pixel of a ground-set tile.
    Silhouette: only candidates 4-connected to the rectangle's border through candidates are ground;
    every other opaque pixel is BUILDING. Transparent pixels are never BUILDING."""
    m = load_map(map_id, cache, slot, pair, world)
    img, mid, coll, W, H = m['img'], m['mid'], m['coll'], m['W'], m['H']
    x0, y0, x1, y1 = rect
    out = np.zeros((H * 16, W * 16), bool)
    rx0, rx1, ry0, ry1 = max(0, x0), min(W - 1, x1), max(0, y0), min(H - 1, y1)
    if rx0 > rx1 or ry0 > ry1:
        return out
    ring = np.zeros((H, W), bool)
    ring[max(0, y0 - 2):min(H, y1 + 3), max(0, x0 - 2):min(W, x1 + 3)] = True
    ring[max(0, y0):min(H, y1 + 1), max(0, x0):min(W, x1 + 1)] = False
    # ground set: walkable ring metatiles, and blocked ones that repeat (4+ cells in the ring)
    ground_ids = []
    for g in np.unique(mid[ring]):
        sel = ring & (mid == g)
        if (coll[sel] == 0).any() or sel.sum() >= 4:
            ground_ids.append(int(g))
    # tiles: the composited 16x16 of each ground metatile (the same pixels ref.py draws)
    py0, py1, px0, px1 = ry0 * 16, (ry1 + 1) * 16, rx0 * 16, (rx1 + 1) * 16
    R = img[py0:py1, px0:px1, :3].astype(np.int16)
    A = img[py0:py1, px0:px1, 3] > 0
    ny, nx = ry1 - ry0 + 1, rx1 - rx0 + 1
    cand = np.zeros(A.shape, bool)
    for g in ground_ids:
        cy, cx = (int(t) for t in np.argwhere(ring & (mid == g))[0])
        T = img[cy * 16:cy * 16 + 16, cx * 16:cx * 16 + 16]
        if not (T[..., 3] > 0).any():
            continue
        Tc = np.tile(T[..., :3].astype(np.int16), (ny, nx, 1))[:A.shape[0], :A.shape[1]]
        Ta = np.tile(T[..., 3] > 0, (ny, nx))[:A.shape[0], :A.shape[1]]
        cand |= (R == Tc).all(axis=2) & Ta & A
    # silhouette: flood the candidates inward from the rectangle's border (outside counts as outside)
    border = np.zeros(A.shape, bool)
    border[0, :] = border[-1, :] = border[:, 0] = border[:, -1] = True
    reach = cand & border
    while True:
        p = np.pad(reach, 1)
        grow = (p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:])[:A.shape[0], :A.shape[1]]
        new = (reach | (grow & cand))
        if (new == reach).all():
            break
        reach = new
    out[py0:py1, px0:px1] = A & ~reach
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('map'); ap.add_argument('x', type=int); ap.add_argument('y', type=int)
    ap.add_argument('out')
    ap.add_argument('--scale', type=int, default=2)
    ap.add_argument('--size', default='1280x720')
    ap.add_argument('--cache'); ap.add_argument('--slot'); ap.add_argument('--pair'); ap.add_argument('--world')
    a = ap.parse_args()
    w, h = (int(t) for t in a.size.lower().split('x'))
    r = window(a.map, a.x, a.y, a.scale, w, h, cache=a.cache, slot=a.slot, pair=a.pair, world=a.world)
    Image.fromarray(r['rgba'], 'RGBA').save(a.out)
    m = r['map']
    print('wrote', a.out, '%dx%d' % (w, h), m['id'], 'slot', m['slot'], 'pair', m['pair'],
          'cell (%d,%d) scale %d' % (a.x, a.y, a.scale))

if __name__ == '__main__':
    main()
