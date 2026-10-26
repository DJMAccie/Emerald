#!/usr/bin/env python3
# hmap.py <dump> [map]  prints the grid of H (or base) per cell: "MID:H"
import sys
cells = {}; cur = None
for l in open(sys.argv[1]):
    p = l.split()
    if p[0] == 'MAP': cur = p[1]; cells[cur] = {}; continue
    x, y, mid, kind, coll, base, H = p[:7]; cells[cur][(int(x), int(y))] = (mid, kind, coll, base, H)
for m, c in cells.items():
    xs = sorted({k[0] for k in c}); ys = sorted({k[1] for k in c})
    print(m); print('     ' + ' '.join('%7d' % x for x in xs))
    for y in ys:
        print('%4d ' % y + ' '.join(('%s/%s' % (c[(x, y)][0], c[(x, y)][4] if c[(x, y)][4] != '-' else 'b' + c[(x, y)][3])).rjust(7) if (x, y) in c else '      .' for x in xs))
