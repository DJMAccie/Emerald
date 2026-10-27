#!/usr/bin/env python3
"""transects2.py <dump.txt>...: vertical transects across cliff/shelf/wall rows only: walkable cell A (south) -> g cliff cells -> walkable B (north).
Prints per g: histogram of dH = H(B) - H(A) in courses, plus per-map medians."""
import sys, collections
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief'); sys.path.insert(0, '/Users/user/Documents/Emerald/tools/elevation/learn')
import emdata
from transects import grids, H
CL = ('cliff', 'shelf', 'wall')
def run(paths, maps=None):
    G = grids(paths); rows = []
    for m in G:
        if maps and m not in maps: continue
        try: L = emdata.Layout(m)
        except Exception: continue
        for x in range(L.w):
            y = L.h - 1
            while y >= 0:
                # find walkable A at y, then cliff run going north, then walkable B
                if not L.blocked(x, y) and L.role_at(x, y) not in ('water',):
                    g = 0; yy = y - 1
                    while yy >= 0 and L.blocked(x, yy) and L.role_at(x, yy) in CL: g += 1; yy -= 1
                    if g >= 1 and yy >= 0 and not L.blocked(x, yy) and L.role_at(x, yy) != 'water':
                        ha, hb = H(G, m, x, y), H(G, m, x, yy)
                        if ha is not None and hb is not None:
                            rows.append((m, x, y, yy, g, hb - ha, tuple(L.metatile(x, y - k) for k in range(1, g + 1))))
                y -= 1
    return rows
if __name__ == '__main__':
    rows = run(sys.argv[1:])
    hist = collections.defaultdict(collections.Counter)
    for r in rows: hist[r[4]][r[5]] += 1
    for g in sorted(hist):
        if g <= 8: print('gap', g, 'n', sum(hist[g].values()), dict(sorted(hist[g].items())))
