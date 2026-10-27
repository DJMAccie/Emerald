#!/usr/bin/env python3
"""flights.py <dump>...: vertical stair runs (role 'stair') and single jump ledges between flat walkable cells: dH vs run length, from the installed field."""
import sys, collections
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief'); sys.path.insert(0, '/Users/user/Documents/Emerald/tools/elevation/learn')
import emdata
from transects import grids, H
G = grids(sys.argv[1:]); hist = collections.defaultdict(collections.Counter); per = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))
for m in G:
    if 'FRONTIER' in m: continue
    try: L = emdata.Layout(m)
    except Exception: continue
    def ok(x, y): return 0 <= x < L.w and 0 <= y < L.h and not L.blocked(x, y) and L.role_at(x, y) not in ('water', 'stair', 'ledge')
    def flat(x, y):
        h = H(G, m, x, y)
        return h is not None and h == int(h)
    for kind in ('stair', 'ledge'):
        for x in range(L.w):
            y = 0
            while y < L.h:
                if L.role_at(x, y) == kind:
                    y0 = y
                    while y < L.h and L.role_at(x, y) == kind: y += 1
                    n = y - y0
                    if ok(x, y0 - 1) and ok(x, y) and flat(x, y0 - 1) and flat(x, y):
                        d = int(H(G, m, x, y0 - 1) - H(G, m, x, y))   # north end minus south end (stairs climb north)
                        hist[(kind, n)][d] += 1; per[m][(kind, n)][d] += 1
                else: y += 1
for k in sorted(hist): print(k, dict(sorted(hist[k].items())))
