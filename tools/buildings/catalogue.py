#!/usr/bin/env python3
"""The building checklist: one pane per building, drawn from its own metatiles.

Source of truth is tools/buildings/inventory.json -- door-anchored, named, one
row per building (no merged boxes). Each pane shows the building's original 2D
drawing (its box plus the roof rows drawn over the walkable ground above it),
its name, map, door and footprint.

  python3 tools/buildings/catalogue.py <outdir> [--per 24] [--cols 6]
Writes catalogue_NN.png sheets and catalogue.json (nothing ROM-derived is
committed: it reads the local QA cache only).
"""
import argparse, json, os, sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
import layers
import voxproto

INVENTORY = os.path.join(HERE, 'inventory.json')


def blocked(cells, W, x, y):
    if x < 0 or y < 0 or x >= W:
        return False
    v = cells[y * W + x]
    return bool((v >> 10) & 3)


def footprint(map_id, doors, cells, W, H):
    """A building is a BOX standing on its door row (the door-anchored method
    gen_emerald_tables.py uses): the facade's width is the run of built cells
    along the door row, and the box rises row by row while most of that width
    is still built. Rows may then be wider than the door row, but only by a
    few cells -- a bay narrower than the hall above it. Stopping on coverage is
    what keeps a Sootopolis house from swallowing the rock it stands on."""
    def built(x, y):
        return 0 <= x < W and 0 <= y < H and blocked(cells, W, x, y)
    best = None
    for (dx, dy) in doors:
        # The door cell itself is usually the warp tile, not a building cell:
        # anchor on the nearest built cell, preferring the one above it.
        ax, ay = dx, dy
        if not built(ax, ay):
            found = None
            for (ox, oy) in ((0, -1), (-1, 0), (0, 0), (1, 0), (0, 1), (-1, -1), (1, -1), (0, -2)):
                if built(dx + ox, dy + oy):
                    found = (dx + ox, dy + oy); break
            if not found:
                continue
            ax, ay = found
        dx, dy = ax, ay
        x0 = dx
        while x0 - dx <= 24 and built(x0 - 1, dy):
            x0 -= 1
        x1 = dx
        while x1 - dx <= 24 and built(x1 + 1, dy):
            x1 += 1
        # A run this wide is the town's own terrain (Sootopolis rock, Fortree's
        # platforms), not a facade: this anchor cannot show where the box ends.
        if x1 - x0 < 0 or x1 - x0 > 20:
            continue
        width = x1 - x0 + 1
        top = dy
        while top > 0:
            n = sum(1 for x in range(x0, x1 + 1) if built(x, top - 1))
            if n * 10 < width * 6:
                break
            top -= 1
        bot = dy
        while bot + 1 < H and sum(1 for x in range(x0, x1 + 1) if built(x, bot + 1)) * 10 >= width * 6:
            bot += 1
        box = [x0, top, x1, bot]
        if best is None or (box[2] - box[0]) * (box[3] - box[1]) > (best[2] - best[0]) * (best[3] - best[1]):
            best = box
    if best is None:
        # Nothing box-shaped around the door: crop the door and the art above
        # it so the building is still in the checklist, and flag it.
        for (dx, dy) in doors:
            return (dx - 4, max(0, dy - 6), dx + 4, dy + 1)
        return None
    x0, y0, x1, y1 = best
    # Rows may widen away from the door row: widen each row by up to 4 cells.
    for y in range(y0, y1 + 1):
        lo, hi = x0, x1
        while x0 - (lo - 1) <= 4 and built(lo - 1, y):
            lo -= 1
        while (hi + 1) - x1 <= 4 and built(hi + 1, y):
            hi += 1
        x0 = min(x0, lo); x1 = max(x1, hi)
    for (dx, dy) in doors:
        x0 = min(x0, dx); x1 = max(x1, dx)
        y0 = min(y0, dy); y1 = max(y1, dy)
    # The roof's top rows are painted over walkable ground above the box.
    while y0 > 0 and any(blocked(cells, W, x, y0 - 1) for x in range(x0, x1 + 1)):
        y0 -= 1
    return (x0, y0, x1, y1)


def compose(L, cells, W, H, box, pad=1):
    x0, y0, x1, y1 = box
    x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
    x1 = min(W - 1, x1 + pad); y1 = min(H - 1, y1 + pad)
    if x1 < x0 or y1 < y0:
        return None, x0, y0
    w, h = x1 - x0 + 1, y1 - y0 + 1
    img = np.zeros((h * 16, w * 16, 4), np.uint8)
    for yy in range(h):
        for xx in range(w):
            cx, cy = x0 + xx, y0 + yy
            if cx >= W or cy >= H:
                continue
            mid = cells[cy * W + cx] & 0x3FF
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
    return img, x0, y0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('out')
    ap.add_argument('--per', type=int, default=24)
    ap.add_argument('--cols', type=int, default=6)
    ap.add_argument('--pad', type=int, default=1)
    ap.add_argument('--only', default='')
    args = ap.parse_args()
    inv = json.load(open(INVENTORY))
    if args.only:
        want = {int(v) for v in args.only.split(',')}
        inv = [e for e in inv if e['n'] in want]
    os.makedirs(args.out, exist_ok=True)
    Ls, maps, panes, meta = {}, {}, [], []
    for e in inv:
        pair, map_id = e['pair'], e['map']
        if pair not in Ls:
            Ls[pair] = layers.load(pair)
        L = Ls[pair]
        if 'u' not in L:
            continue
        if map_id not in maps:
            maps[map_id] = voxproto.map_cells(map_id)
        W, H, cells = maps[map_id]
        fp = footprint(map_id, e['doors'], cells, W, H)
        if not fp:
            continue
        x0, y0, x1, y1 = fp
        img, ox, oy = compose(L, cells, W, H, fp, args.pad)
        if img is None:
            continue
        cells_w, cells_h = x1 - x0 + 1, y1 - y0 + 1
        meta.append({'n': e['n'], 'name': e['name'], 'map': map_id, 'pair': pair,
                     'doors': e['doors'], 'box': [x0, y0, x1, y1],
                     'cells': [cells_w, cells_h],
                     'kind': 'simple' if cells_w <= 5 and cells_h <= 4 else 'large'})
        im = Image.fromarray(img)
        s = min(300 / im.width, 210 / im.height, 4)
        im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.NEAREST)
        pane = Image.new('RGB', (312, 252), (18, 18, 22))
        pane.paste(im.convert('RGB'), (5, 34))
        d = ImageDraw.Draw(pane)
        d.text((5, 3), '%03d %s' % (e['n'], e['name'][:38]), fill=(255, 230, 120))
        d.text((5, 17), '%s  door %s  %dx%d' % (map_id[3:20], e['doors'][0], cells_w, cells_h),
               fill=(140, 200, 255))
        panes.append(pane)
    for i in range(0, len(panes), args.per):
        chunk = panes[i:i + args.per]
        cols = args.cols
        rows = (len(chunk) + cols - 1) // cols
        sheet = Image.new('RGB', (312 * cols, 252 * rows), (10, 10, 12))
        for j, p in enumerate(chunk):
            sheet.paste(p, ((j % cols) * 312, (j // cols) * 252))
        sheet.save(os.path.join(args.out, 'catalogue_%02d.png' % (i // args.per + 1)))
    json.dump(meta, open(os.path.join(args.out, 'catalogue.json'), 'w'), indent=1)
    print('%d buildings; %d large; %d sheets'
          % (len(meta), sum(1 for m in meta if m['kind'] == 'large'),
             (len(panes) + args.per - 1) // args.per))


if __name__ == '__main__':
    main()
