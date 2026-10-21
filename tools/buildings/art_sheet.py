#!/usr/bin/env python3
"""Pixel-accurate art sheet of a building's ORIGINAL drawing, for recipe work.

  art_sheet.py PAIR MAP x0 y0 x1 y1 OUT.png [--scale 6] [--band y0,y1]

Renders the composed drawing exactly as the baker sees it (bldmodel.compose: under + over layers) with:
- every art pixel as a scale x scale block (nearest neighbour: no smoothing, no invented pixels),
- the 16-px TILE grid drawn on top (thin white lines) and the tile origin marked,
- a ruler every 8 px along both edges, numbered, so a recipe constant can be read off the image,
- the caller's chosen band (--band) outlined, so a facade band is unambiguous,
- a legend of the drawing's colours with their pixel count and a sample position.
The point: a recipe constant must come from a pixel a person can point at, not from a smoothed thumbnail.
"""
import os, sys, collections
import numpy as np
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
import bldmodel as M

PAD = 26   # room for the rulers


def main(argv):
    pair, map_id = argv[0], argv[1]
    x0, y0, x1, y1 = (int(v) for v in argv[2:6])
    out = argv[6]
    scale = int(argv[argv.index('--scale') + 1]) if '--scale' in argv else 6
    band = None
    if '--band' in argv:
        band = [int(v) for v in argv[argv.index('--band') + 1].split(',')]
    img = M.compose(pair, map_id, x0, y0, x1, y1)[..., :3].astype(np.uint8)
    H, W = img.shape[:2]
    S = scale
    canvas = Image.new('RGB', (W * S + PAD, H * S + PAD), (24, 24, 24))
    art = Image.fromarray(img).resize((W * S, H * S), Image.NEAREST)
    canvas.paste(art, (PAD, PAD))
    d = ImageDraw.Draw(canvas)
    # tile grid
    for gx in range(0, W + 1, 16):
        d.line([(PAD + gx * S, PAD), (PAD + gx * S, PAD + H * S)], fill=(255, 255, 255, 90), width=1)
    for gy in range(0, H + 1, 16):
        d.line([(PAD, PAD + gy * S), (PAD + W * S, PAD + gy * S)], fill=(255, 255, 255, 90), width=1)
    # rulers every 8 px
    for x in range(0, W, 8):
        d.line([(PAD + x * S, PAD - 4), (PAD + x * S, PAD - 1)], fill=(255, 255, 0))
        d.text((PAD + x * S + 1, 2), str(x), fill=(255, 255, 0))
    for y in range(0, H, 8):
        d.line([(PAD - 4, PAD + y * S), (PAD - 1, PAD + y * S)], fill=(255, 255, 0))
        d.text((1, PAD + y * S - 3), str(y), fill=(255, 255, 0))
    # the named band
    if band and len(band) >= 2:
        by0, by1 = band[0], band[1]
        bx0, bx1 = (band[2], band[3]) if len(band) > 3 else (0, W - 1)
        d.rectangle([PAD + bx0 * S - 2, PAD + by0 * S - 2, PAD + (bx1 + 1) * S + 1, PAD + (by1 + 1) * S + 1],
                    outline=(0, 255, 0), width=3)
        d.text((PAD + bx0 * S + 4, PAD + by0 * S + 4), 'facade band rows %d..%d' % (by0, by1), fill=(0, 255, 0))
    # legend (kept in the console: the image stays 1:1 art)
    cnt = collections.Counter(map(tuple, img.reshape(-1, 3)))
    print('%s %s  %dx%d px (%d x %d cells)  scale %dx  -> %s' % (map_id, pair, W, H, x1 - x0 + 1, y1 - y0 + 1, S, out))
    print('colours (%d):' % len(cnt))
    for c, n in cnt.most_common(12):
        d.rectangle([PAD + W * S + 2, 2, PAD + W * S + 2, 2], outline=c)   # keep drawing area clean
        print('   %-18s %6d px  %5.1f%%' % (str(tuple(int(v) for v in c)), n, 100.0 * n / (W * H)))
    canvas.save(out)
    print('wrote', out)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
