#!/usr/bin/env python3
"""zfight.py <geo.gz> [x0,y0,x1,y1 cell box]   count z-fight pairs: horizontal triangles (normal up) of the ground meshes whose plane
is within 0.005 px of another one and that overlap it in xz (a triangle of B has its centroid inside A, A != B).
Prints total and per-tag-pair counts, then the cells (x,y) with the most pairs. Run WITHOUT -I? (numpy only: -I is fine)."""
import sys, os, collections
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'autoloop'))
import detect

def inside(P, A):
    # P (n,2) points; A (m,3,2) triangles -> (n,m) bool, barycentric sign test
    x, z = P[:, 0][:, None], P[:, 1][:, None]
    ax, az = A[:, 0, 0][None], A[:, 0, 1][None]; bx, bz = A[:, 1, 0][None], A[:, 1, 1][None]; cx, cz = A[:, 2, 0][None], A[:, 2, 1][None]
    d1 = (x - bx) * (az - bz) - (ax - bx) * (z - bz)
    d2 = (x - cx) * (bz - cz) - (bx - cx) * (z - cz)
    d3 = (x - ax) * (cz - az) - (cx - ax) * (z - az)
    neg = (d1 < -1e-4) | (d2 < -1e-4) | (d3 < -1e-4); pos = (d1 > 1e-4) | (d2 > 1e-4) | (d3 > 1e-4)
    return ~(neg & pos)

LIBDIR = os.path.expanduser('~/Documents/battle-art-notquiteog/lib')
TOL = 0.005    # a lifted patch (floor + .02) is NOT a pair

def pairs(path, box=None):
    head, tags, a = detect.load(path)
    kinds = {t: v['tag'] for t, v in tags.items()}
    kd = detect.source_lines(LIBDIR)
    under = {t for t, v in tags.items() if detect.tag_kind(kd, v['tag']) == 'under'}
    a = a[np.isin(a[:, 0].astype(int), list(under))]   # the 'over' pass redraws the same quads (same vertices): not a z-fight
    tri = a[:, 1:10].reshape(-1, 3, 3)
    ys = tri[:, :, 1]
    flat = (ys.max(1) - ys.min(1) < 0.01)
    # area > 0 (non-degenerate) and strictly horizontal
    ex = tri[:, 1, [0, 2]] - tri[:, 0, [0, 2]]; ey = tri[:, 2, [0, 2]] - tri[:, 0, [0, 2]]
    area = 0.5 * np.abs(ex[:, 0] * ey[:, 1] - ex[:, 1] * ey[:, 0])
    ok = flat & (area > 0.5)
    idx = np.where(ok)[0]
    cen = tri[idx].mean(1)
    buckets = collections.defaultdict(list)
    for k, i in enumerate(idx):
        c = cen[k]
        buckets[(int(c[0] // 16), int(c[2] // 16))].append(i)
    out = collections.Counter(); percell = collections.Counter(); total = 0
    for (cx, cz), L in buckets.items():
        if box and not (box[0] <= cx <= box[2] and box[1] <= cz <= box[3]):
            continue
        # compare against this cell and the 8 neighbours (a triangle straddling a cell edge)
        N = []
        for dx in (-1, 0, 1):
            for dz in (-1, 0, 1):
                N += buckets.get((cx + dx, cz + dz), [])
        N = np.array(sorted(set(N)))
        for i in L:
            yi = tri[i, 0, 1]
            m = N[(np.abs(tri[N, 0, 1] - yi) < TOL) & (N != i)]
            if len(m) == 0:
                continue
            P = tri[m].mean(1)[:, [0, 2]]
            A = tri[i][None][:, :, [0, 2]]
            hit = inside(P, A)[:, 0]
            for j in m[hit]:
                if j > i:
                    continue    # count each unordered pair once
                total += 1
                out[tuple(sorted((kinds[int(a[i, 0])], kinds[int(a[j, 0])])))] += 1
                percell[(cx, cz)] += 1
    return head, total, out, percell

if __name__ == '__main__':
    box = tuple(int(x) for x in sys.argv[2].split(',')) if len(sys.argv) > 2 else None
    head, total, out, percell = pairs(sys.argv[1], box)
    print(head.get('map'), 'zfight pairs', total)
    for k, v in out.most_common(6):
        print('  ', v, k)
    print('  top cells', percell.most_common(10))
