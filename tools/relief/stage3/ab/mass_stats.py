#!/usr/bin/env python3
# mass_stats.py <census dir>   per relief mass: cells, how many stand over the LOWEST walkable ground beside them (hmax - ground min);
# flat = share of those edge cells that stand < 8 px over it (a decal lying on the ground)
import sys, glob, collections, statistics as st
d = sys.argv[1]
M = collections.OrderedDict()
for f in sorted(glob.glob(d + '/dump_*.txt')):
    for l in open(f):
        p = l.split()
        if not p or p[0].startswith(('MASS', 'OFFHIST', 'SKIP')) or len(p) < 11: continue
        m, x, y, mid, coll, lo, hi, gl, gh, mouth, rid = p[:11]
        k = (m, int(rid))
        M.setdefault(k, []).append((float(lo), float(hi), None if gl == '-' else float(gl), None if gh == '-' else float(gh)))
rows = []
for (m, rid), cs in M.items():
    g = [c for c in cs if c[2] is not None]
    rise = [c[1] - c[2] for c in g]
    flat = sum(1 for r in rise if r < 8)
    top = max(c[1] for c in cs); bot = min(c[0] for c in cs)
    rows.append((m, rid, len(cs), len(g), st.median(rise) if rise else float('nan'), flat / len(g) if g else float('nan'), top - bot))
print('%-30s %4s %5s %5s %8s %6s %7s' % ('map', 'id', 'cells', 'edge', 'medRise', 'flat', 'span'))
for r in sorted(rows, key=lambda r: (r[0], -r[2])):
    if r[2] >= 8: print('%-30s %4d %5d %5d %8.1f %6.2f %7.1f' % r)
