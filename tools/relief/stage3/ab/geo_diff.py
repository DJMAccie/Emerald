#!/usr/bin/env python3
"""geo_diff.py <A.geo.gz> <B.geo.gz> [tol 0.1]   ground ('under' kind) triangles present in only one dump, rounded to <tol> px so a .02 lift is invisible.
Prints counts by class (flat / wall / slope) and the top cells. A change that only moves heights by a hair or swaps a texture shows 0/0."""
import sys, os, collections
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'autoloop'))
import detect
LIBDIR = os.path.expanduser('~/Documents/battle-art-notquiteog/lib')

def keys(path, tol):
    head, tags, a = detect.load(path)
    kd = detect.source_lines(LIBDIR)
    under = {t for t, v in tags.items() if detect.tag_kind(kd, v['tag']) == 'under'}
    out = collections.Counter(); meta = {}
    for row in a:
        if int(row[0]) not in under:
            continue
        tri = np.round(row[1:10].reshape(3, 3) / tol) * tol
        k = tuple(sorted(map(tuple, tri.tolist())))
        out[k] += 1; meta[k] = tri
    return out, meta

def cls(t):
    if np.ptp(t[:, 1]) < 0.05: return 'flat'
    if np.ptp(t[:, 0]) < 0.05 or np.ptp(t[:, 2]) < 0.05: return 'wall'
    return 'slope'

if __name__ == '__main__':
    tol = float(sys.argv[3]) if len(sys.argv) > 3 else 0.1
    a, ma = keys(sys.argv[1], tol); b, mb = keys(sys.argv[2], tol)
    oa = [k for k in a if k not in b]; ob = [k for k in b if k not in a]
    print('under tris', sum(a.values()), sum(b.values()), '| only-A', len(oa), 'only-B', len(ob))
    for name, L, M in (('only-A', oa, ma), ('only-B', ob, mb)):
        print(' ', name, dict(collections.Counter(cls(M[k]) for k in L)))
        print('    top cells', collections.Counter((int(M[k][:, 0].mean() // 16), int(M[k][:, 2].mean() // 16)) for k in L).most_common(6))
