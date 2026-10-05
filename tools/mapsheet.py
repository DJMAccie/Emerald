#!/usr/bin/env python3
"""Render one Emerald map from the gen1recomp cache with every cell's metatile
id (and collision / elevation) labelled, so building columns, tree groups and
cliff edges can be read off the actual map instead of guessed from the atlas.

  python3 mapsheet.py <cache-root> <group>_<num> <pair> <out.png> [--scale 4]

<group>_<num> is the map_tree/maps/ slot (census.json lists ids -> slots).
grid.bin holds width*height little-endian u16 cells in pret's map grid format:
bits 0-9 metatile id, 10-11 collision, 12-15 elevation.
"""
import os, sys, json, struct, glob, zlib, argparse
sys.path.insert(0, os.path.dirname(__file__))
from sheet import read_idx, read_rgba, png, FONT

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cache'); ap.add_argument('slot'); ap.add_argument('pair'); ap.add_argument('out')
    ap.add_argument('--scale', type=int, default=4)
    a = ap.parse_args()
    mdir = os.path.join(a.cache, 'map_tree', 'maps', a.slot)
    hdr = json.load(open(os.path.join(mdir, 'header.json')))
    W, H = hdr['width'], hdr['height']
    grid = open(os.path.join(mdir, 'grid.bin'), 'rb').read()
    assert len(grid) == W * H * 2, "grid size %d != %dx%dx2" % (len(grid), W, H)
    cells = struct.unpack('<%dH' % (W * H), grid)
    d = os.path.join(a.cache, 'native', a.pair)
    count, cols, rows, ids = read_idx(os.path.join(d, 'mids.idx'))
    aw, ah = cols * 16, rows * 16
    layers = []
    for tag in ('u', 'm', 'o'):
        f = glob.glob(os.path.join(d, 'atlas_%s_*.rgba' % tag))
        layers.append(read_rgba(f[0], aw, ah) if f else None)
    mid_to_slot = {mid: i for i, mid in enumerate(ids)}
    S = a.scale
    cell = 16 * S + 1
    OW, OH = W * cell + 1, H * cell + 1
    img = [bytearray(b'\x30\x30\x30\xff' * OW) for _ in range(OH)]
    def px(slot, x, y):
        sx, sy = (slot % cols) * 16 + x, (slot // cols) * 16 + y
        o = (sy * aw + sx) * 4
        r, g, b, al = layers[0][o], layers[0][o+1], layers[0][o+2], layers[0][o+3]
        for L in layers[1:]:
            if L is None:
                continue
            ao = L[o+3]
            if ao:
                k = ao / 255.0
                r, g, b = int(L[o]*k + r*(1-k)), int(L[o+1]*k + g*(1-k)), int(L[o+2]*k + b*(1-k))
        return r, g, b
    def text(ox, oy, s, fg):
        lw = len(s) * 4 + 1
        for y in range(7):
            row = img[oy + y]
            for x in range(lw):
                p = (ox + x) * 4
                row[p:p+4] = b'\x00\x00\x00\xff'
        for i, ch in enumerate(s):
            g_ = FONT.get(ch)
            if not g_:
                continue
            for y in range(5):
                for x in range(3):
                    if g_[y][x] == '1':
                        p = (ox + 1 + i * 4 + x) * 4
                        img[oy + 1 + y][p:p+4] = fg
    for cy in range(H):
        for cx in range(W):
            v = cells[cy * W + cx]
            mid, coll, elev = v & 0x3FF, (v >> 10) & 3, (v >> 12) & 0xF
            slot = mid_to_slot.get(mid)
            ox, oy = cx * cell + 1, cy * cell + 1
            for y in range(16):
                for x in range(16):
                    r, g, b = px(slot, x, y) if slot is not None else (255, 0, 255)
                    for sy in range(S):
                        row = img[oy + y * S + sy]
                        for sx in range(S):
                            p = (ox + x * S + sx) * 4
                            row[p:p+4] = bytes((r, g, b, 255))
            text(ox, oy, '%03X' % mid, b'\xff\xff\x00\xff')
            # collision (C=blocked) and elevation, bottom-left
            text(ox, oy + 16 * S - 8, ('C' if coll else '') + '%X' % elev, b'\x00\xff\xff\xff' if coll else b'\xa0\xa0\xa0\xff')
    open(a.out, 'wb').write(png(OW, OH, [bytes(r) for r in img]))
    print('wrote', a.out, '%dx%d cells' % (W, H), 'map', hdr['id'], 'type', hdr.get('mapType'))

if __name__ == '__main__':
    main()
