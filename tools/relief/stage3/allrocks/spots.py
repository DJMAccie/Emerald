#!/usr/bin/env python3
# spots.py  clusters1 + game1 -> spots.csv: per map the clusters that hold its non-relief, non-sea rock cells (max 3), or the biggest cluster for fully-relief maps
import glob, collections, csv
cells = collections.defaultdict(dict)   # map -> {(x,y): kind}
for f in glob.glob('game1/dump_*.txt'):
    for l in open(f):
        p = l.split()
        if len(p) < 7: continue
        m, x, y, mid, b, rel, sea = p[:7]
        cells[m][(int(x), int(y))] = 'sea' if sea == '1' else ('relief' if rel == '1' else b)
rows = collections.defaultdict(list)
for f in glob.glob('clusters1/dump_*.txt'):
    for l in open(f):
        p = l.split()
        if len(p) < 11: continue
        m, i, b, n, x0, y0, x1, y1, sx, sy, mids = p[:11]
        if b not in ('rock', 'dome'): continue
        x0, y0, x1, y1 = map(int, (x0, y0, x1, y1))
        c = collections.Counter(k for (x, y), k in cells[m].items() if x0 <= x <= x1 and y0 <= y <= y1)
        bad = c['rock'] + c['dome']
        rows[m].append(dict(map=m, cl=int(i), builder=b, n=int(n), bad=bad, relief=c['relief'], sea=c['sea'], x0=x0, y0=y0, x1=x1, y1=y1, sx=int(sx), sy=int(sy), mids=mids))
out = []
for m, rs in sorted(rows.items()):
    tot = sum(r['bad'] for r in rs)
    rs.sort(key=lambda r: (-r['bad'], -r['n']))
    pick = []
    if tot == 0:
        pick = sorted(rs, key=lambda r: -r['n'])[:1]
    else:
        acc = 0
        for r in rs:
            if r['bad'] < 6 and pick: break
            pick.append(r); acc += r['bad']
            if len(pick) == 3 or acc >= .8 * tot: break
    for r in pick:
        if r['sx'] < 0: continue
        out.append(r)
w = csv.DictWriter(open('spots.csv', 'w'), fieldnames=list(out[0].keys())); w.writeheader(); w.writerows(out)
print(len(out), 'spots on', len(set(r['map'] for r in out)), 'maps;', len(rows), 'maps with clusters')
miss = [m for m in cells if m not in rows]; print('maps with cells but no cluster:', miss)
