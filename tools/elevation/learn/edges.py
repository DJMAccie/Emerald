#!/usr/bin/env python3
"""edges.py: cliff-face edges of the pinned maps with their true height step, and a leave-one-map-out test of two predictors.
An edge = walkable A (south, flat) -> g cliff/shelf cells (vertical run, one column) -> walkable B (north, flat); dH = H(B)-H(A) in courses,
H from the installed field (exact at the pins). Flat = the cell's four walkable neighbours have the same height."""
import sys, collections
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief'); sys.path.insert(0, '/Users/user/Documents/Emerald/tools/elevation/learn')
import emdata
from transects import grids, H
CL = ('cliff', 'shelf')
def edges(paths, skip=('FRONTIER',)):
    G = grids(paths); out = []
    for m in G:
        if any(s in m for s in skip): continue
        try: L = emdata.Layout(m)
        except Exception: continue
        def walk(x, y): return 0 <= x < L.w and 0 <= y < L.h and not L.blocked(x, y) and L.role_at(x, y) != 'water'
        def flat(x, y):
            h = H(G, m, x, y)
            if h is None or h != int(h): return False
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if walk(x + d[0], y + d[1]) and H(G, m, x + d[0], y + d[1]) != h: return False
            return True
        for x in range(L.w):
            for y in range(L.h - 1, -1, -1):
                if not walk(x, y): continue
                g = 0; yy = y - 1
                while yy >= 0 and L.blocked(x, yy) and L.role_at(x, yy) in CL: g += 1; yy -= 1
                if g >= 1 and walk(x, yy) and flat(x, y) and flat(x, yy):
                    out.append(dict(m=m, x=x, ya=y, yb=yy, g=g, d=int(H(G, m, x, yy) - H(G, m, x, y)), tiles=tuple(L.metatile(x, y - k) for k in range(1, g + 1)), pair=getattr(L, 'pair', None) or getattr(L, 'tileset', None)))
    return out
def mode(c): return c.most_common(1)[0][0]
if __name__ == '__main__':
    E = edges(sys.argv[1:]); print(len(E), 'edges', dict(collections.Counter(e['m'] for e in E)))
    # dedupe columns inside one cliff band: keep all (each column is a sample)
    maps = sorted(set(e['m'] for e in E)); tot = collections.Counter(); per = {}
    for hold in maps:
        tr = [e for e in E if e['m'] != hold]; te = [e for e in E if e['m'] == hold]
        byT = collections.defaultdict(collections.Counter); byG = collections.defaultdict(collections.Counter)
        for e in tr: byT[e['tiles']][e['d']] += 1; byG[e['g']][e['d']] += 1
        ok1 = ok2 = n = cov = 0; err1 = err2 = 0
        for e in te:
            n += 1
            p2 = mode(byG[e['g']]) if e['g'] in byG else e['g']
            p1 = mode(byT[e['tiles']]) if e['tiles'] in byT else p2
            cov += e['tiles'] in byT
            ok1 += p1 == e['d']; ok2 += p2 == e['d']; err1 += abs(p1 - e['d']); err2 += abs(p2 - e['d'])
        per[hold] = (n, cov, ok1, ok2, err1, err2)
        for k, v in zip('n cov tileExact rowsExact tileAbs rowsAbs'.split(), per[hold]): tot[k] += v
        print('%-26s n=%4d covered=%4d  tile-table exact %.2f (abs err %.2f)   rows-only exact %.2f (abs err %.2f)' % (hold, n, cov, ok1 / max(n, 1), err1 / max(n, 1), ok2 / max(n, 1), err2 / max(n, 1)))
    print('ALL n=%d covered %.2f  tile-table exact %.2f abs %.2f | rows-only exact %.2f abs %.2f' % (tot['n'], tot['cov'] / tot['n'], tot['tileExact'] / tot['n'], tot['tileAbs'] / tot['n'], tot['rowsExact'] / tot['n'], tot['rowsAbs'] / tot['n']))
