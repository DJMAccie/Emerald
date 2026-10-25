#!/usr/bin/env python3
# grid.py <run.log> [x0,y0,x1,y1]  print the [TR] mass lines as grids: cell = MID type(F face/L lid/T foliage) height
import sys, re
log = sys.argv[1]
box = list(map(int, sys.argv[2].split(','))) if len(sys.argv) > 2 else None
seen = set()
for l in open(log, errors='replace'):
    if '[TR] mass' not in l: continue
    head, _, cells = l.partition(' | ')
    if head in seen: continue
    seen.add(head)
    cs = {}
    for t in cells.split():
        p = t.split(':')
        x, y = map(int, p[0].split(','))
        cs[(x, y)] = (p[1], p[2], p[3][1:], p[4][1:], p[5])
    xs = [k[0] for k in cs]; ys = [k[1] for k in cs]
    if box and not any(box[0] <= x <= box[2] and box[1] <= y <= box[3] for x, y in cs): continue
    print(head.strip())
    for y in range(min(ys), max(ys) + 1):
        row = []
        for x in range(min(xs), max(xs) + 1):
            c = cs.get((x, y))
            row.append('   .   ' if not c else '%s%s%3s' % (c[0], c[1], c[2]))
        print('%3d ' % y + ' '.join(row))
    print('    ' + ' '.join('%4d   ' % x for x in range(min(xs), max(xs) + 1)))
