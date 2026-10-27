#!/usr/bin/env python3
"""geo_cmp.py <h3geo label dir> [tol 0.1]   per map: triangles only in control vs control2 (noise) and control vs probe; classes + top cells of the probe-only differences that the noise does not show."""
import sys, os, gzip, collections
import numpy as np
D = sys.argv[1]; tol = float(sys.argv[2]) if len(sys.argv) > 2 else 0.1
def load(p):
    tris = []
    with gzip.open(p, 'rt') as f:
        for l in f:
            if l.startswith('T '):
                v = l.split(); tris.append([float(x) for x in v[2:11]])
    a = np.array(tris).reshape(-1, 3, 3)
    a = np.round(a / tol) * tol
    c = collections.Counter(); meta = {}
    for t in a:
        k = tuple(sorted(map(tuple, t.tolist()))); c[k] += 1; meta[k] = t
    return c, meta
def cls(t):
    t = np.array(t)
    if np.ptp(t[:, 1]) < 0.05: return 'flat'
    if np.ptp(t[:, 0]) < 0.05 or np.ptp(t[:, 2]) < 0.05: return 'wall'
    return 'slope'
def diff(a, b):
    return [k for k in a if k not in b], [k for k in b if k not in a]
for fn in sorted(os.listdir(D + '/control')):
    if not fn.endswith('.geo.gz'): continue
    m = fn[:-7]
    c, mc = load(f'{D}/control/{fn}'); c2, mc2 = load(f'{D}/control2/{fn}'); p, mp = load(f'{D}/probe/{fn}')
    n1, n2 = diff(c, c2); pa, pb = diff(c, p)
    noise = {(int(mc[k][:, 0].mean() // 16), int(mc[k][:, 2].mean() // 16)) for k in n1} | {(int(mc2[k][:, 0].mean() // 16), int(mc2[k][:, 2].mean() // 16)) for k in n2}
    cellsP = collections.Counter()
    for k in pa: cellsP[(int(mc[k][:, 0].mean() // 16), int(mc[k][:, 2].mean() // 16))] += 1
    for k in pb: cellsP[(int(mp[k][:, 0].mean() // 16), int(mp[k][:, 2].mean() // 16))] += 1
    real = {c_: n for c_, n in cellsP.items() if c_ not in noise}
    print(f'{m}: noise {len(n1)}/{len(n2)} cells {len(noise)} | probe only-ctrl {len(pa)} only-probe {len(pb)} cells {len(cellsP)} (outside noise cells: {len(real)}) classes ctrl {dict(collections.Counter(cls(mc[k]) for k in pa))} probe {dict(collections.Counter(cls(mp[k]) for k in pb))}')
    print('   cells:', sorted(real)[:40])
