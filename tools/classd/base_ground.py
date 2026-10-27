#!/usr/bin/env python3
# base_ground.py <label>: from the tools/classd/base_ground.sh dumps: walkable cells (collision 0) REACHABLE on foot from each map's
# spot (4-neighbours over collision-0 cells, any height) whose drawn base differs from groundAt by more than TOL.
import sys, glob, os, collections, re
R = os.path.expanduser('~/Documents/Emerald/.autoloop/runs/' + sys.argv[1]); TOL = float(sys.argv[2]) if len(sys.argv) > 2 else 3
starts = {}
for f in glob.glob(R + '/maps_*'):
    for l in open(f):
        p = l.split()
        if len(p) >= 3: starts[p[0]] = (int(p[1]), int(p[2]))
cells = collections.defaultdict(dict)
for f in glob.glob(R + '/out_*.txt'):
    for l in open(f):
        p = l.split()
        if len(p) < 9 or p[0] == 'SKIP': continue
        kv = dict(x.split('=') for x in p[5:] if '=' in x)
        cells[p[0]][(int(p[1]), int(p[2]))] = (p[4], int(kv['coll']), float(kv['base']) if kv['base'] != 'nil' else None, float(kv['ground']), kv.get('bld') == '1', kv.get('civic') == '1', kv.get('deck') == '1')
tot = 0
for m, cs in sorted(cells.items()):
    s = starts.get(m)
    if not s or s not in cs: print(m, 'no start', s); continue
    seen = {s}; q = [s]
    while q:
        x, y = q.pop()
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + d[0], y + d[1])
            if n in cs and n not in seen and cs[n][1] == 0: seen.add(n); q.append(n)
    bad = [(c, cs[c]) for c in sorted(seen) if cs[c][2] is not None and abs(cs[c][2] - cs[c][3]) > TOL and not cs[c][6]]
    allw = sum(1 for c in cs if cs[c][1] == 0)
    print('%-34s walkable %5d reachable %5d  base!=ground %4d' % (m, allw, len(seen), len(bad)))
    for c, v in bad[:6]: print('      %s kind=%s base=%s ground=%s bld=%s civic=%s' % (c, v[0], v[2], v[3], v[4], v[5]))
    tot += len(bad)
print('total', tot)
