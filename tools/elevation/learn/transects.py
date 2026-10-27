#!/usr/bin/env python3
"""transects.py <dump.txt>...: vertical (and horizontal) transects across blocked cells between two walkable cells, from the pinned maps.
GRID rows of em_pins_driver dumps give the field height per cell (half-courses, base 36); emdata gives the 2D facts.
Prints, per gap length g (blocked cells between), the histogram of dH (courses, upper - lower, upper = the higher end)."""
import sys, re, collections
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
def grids(paths):
    G = collections.defaultdict(dict)
    for p in paths:
        for l in open(p):
            if l.startswith('GRID '):
                t = l.split(); m, y, row = t[1], int(t[2]), t[3]
                G[m][y] = row
    return G
def H(G, m, x, y):
    r = G[m].get(y)
    if r is None or x < 0 or x >= len(r) or r[x] == '.': return None
    return int(r[x], 36) / 2.0
if __name__ == '__main__':
    G = grids(sys.argv[1:]); hist = collections.defaultdict(collections.Counter); ex = collections.defaultdict(list)
    for m in G:
        try: L = emdata.Layout(m)
        except Exception as e: continue
        for axis in (0, 1):
            outer = range(L.w if axis == 0 else L.h); inner = L.h if axis == 0 else L.w
            for o in outer:
                run = []
                for i in range(inner + 1):
                    x, y = (o, i) if axis == 0 else (i, o)
                    ok = i < inner and not L.blocked(x, y) and L.role_at(x, y) not in ('water',)
                    blk = i < inner and L.blocked(x, y) and L.role_at(x, y) not in ('water', 'tree', 'fence', 'signpost')
                    if ok:
                        if run and run[-1][0] == 'g' and run[-1][1] >= 1 and len(run) >= 2 and run[-2][0] == 'w':
                            a = run[-2][1]; g = run[-1][1]; b = i
                            xa, ya = (o, a) if axis == 0 else (a, o); xb, yb = (o, b) if axis == 0 else (b, o)
                            ha, hb = H(G, m, xa, ya), H(G, m, xb, yb)
                            if ha is not None and hb is not None:
                                d = hb - ha if axis == 1 or True else 0
                                key = (axis, g); hist[key][abs(d)] += 1
                                if len(ex[key]) < 3: ex[key].append((m, xa, ya, xb, yb, d))
                        run = [r for r in run if r[0] == 'w'][-1:] + [('w', i)]
                    elif blk:
                        if run and run[-1][0] == 'g': run[-1] = ('g', run[-1][1] + 1)
                        elif run: run.append(('g', 1))
                    else: run = []
    for k in sorted(hist):
        if k[1] <= 8: print('axis', 'xy'[k[0]], 'gap', k[1], dict(sorted(hist[k].items())), ex[k][:2])
