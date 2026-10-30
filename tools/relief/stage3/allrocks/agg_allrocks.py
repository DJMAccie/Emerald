#!/usr/bin/env python3
# agg_allrocks.py <census dir> [out.md]  per-map rock cells by builder (relief / rock / dome / sea) and tile class, from dump_*.txt
# line: MAP x y MID builder relief sea
import sys, glob, collections, json
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
d = sys.argv[1]
SEC = {emdata.TS_FALLARBOR: 'BROWN', emdata.TS_LAVARIDGE: 'RED'}
per = collections.defaultdict(lambda: collections.Counter())
mids = collections.defaultdict(lambda: collections.Counter())
skips = []
for f in sorted(glob.glob(d + '/dump_*.txt')):
    for l in open(f):
        p = l.split()
        if p and p[0] == 'SKIP': skips.append(l.strip()); continue
        if len(p) < 7: continue
        m, x, y, mid, b, rel, sea = p[:7]
        mid = int(mid, 16); c = per[m]
        if sea == '1': k = 'sea'
        elif rel == '1': k = 'relief'
        else: k = b          # rock (Gen3Rock courses) or dome (Gen3Mass)
        c[k] += 1; c['cells'] += 1
        mids[m][mid] += 1
sec = {}
for e in emdata.census()['maps']:
    sec[emdata.em_name(e['id'])] = e['secondaryTileset']
def cls(m, mid):
    if mid < 0x200: return 'GEN' if 0x64 <= mid <= 0xA9 else 'GENo'
    return SEC.get(sec.get(m), 'S:' + (sec.get(m) or '?')[-4:])
rows = []
for m, c in per.items():
    cl = collections.Counter()
    for mid, n in mids[m].items(): cl[cls(m, mid)] += n
    rows.append((m, c, cl))
rows.sort(key=lambda r: -(r[1]['cells'] - r[1]['relief']))
out = ['| map | cells | relief | rock | dome | sea | classes |', '|---|---|---|---|---|---|---|']
tot = collections.Counter()
for m, c, cl in rows:
    out.append('| %s | %d | %d | %d | %d | %d | %s |' % (m, c['cells'], c['relief'], c['rock'], c['dome'], c['sea'], ' '.join('%s:%d' % kv for kv in cl.most_common())))
    tot.update(c)
out.append('| TOTAL | %d | %d | %d | %d | %d | |' % (tot['cells'], tot['relief'], tot['rock'], tot['dome'], tot['sea']))
print('\n'.join(out)); print(len(skips), 'SKIP', skips[:5])
if len(sys.argv) > 2: open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
