#!/usr/bin/env python3
"""Offline check for the duplicated-shoreline hypothesis (Gen3Boundary water donor).
Lists outdoor maps whose EDGE cells are water tiles with shore pixels baked in (sand/foam):
Gen3Boundary.resolve repeats the nearest edge tile beyond the map, so those tiles are replicated.
  cd tools/buildings && python3 ../props/shore_edges.py
Uses tools/analysis atlases through tools/buildings/layers (offline atlases work for unvisited maps)."""
import os, sys, json, collections
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'buildings'))
import bldmodel  # noqa: F401  (sets up the import path for layers)
import layers
w = json.load(open(os.path.expanduser('~/Documents/gen1recomp-modwork/world.json')))
cache, seen = {}, {}


def tile(pair, mid):
    if pair not in cache:
        cache[pair] = layers.load(pair)
    L = cache[pair]
    u = layers.tile(L, 'u', mid)
    if u is None:
        return None
    u = u.astype(float)
    if 'o' in L:
        o = layers.tile(L, 'o', mid)
        if o is not None:
            k = o[..., 3:4] / 255.
            u[..., :3] = o[..., :3] * k + u[..., :3] * (1 - k)
    return u[..., :3]


def waterness(t):
    r, g, b = t[..., 0], t[..., 1], t[..., 2]
    return ((b > r * 1.25) & (b >= g * 0.95)).mean()


rows = []
for e in w['maps']:
    if not e['pair'].startswith('general__') or e['type'] not in (1, 2, 3):
        continue
    W, H, c = e['w'], e['h'], e['cells']
    edge = {(x, 0) for x in range(W)} | {(x, H - 1) for x in range(W)} | {(0, y) for y in range(H)} | {(W - 1, y) for y in range(H)}
    bad, tot = collections.Counter(), 0
    for (x, y) in edge:
        mid = c[y * W + x] & 0x3FF
        k = (e['pair'], mid)
        if k not in seen:
            t = tile(*k)
            seen[k] = None if t is None else waterness(t)
        wv = seen[k]
        if wv is not None and wv > 0.5:
            tot += 1
            if wv < 0.93:
                bad[hex(mid)] += 1
    if tot:
        rows.append((sum(bad.values()), tot, e['id'], dict(bad)))
rows.sort(reverse=True)
print('maps with water on the edge:', len(rows), '| with shore-variant edge tiles:', sum(1 for r in rows if r[0]))
for n, tot, mid, bad in rows[:20]:
    print('%-36s %3d of %3d edge water cells carry shore pixels  %s' % (mid, n, tot, list(bad.items())[:4]))
