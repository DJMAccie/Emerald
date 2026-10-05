#!/usr/bin/env python3
"""Map art with each cell's metatile id (and collision) printed on it:
python3 midgrid.py out.png MAP PAIR   (interiors: the whole map)"""
import sys, os
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
import bldmodel as M, voxproto
out, mp, pair = sys.argv[1:4]
W, H, cells = voxproto.map_cells(mp)
im = Image.fromarray(M.compose(pair, mp, 0, 0, W - 1, H - 1)).convert('RGB').resize((W * 48, H * 48), Image.NEAREST)
d = ImageDraw.Draw(im)
for y in range(H):
    for x in range(W):
        v = cells[y * W + x]
        d.rectangle((x * 48, y * 48, x * 48 + 47, y * 48 + 47), outline=(255, 0, 0))
        d.rectangle((x * 48 + 1, y * 48 + 1, x * 48 + 30, y * 48 + 11), fill=(0, 0, 0))
        d.text((x * 48 + 2, y * 48 + 1), '%03X%s' % (v & 0x3ff, '#' if v >> 10 & 3 else ''), fill=(255, 255, 0))
        if y == 0: d.text((x * 48 + 2, y * 48 + 36), str(x), fill=(0, 255, 255))
    d.text((1, y * 48 + 36), str(y), fill=(0, 255, 255))
im.save(out)
