#!/usr/bin/env python3
"""Trace the gaps between Hoenn's maps from the filled reference into the game's own tiles.

  python3 make_fill.py [--out ~/Documents/battle-art-notquiteog/assets/worldfill]

Reads ref/filled.png (the user's reference, 16 px per cell) and ref/register.json (register.py), and the
gen1recomp cache (map grids, tileset pair atlases). Every reference cell that no map covers gets the
(pair, metatile) whose 16x16 look equals the reference block, colours compared after the 5-bit palette
widening the reference uses (multiples of 8):
  - the open sea tile 0x170 (and blue blocks that match nothing) -> 0: the flight's textured sea plane shows it;
  - a primary tile (< 0x200) -> the pair of the nearest map, so the flight reuses an atlas it already loads;
  - a secondary tile -> the nearest map's pair if it has that look, else the pair most used by maps that has it;
  - no exact match -> the nearest look (sum of squared colour differences) among the pairs around it.

Writes <out>/fill.bin and <out>/placements.lua (gitignored: traced from third-party art):
  fill.bin  'WFIL' u16 version=1, i16 ox, i16 oy (Littleroot-frame cell of the grid's top-left), u16 W, u16 H,
            u16 npairs, then npairs x (u8 len, name), then the zlib-compressed W*H little-endian u16 cells:
            0 = a map covers it or open sea, else (pair index + 1) << 10 | metatile.
  placements.lua  maps no connection reaches, at their reference spots (Littleroot-frame cells).
Also writes ref/fill_stats.json and ref/fill_preview.png (the fill alone, 1/4 scale).
"""
import os, sys, json, glob, zlib, struct, argparse
from collections import Counter, defaultdict
import numpy as np
from PIL import Image
from scipy import ndimage
import world as Wd, ref as R

Image.MAX_IMAGE_PIXELS = None
HERE = os.path.dirname(os.path.abspath(__file__))
SEA_MID = 0x170


def q8(a):
    return ((a.astype(np.int32) * 31 + 127) // 255) * 8


def pair_looks(pair):
    d = os.path.join(R.CACHE, 'native', pair)
    count, cols, rows, ids = R.read_idx(os.path.join(d, 'mids.idx'))
    layers = []
    for tag in ('u', 'm', 'o'):
        f = glob.glob(os.path.join(d, 'atlas_%s_*.rgba' % tag))
        layers.append(R.read_rgba(f[0], cols * 16, rows * 16) if f else None)
    rgb = q8(R.composite(layers)[..., :3]).astype(np.uint8)
    out = {}
    for s, mid in enumerate(ids):
        sx, sy = (s % cols) * 16, (s // cols) * 16
        out[mid] = rgb[sy:sy + 16, sx:sx + 16].copy()
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.expanduser('~/Documents/battle-art-notquiteog/assets/worldfill'))
    a = ap.parse_args()
    os.chdir(HERE)
    reg = json.load(open('ref/register.json'))
    img = np.asarray(Image.open('ref/filled.png').convert('RGB'))
    CH, CW = img.shape[0] // 16, img.shape[1] // 16
    gx0, gy0 = reg['world_x0'] - reg['px'] // 16, reg['world_y0'] - reg['py'] // 16   # grid top-left, Littleroot frame
    blocks = img[:CH * 16, :CW * 16].reshape(CH, 16, CW, 16, 3).transpose(0, 2, 1, 3, 4)

    world = Wd.load_world()
    WORLDJ = {m['id']: m for m in json.load(open(R.WORLD))['maps']}
    hs = Wd.headers()
    byem = {h['emId']: h for h in hs.values() if h.get('emId')}

    # maps no connection reaches, at their reference spots
    iso = json.load(open('ref/isolated.json'))
    place = {k: {'ox': v['ox'], 'oy': v['oy'], 'W': v['W'], 'H': v['H']} for k, v in iso.items()}
    # Sootopolis: not drawn in the reference; centred on the light crater cells of Route 126 (laid only when flown to)
    r126 = world['EM_ROUTE126']
    sub = blocks[r126['oy'] - gy0:r126['oy'] - gy0 + r126['H'], r126['ox'] - gx0:r126['ox'] - gx0 + r126['W']]
    light = sub.reshape(r126['H'], r126['W'], -1).mean(axis=2) > 170
    ys, xs = np.nonzero(light)
    h = byem['EM_SOOTOPOLIS_CITY']
    cx, cy = r126['ox'] + xs.mean() + .5, r126['oy'] + ys.mean() + .5
    place['EM_SOOTOPOLIS_CITY'] = {'ox': int(round(cx - h['width'] / 2)), 'oy': int(round(cy - h['height'] / 2)),
                                   'W': h['width'], 'H': h['height'], 'overlay': True}

    owner = np.full((CH, CW), -1, np.int32)
    names = []
    def cover(name, e):
        x, y = e['ox'] - gx0, e['oy'] - gy0
        names.append(name)
        owner[max(0, y):y + e['H'], max(0, x):x + e['W']] = len(names) - 1
    for k, e in list(world.items()) + [(k, v) for k, v in place.items() if not v.get('overlay')]:
        cover(k, e)
    # nearest map per cell, for its pair
    _, (iy, ix) = ndimage.distance_transform_edt(owner < 0, return_indices=True)
    near = owner[iy, ix]
    mapPair = [WORLDJ.get(nm, {}).get('pair') for nm in names]

    # looks of every general pair (the maps' own first)
    used = Counter(p for p in mapPair if p)
    allpairs = sorted({m['pair'] for m in WORLDJ.values() if m.get('pair') and m['pair'].startswith('general__')})
    looks = {}
    for p in allpairs:
        if os.path.exists(os.path.join(R.CACHE, 'native', p, 'mids.idx')):
            looks[p] = pair_looks(p)
    index = defaultdict(list)   # look bytes -> [(pair, mid)]
    for p, lk in looks.items():
        for mid_, b in lk.items():
            index[b.tobytes()].append((p, mid_))
    seaKey = looks['general__petalburg'][SEA_MID].tobytes()

    cells = np.zeros((CH, CW), np.uint16)
    pairs = []
    pidx = {}
    def pid(p):
        if p not in pidx:
            pidx[p] = len(pairs); pairs.append(p)
        return pidx[p]
    stats = Counter()
    def block(y, x, dy=0, dx=0):
        y0, x0 = y * 16 + dy, x * 16 + dx
        if y0 < 0 or x0 < 0 or y0 + 16 > img.shape[0] or x0 + 16 > img.shape[1]:
            return None
        return img[y0:y0 + 16, x0:x0 + 16]
    def match(y, x, b):
        """(pair, mid) for an exact look, 'sea', or None"""
        k = b.tobytes()
        if k == seaKey:
            return 'sea'
        hits = index.get(k)
        if not hits:
            return None
        np_ = mapPair[near[y, x]] or 'general__petalburg'
        hp = {p for p, _ in hits}
        p = np_ if np_ in hp else max(hp, key=lambda q: (used.get(q, 0), q))
        m = next(m for q, m in hits if q == p)
        return 'sea' if m == SEA_MID else (p, m)
    def put(y, x, r, tag):
        if r == 'sea':
            stats['sea'] += 1
        else:
            cells[y, x] = (pid(r[0]) + 1) << 10 | r[1]
            stats[tag] += 1
    miss = np.zeros((CH, CW), bool)
    for y in range(CH):
        for x in range(CW):
            if owner[y, x] >= 0:
                continue
            r = match(y, x, blocks[y, x])
            if r is None:
                miss[y, x] = True
            else:
                put(y, x, r, 'exact')
    # patches pasted off the 16 px grid: find each patch's pixel shift and match it at that shift
    lab, n = ndimage.label(miss)
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        pick = np.linspace(0, len(ys) - 1, min(len(ys), 40)).astype(int)
        best = (0, 0, 0)
        for dy in range(-8, 8):
            for dx in range(-8, 8):
                if dx == 0 and dy == 0:
                    continue
                hit = 0
                for j in pick:
                    b = block(ys[j], xs[j], dy, dx)
                    if b is not None and match(ys[j], xs[j], b) is not None:
                        hit += 1
                if hit > best[0]:
                    best = (hit, dy, dx)
        if best[0] >= max(3, len(pick) // 3):
            got = 0
            for y, x in zip(ys, xs):
                b = block(y, x, best[1], best[2])
                r = b is not None and match(y, x, b)
                if r:
                    put(y, x, r, 'shifted'); miss[y, x] = False; got += 1
            print('patch %d (%d cells at %d,%d): shift %d,%d px, %d matched' % (i, len(ys), xs.mean(), ys.mean(), best[2], best[1], got))
    # Southern Island: the reference redraws it, so the real map sits on the biggest patch still unmatched in the south
    lab, n = ndimage.label(miss)
    best = None
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        col = blocks[ys, xs].reshape(-1, 3).mean(axis=0)
        blue = np.abs(col - np.array([80, 104, 208])).sum() < 60
        if len(ys) > 200 and not blue and ys.mean() > CH * .8 and (best is None or len(ys) > best[0]):
            best = (len(ys), xs.mean(), ys.mean())
    if best:
        h = byem['EM_SOUTHERN_ISLAND_EXTERIOR']
        cx, cy = best[1] + gx0 + .5, best[2] + gy0 + .5
        e = {'ox': int(round(cx - h['width'] / 2)), 'oy': int(round(cy - h['height'] / 2)), 'W': h['width'], 'H': h['height']}
        place['EM_SOUTHERN_ISLAND_EXTERIOR'] = e
        x, y = e['ox'] - gx0, e['oy'] - gy0
        cells[y:y + e['H'], x:x + e['W']] = 0
        miss[y:y + e['H'], x:x + e['W']] = False
        owner[y:y + e['H'], x:x + e['W']] = 10 ** 6
    # what still matches nothing: blue blocks are sea; others take the nearest look in the pairs around them
    B = np.array([80, 104, 208], np.float32)
    for y, x in zip(*np.nonzero(miss)):
        b = blocks[y, x].astype(np.float32)
        if np.abs(b.reshape(-1, 3).mean(axis=0) - B).sum() < 60:
            stats['sea_other'] += 1; continue
        cand = {mapPair[near[y, x]] or 'general__petalburg'}
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                yy, xx = y + dy, x + dx
                if 0 <= yy < CH and 0 <= xx < CW and cells[yy, xx]:
                    cand.add(pairs[(int(cells[yy, xx]) >> 10) - 1])
        bestd, bp, bm = None, None, None
        for p in cand:
            for m, lk in looks.get(p, {}).items():
                d = float(((lk.astype(np.float32) - b) ** 2).sum())
                if bestd is None or d < bestd:
                    bestd, bp, bm = d, p, m
        if bm is None or bm == SEA_MID:
            stats['sea_nearest'] += 1; continue
        put(y, x, (bp, bm), 'nearest')
    np.save('ref/fill_cells.npy', cells)
    assert len(pairs) < 63, 'too many pairs for the u16 cell code'

    os.makedirs(a.out, exist_ok=True)
    head = b'WFIL' + struct.pack('<HhhHHH', 1, gx0, gy0, CW, CH, len(pairs))
    for p in pairs:
        nb = p.encode(); head += struct.pack('<B', len(nb)) + nb
    open(os.path.join(a.out, 'fill.bin'), 'wb').write(head + zlib.compress(cells.astype('<u2').tobytes(), 9))
    with open(os.path.join(a.out, 'placements.lua'), 'w') as f:
        f.write('-- maps no connection reaches, at their spots in the filled reference (cells, Littleroot frame);\n')
        f.write('-- written by ~/Documents/Emerald/tools/worldfill/make_fill.py. overlay = laid only when flown to.\n')
        f.write('return {\n')
        for k in sorted(place):
            v = place[k]
            f.write(' %s={ox=%d,oy=%d,w=%d,h=%d%s},\n' % (k, v['ox'], v['oy'], v['W'], v['H'], ',overlay=true' if v.get('overlay') else ''))
        f.write('}\n')
    json.dump({'stats': stats, 'pairs': pairs, 'grid': [gx0, gy0, CW, CH], 'placements': place},
              open('ref/fill_stats.json', 'w'), indent=1)
    print(dict(stats), len(pairs), 'pairs:', pairs)
    print('placements', json.dumps(place))
    print('fill.bin', os.path.getsize(os.path.join(a.out, 'fill.bin')), 'bytes')


if __name__ == '__main__':
    main()
