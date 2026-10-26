#!/usr/bin/env python3
# spots.py [maxPerMap]  -> spots.csv (map,x,y,group,rockcells): walkable cells with the most blocked (rock) cells in the camera window; maps with an identical grid are one group (first map is captured)
import sys, csv, hashlib, collections
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
_man = emdata.manifest(); _norm = {k[3:].replace('_', ''): k for k in _man}
_orig = emdata.em_name
emdata.em_name = lambda i: _norm.get(i.replace('_', '').upper()) or _orig(i)
K = int(sys.argv[1]) if len(sys.argv) > 1 else 2
rows = list(csv.DictReader(open('census_cells.csv')))
out = []; seen = {}
for r in rows:
    if int(r['cells']) == 0: continue
    L = emdata.Layout(r['map'])
    h = hashlib.md5(bytes(str(L.blocks), 'ascii') + L.secondary.encode()).hexdigest()
    if h in seen: out.append(dict(map=r['map'], x='', y='', group=seen[h], cells=r['cells'])); continue
    seen[h] = r['map']
    W, H = L.w, L.h
    cand = []
    for y in range(H):
        for x in range(W):
            if L.blocked(x, y): continue
            n = sum(1 for yy in range(max(0, y - 13), min(H, y + 4)) for xx in range(max(0, x - 9), min(W, x + 10)) if L.blocked(xx, yy))
            cand.append((n, x, y))
    cand.sort(reverse=True); pick = []
    for n, x, y in cand:
        if all(abs(x - px) + abs(y - py) >= 14 for _, px, py in pick): pick.append((n, x, y))
        if len(pick) >= K: break
    for n, x, y in pick: out.append(dict(map=r['map'], x=x, y=y, group=r['map'], cells=r['cells']))
w = csv.DictWriter(open('spots.csv', 'w'), fieldnames=['map', 'x', 'y', 'group', 'cells']); w.writeheader(); w.writerows(out)
print(len(out), 'rows;', len(seen), 'unique layouts')
