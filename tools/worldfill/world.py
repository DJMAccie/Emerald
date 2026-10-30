#!/usr/bin/env python3
"""The Hoenn overworld as one grid of cells, offline, from the gen1recomp cache.

Maps are joined by their header connections (pret rules), starting at Littleroot
Town at (0, 0); every map reached is an outdoor map of the continent and the sea.
Helpers here are shared by the world-fill tools:

  load_world()        -> {map_id: {'ox','oy','W','H','slot','pretId'}}  (EM_ ids)
  render(world, maps) -> RGBA image of those maps at 16 px per cell
"""
import os, sys, json
from collections import deque
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'ortho45'))
import ref  # noqa: E402  (load_map, layout_names, CACHE)

CACHE = ref.CACHE


def headers(cache=CACHE):
    census = json.load(open(os.path.join(cache, 'map_tree', 'census.json')))
    names = ref.layout_names(cache)
    out = {}
    for m in census['maps']:
        hp = os.path.join(cache, 'map_tree', 'maps', m['slot'], 'header.json')
        if not os.path.exists(hp):
            continue
        h = json.load(open(hp))
        h['slot'] = m['slot']
        h['emId'] = names.get(h.get('layoutId'))
        out[h['id']] = h
    return out


def load_world(root='LittlerootTown', cache=CACHE):
    hs = headers(cache)
    pos = {root: (0, 0)}
    q = deque([root])
    while q:
        cur = q.popleft()
        h = hs[cur]
        cx, cy = pos[cur]
        for c in h.get('connections') or []:
            n = hs.get(c['map'])
            if not n or c['dir'] not in ('north', 'south', 'east', 'west'):
                continue
            off = c.get('offset', 0)
            if c['dir'] == 'north':
                p = (cx + off, cy - n['height'])
            elif c['dir'] == 'south':
                p = (cx + off, cy + h['height'])
            elif c['dir'] == 'east':
                p = (cx + h['width'], cy + off)
            else:
                p = (cx - n['width'], cy + off)
            if c['map'] not in pos:
                pos[c['map']] = p
                q.append(c['map'])
    world = {}
    for pid, (x, y) in pos.items():
        h = hs[pid]
        world[h['emId'] or pid] = {'ox': x, 'oy': y, 'W': h['width'], 'H': h['height'],
                                   'slot': h['slot'], 'pretId': pid, 'emId': h['emId']}
    return world


def bounds(world):
    x0 = min(e['ox'] for e in world.values()); y0 = min(e['oy'] for e in world.values())
    x1 = max(e['ox'] + e['W'] for e in world.values()); y1 = max(e['oy'] + e['H'] for e in world.values())
    return x0, y0, x1, y1


def cell_means(world, cache=CACHE):
    """Per-cell mean colour of every map, as one image (1 px per cell) and a coverage mask."""
    x0, y0, x1, y1 = bounds(world)
    W, H = x1 - x0, y1 - y0
    img = np.zeros((H, W, 3), np.float32)
    cov = np.zeros((H, W), bool)
    for mid, e in world.items():
        try:
            m = ref.load_map(mid, cache=cache, slot=e['slot'])
        except SystemExit as err:
            print('skip', mid, err, file=sys.stderr)
            continue
        a = m['img'].astype(np.float32)
        mean = a.reshape(e['H'], 16, e['W'], 16, 4)[..., :3].mean(axis=(1, 3))
        ys, xs = e['oy'] - y0, e['ox'] - x0
        img[ys:ys + e['H'], xs:xs + e['W']] = mean
        cov[ys:ys + e['H'], xs:xs + e['W']] = True
    return img, cov, (x0, y0)


if __name__ == '__main__':
    w = load_world()
    print(len(w), 'maps; bounds', bounds(w))
    for k in sorted(w, key=lambda k: (w[k]['oy'], w[k]['ox'])):
        e = w[k]
        print('%-34s %5d %5d %4d x %-4d' % (k, e['ox'], e['oy'], e['W'], e['H']))
