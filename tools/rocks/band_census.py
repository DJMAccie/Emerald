#!/usr/bin/env python3
"""P3a slice 2 census: on UNPINNED maps (caves, underwater, unpinned outdoors), which rock cells would the
pinned classifier's rule make FACE (two floor levels within reach), and how are those runs shaped.
Replicates Gen3Elevation's rock BFS: through rock cells only, sources = non-rock cells with a floor height
(weak: blocked non-rock cells with a height), reach = min(RMAX, dmin+SLACK).
  python3 band_census.py <cells dir> [SLACK=2] [RMAX=12] [DEPTH=99]"""
import sys, glob, os
from collections import Counter, defaultdict
D = sys.argv[1]; SLACK = int(sys.argv[2]) if len(sys.argv) > 2 else 2; RMAX = int(sys.argv[3]) if len(sys.argv) > 3 else 12
DEPTH = int(sys.argv[4]) if len(sys.argv) > 4 else 99   # a cell further than DEPTH from its nearest floor is mass, never band
ROCK = ('cliff', 'caveWall')
def load(p):
    cells, hdr = {}, ''
    for line in open(p):
        if line.startswith('#'): hdr = line.strip(); continue
        if not line.startswith('CELL'): continue
        t = line.split(); x, y = int(t[1]), int(t[2]); d = {}
        for kv in t[3:]:
            k, v = kv.split('=', 1); d[k] = v
        d['h'] = float(d['h']) if d['h'] != 'nil' else None
        cells[(x, y)] = d
    return cells, hdr
DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1))
tot = Counter(); courses_h = Counter(); depth_h = Counter(); runs_h = Counter(); rows = []
for p in sorted(glob.glob(os.path.join(D, '*.cells'))):
    cells, hdr = load(p); name = os.path.basename(p)[:-6]
    isRock = {k for k, d in cells.items() if d['coll'] == '7' and d['shape'] in ROCK and d['sea'] == '0'}
    def source(d):
        if d['h'] is None: return None, None
        if d['floor'] == '1': return d['h'], False
        return d['h'], True          # blocked non-rock with a height: weak
    cls = {}; info = {}
    for k0 in isRock:
        seen = {k0}; ring = [k0]; d = 0; dmin = None
        bestMax = bestMin = bestOther = None
        while ring and d <= RMAX and (dmin is None or d <= dmin + SLACK):
            nxt = []
            for q in ring:
                for dx, dy in DIRS:
                    k = (q[0] + dx, q[1] + dy)
                    if k in seen or k not in cells: continue
                    seen.add(k)
                    if k in isRock: nxt.append(k); continue
                    lv, weak = source(cells[k])
                    if lv is None: continue
                    if weak:
                        if bestOther is None or lv > bestOther: bestOther = lv
                    else:
                        if dmin is None: dmin = d + 1
                        if bestMax is None or lv > bestMax: bestMax = lv
                        if bestMin is None or lv < bestMin: bestMin = lv
            ring = nxt; d += 1
        if bestMax is not None and bestMax - bestMin > 0.25 and dmin <= DEPTH: c = 'TWO'
        elif bestMax is not None: c = 'ONE'
        elif bestOther is not None: c = 'OTHER'
        else: c = 'NONE'
        cls[k0] = c; info[k0] = (dmin, bestMin, bestMax)
    n = Counter(cls.values())
    # runs of TWO cells
    seen = set(); runs = 0; two_direct = 0
    for k0, c in cls.items():
        if c != 'TWO': continue
        if info[k0][0] == 1: two_direct += 1
        if k0 in seen: continue
        runs += 1; stack = [k0]; seen.add(k0); comp = []
        while stack:
            q = stack.pop(); comp.append(q)
            for dx, dy in DIRS:
                k = (q[0] + dx, q[1] + dy)
                if k in cls and cls[k] == 'TWO' and k not in seen: seen.add(k); stack.append(k)
        courses = max(round((info[q][2] - info[q][1]) / 16, 1) for q in comp)
        depth = max(info[q][0] for q in comp)
        courses_h[courses] += 1; depth_h[depth] += 1; runs_h[min(len(comp), 40)] += 1
    tot.update(n); tot['runs'] += runs; tot['two_direct'] += two_direct
    rows.append((name, hdr.split('type=')[-1] if 'type=' in hdr else '?', len(isRock), n['TWO'], n['ONE'], n['OTHER'], n['NONE'], runs, two_direct))
print('map type rock TWO ONE OTHER NONE runs TWOdirect')
for r in rows: print(' '.join(str(v) for v in r))
print('\nTOTAL rock', sum(tot[c] for c in ('TWO', 'ONE', 'OTHER', 'NONE')), 'TWO', tot['TWO'], 'ONE', tot['ONE'], 'OTHER', tot['OTHER'], 'NONE', tot['NONE'], 'runs', tot['runs'], 'TWO with a floor beside them', tot['two_direct'])
print('courses per run:', sorted(courses_h.items()))
print('max depth (cells from a floor) per run:', sorted(depth_h.items()))
print('run sizes (cells, capped 40):', sorted(runs_h.items()))
