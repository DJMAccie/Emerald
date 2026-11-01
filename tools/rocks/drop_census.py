#!/usr/bin/env python3
"""P3a slice 3 census over the pinned maps' cell dumps: every plateau edge the hidden-ledge pass left as a bare drop
(bare=1 on the upper cell): how many courses it needs (drop / 16 px at 45 degrees), and how far the plain lower
ground in front of it extends (rows of eligible cells straight out from the edge, up to the need).
  python3 drop_census.py <cells dir>"""
import sys, glob, os
from collections import Counter
D = sys.argv[1]; LEDGE_MIN = 8; SPX = 16.0; LEDGE_MAX = 3
OK = ('flat', 'sand')
def load(p):
    cells = {}
    for line in open(p):
        if not line.startswith('CELL'): continue
        t = line.split(); d = dict(kv.split('=', 1) for kv in t[3:]); d['h'] = float(d['h']) if d['h'] != 'nil' else None
        cells[(int(t[1]), int(t[2]))] = d
    return cells
DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1))
def eligible(d):
    return d is not None and d['cls'] == 'PLATEAU' and d['floor'] == '1' and d['h'] is not None and d['step'] == '0' and d['layer'] != '15' \
        and d['kind'] != 'water' and d['tree'] == '0' and d['relief'] == '0' and d['shape'] in OK and d['coll'] == '0'
need_h = Counter(); reach_h = Counter(); per_map = []; tall_list = []
for p in sorted(glob.glob(os.path.join(D, '*.cells'))):
    name = os.path.basename(p)[:-6]; c = load(p)
    edges = 0; ledges = sum(1 for d in c.values() if d['ledge'] != 'nil')
    for (x, y), u in c.items():
        if u['bare'] != '1' or u['h'] is None: continue
        for dx, dy in DIRS:
            n = c.get((x + dx, y + dy))
            if n is None or n['h'] is None or n['floor'] != '1' and n['cls'] != 'WATER': continue
            drop = u['h'] - n['h']
            if drop < LEDGE_MIN: continue
            need = int(-(-drop // SPX))
            # rows of eligible plain ground straight out from the edge at the lower level
            reach = 0
            for r in range(1, need + 1):
                m = c.get((x + dx * r, y + dy * r))
                if eligible(m) and abs(m['h'] - n['h']) < .25: reach = r
                else: break
            edges += 1; need_h[need] += 1
            reach_h[('tall' if need > LEDGE_MAX else 'low', 'full' if reach >= need else ('none' if reach == 0 else 'part'))] += 1
            if need > LEDGE_MAX: tall_list.append((name, x, y, need, reach))
    per_map.append((name, edges, ledges))
print('bare-drop edges by courses needed:', sorted(need_h.items()))
print('edges (tall = over LEDGE_MAX 3) by plain ground in front (full = need rows, part, none):', sorted(reach_h.items()))
print('\nmap bareEdges ledgeCells')
for r in per_map:
    if r[1] or r[2]: print(*r)
tl = Counter((t[0], t[3]) for t in tall_list)
print('\ntall drops per map (map, courses): count'); 
for k, v in sorted(tl.items(), key=lambda kv: -kv[1])[:40]: print(k, v)
