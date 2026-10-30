#!/usr/bin/env python3
"""model_diff.py <dirA> <dirB> [--min-overlap 0.5]  diff two per-UPLOAD geometry dumps model by model.

tools/rewrite/probe/model_driver.lua writes one file per mesh upload (`NNN.<layer>.tri`), which is the
only way to compare a layer the mod INSTANCES: in a merged dump every tree/canopy/pine model sits on
the origin and overlaps the others, which is why compare.py reads 0 for this layer. Both sides upload
one model per (drawing, variant) at the origin, so the same drawing on both sides should match
triangle for triangle.

For every upload of A it finds the upload of B with the largest identical-triangle overlap and prints
the pair (layer, quads, bbox, overlap %). Models with no partner are listed as missing: A-only = a
model the old look draws and we do not, B-only = a model we draw that the old look does not (that is
the class of fault the canopy slice found).

LIMITS (measured 2026-10-30, Route 111): a driver dump holds only the uploads of the LAST settled build,
so a model first uploaded in an earlier window of the same map is missing from the dump on that side
(the old look's window is also larger than ours, so the two sides do not hold the same tree set). Use
one spot per map and read the pair list as "models both sides uploaded at that spot", never as a full
inventory. It matched 1 of our 4 Route 111 stamp models against the old look's 16 (43 % of quad
for quad) and left 15 unmatched - a starting point for the model-parity item, not a gate yet.
"""
import os
import sys
import collections

TOL = 0.01


def load(path):
    with open(path) as f:
        head = f.readline().split()
        meta = {'verts': int(head[1]), 'tris': int(head[3]), 'idx': int(head[5]),
                'bbox': [float(x) for x in head[7:13]]}
        tris = set()
        for line in f:
            p = line.split()
            if len(p) != 9:
                continue
            v = [round(float(x) / TOL) for x in p]
            tri = tuple(sorted((tuple(v[0:3]), tuple(v[3:6]), tuple(v[6:9]))))
            tris.add(tri)
    meta['set'] = tris
    meta['n'] = len(tris)
    meta['bbox'] = [round(x, 1) for x in meta['bbox']]
    return meta


def folder(d):
    out = []
    for name in sorted(os.listdir(d)):
        if name.endswith('.tri'):
            m = load(os.path.join(d, name))
            m['name'] = name
            m['layer'] = name.split('.')[1] if '.' in name else '?'
            out.append(m)
    return out


def at_origin(m):
    """An instanced model: both sides upload it at the model origin, so its box straddles 0."""
    x0, y0, z0, x1, y1, z1 = m['bbox']
    if x0 > 1e8:
        return False
    return x1 - x0 <= 64 and z1 - z0 <= 64 and abs((x0 + x1) / 2) <= 16 and abs((z0 + z1) / 2) <= 16


def size_class(m):
    x0, y0, z0, x1, y1, z1 = m['bbox']
    return (round((x1 - x0) / 2), round((y1 - y0) / 2), round((z1 - z0) / 2))


def main():
    A, B = sys.argv[1], sys.argv[2]
    min_ov = 0.5
    if '--min-overlap' in sys.argv:
        min_ov = float(sys.argv[sys.argv.index('--min-overlap') + 1])
    a, b = folder(A), folder(B)
    # Only instanced models are comparable model for model (a world-space mesh sits at its own spot and
    # would never match): pair within a size class, so a 16x32 stamp is never matched against a tree.
    ia = [x for x in a if at_origin(x)]
    ib = [y for y in b if at_origin(y)]
    if ia or ib:
        a, b = ia, ib
        print(f'instanced models only: {len(a)} in A, {len(b)} in B')
    used = set()
    pairs = []
    for x in a:
        best, bestov = None, 0.0
        for i, y in enumerate(b):
            if i in used:
                continue
            if size_class(x) != size_class(y):
                continue
            ov = len(x['set'] & y['set']) / max(1, min(x['n'], y['n']))
            if ov > bestov:
                best, bestov = i, ov
        if best is not None and bestov >= min_ov:
            used.add(best)
            pairs.append((x, b[best], bestov))
        else:
            pairs.append((x, None, bestov))
    print(f'A={A} ({len(a)} uploads)  B={B} ({len(b)} uploads)')
    for x, y, ov in pairs:
        if y is None:
            print(f'  A-only {x["name"]:22s} layer={x["layer"]:6s} quads={x["n"]//2:5d} '
                  f'bbox={x["bbox"]}  (best overlap {ov:.0%})')
        else:
            same = 'SAME' if x['set'] == y['set'] else f'{ov:.0%} of {min(x["n"], y["n"])//2} quads'
            print(f'  {x["name"]:22s} vs {y["name"]:22s} layer={x["layer"]:6s} '
                  f'quads={x["n"]//2:5d}/{y["n"]//2:5d} bbox={x["bbox"]}/{y["bbox"]}  {same}')
    for i, y in enumerate(b):
        if i not in used:
            print(f'  B-only {y["name"]:22s} layer={y["layer"]:6s} quads={y["n"]//2:5d} bbox={y["bbox"]}')
    tot_a = sum(x['n'] for x in a) // 2
    tot_b = sum(y['n'] for y in b) // 2
    matched = sum(min(x['n'], y['n']) for x, y, _ in pairs if y is not None) // 2
    print(f'quads A={tot_a} B={tot_b} matched={matched} '
          f'({matched / max(1, tot_b):.0%} of B)  A-only models={sum(1 for _, y, _ in pairs if y is None)} '
          f'B-only models={len(b) - len(used)}')


if __name__ == '__main__':
    main()
