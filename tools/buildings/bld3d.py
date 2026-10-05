#!/usr/bin/env python3
"""Building model lab: compose a building's own metatile art (under + over
layers) into one ImageData, print its row structure, and read the drawing's
bands off it. This is the offline half of BuildingModels.lua.

  python3 tools/buildings/bld3d.py <bNNN|map:doorx,doory> [--out DIR]
"""
import argparse, json, os, sys, struct

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
import layers
import voxproto

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
BUILDINGS = json.load(open(os.path.expanduser('~/Documents/gen1recomp-modwork/buildings.json')))


def compose(pair, map_id, x0, y0, x1, y1):
    """The building's drawing: under layer + over layer of every cell."""
    L = layers.load(pair)
    W, H, cells = voxproto.map_cells(map_id)
    w, h = x1 - x0 + 1, y1 - y0 + 1
    img = np.zeros((h * 16, w * 16, 4), np.uint8)
    for yy in range(h):
        for xx in range(w):
            mid = cells[(y0 + yy) * W + x0 + xx] & 0x3FF
            u = layers.tile(L, 'u', mid)
            if u is None:
                continue
            t = u.astype(float)
            o = layers.tile(L, 'o', mid) if 'o' in L else None
            if o is not None:
                k = o[..., 3:4] / 255.0
                t[..., :3] = o[..., :3] * k + t[..., :3] * (1 - k)
                t[..., 3:4] = np.maximum(t[..., 3:4], o[..., 3:4])
            img[yy * 16:(yy + 1) * 16, xx * 16:(xx + 1) * 16] = t.astype(np.uint8)
    return img, W, H, cells


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('which')
    ap.add_argument('--out', default=os.path.join(ROOT, 'shots_bld', 'lab'))
    ap.add_argument('--pad', type=int, default=1)
    args = ap.parse_args()
    n = int(args.which.lstrip('bB'))
    b = BUILDINGS[n - 1]
    x0, y0, x1, y1 = b['box']
    W0, H0 = x1 - x0 + 1, y1 - y0 + 1
    x0 = max(0, x0 - args.pad); y0 = max(0, y0 - args.pad)
    x1 = x1 + args.pad; y1 = y1 + args.pad
    img, W, H, cells = compose(b['pair'], b['map'], x0, y0, x1, y1)
    os.makedirs(args.out, exist_ok=True)
    W0c, H0c = x1 - x0 + 1, y1 - y0 + 1
    tag = 'b%03d_%s' % (n, b['map'][3:].lower())
    Image.fromarray(img).save(os.path.join(args.out, tag + '.png'))
    # the same drawing with a cell grid, so bands can be read in map rows
    S = 6
    big = Image.fromarray(img).resize((img.shape[1] * S, img.shape[0] * S), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for i in range(H0c + 1):
        y = i * 16 * S
        d.line([(0, y), (big.width, y)], fill=(255, 0, 255, 255))
        d.text((2, y + 2), 'row %d' % (y0 + i), fill=(255, 255, 0))
    for i in range(W0c + 1):
        x = i * 16 * S
        d.line([(x, 0), (x, big.height)], fill=(255, 0, 255, 255))
    for i in range(W0c):
        d.text((i * 16 * S + 4, big.height - 14), 'c%d' % (x0 + i), fill=(0, 255, 255))
    # facade line: per column, the topmost row where the cell is wall art
    big.save(os.path.join(args.out, tag + '_grid.png'))
    print('%s  pair=%s cells=%dx%d box=%s' % (tag, b['pair'], W0, H0, b['box']))
    print('door', b['door'], 'image', img.shape[1], 'x', img.shape[0])
    # per map row: which cells carry over-layer art, and mean colour
    for yy in range(H0c):
        mids = [cells[(y0 + yy) * W + x0 + xx] & 0x3FF for xx in range(W0c)]
        band = img[yy * 16:(yy + 1) * 16]
        mean = band[:, :, :3].reshape(-1, 3).mean(0).astype(int)
        print('  row %2d mids=%s mean=%s' % (y0 + yy, ' '.join('%03X' % m for m in mids), mean))


if __name__ == '__main__':
    main()
