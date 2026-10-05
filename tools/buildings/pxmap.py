#!/usr/bin/env python3
"""Pixel map of a furniture piece against its floor (for Gen3PixelFurniture parts).
python3 pxmap.py MAP PAIR x0 y0 x1 y1 GROUNDMID[,GROUNDMID...]
'.' = floor colour (interior of the ground tiles), letters = object colours."""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
import bldmodel as M, layers
mp, pair = sys.argv[1:3]; x0, y0, x1, y1 = map(int, sys.argv[3:7])
img = M.compose(pair, mp, x0, y0, x1, y1)[..., :3].astype(int)
L = layers.load(pair); g = set()
for t in sys.argv[7].split(','):
    a = layers.tile(L, 'u', int(t, 16))[..., :3].astype(int); g |= {tuple(c) for c in a[4:12, 4:12].reshape(-1, 3)}
pal = {}
print('    ' + ''.join(str(x // 10 % 10) if x % 10 == 0 else ' ' for x in range(img.shape[1])))
for y in range(img.shape[0]):
    row = ''
    for x in range(img.shape[1]):
        c = tuple(img[y, x])
        if c in g: row += '.'
        else:
            if c not in pal: pal[c] = chr(65 + len(pal)) if len(pal) < 26 else chr(97 + len(pal) - 26)
            row += pal[c]
    print('%3d %s' % (y, row))
