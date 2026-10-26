#!/usr/bin/env python3
# agg_caves.py <census dirs...>  per-map cave rock cells by builder + top tiles + tileset family -> stdout table
import sys, glob, collections, csv
per = collections.defaultdict(collections.Counter); mids = collections.defaultdict(collections.Counter); skips = []
for d in sys.argv[1:]:
    for f in sorted(glob.glob(d + '/dump_*.txt')):
        for l in open(f):
            p = l.split()
            if p and p[0] == 'SKIP': skips.append(p[1]); continue
            if len(p) < 7: continue
            m, x, y, mid, b, rel, sea = p[:7]
            k = 'sea' if sea == '1' else ('relief' if rel == '1' else b)
            per[m][k] += 1; per[m]['cells'] += 1; mids[m][mid] += 1
meta = {r['map']: r for r in csv.DictReader(open('maps_caves.csv'))}
print('| map | type | family | size | rock cells | rock | dome | relief | top tiles |'); print('|---|---|---|---|---|---|---|---|---|')
for m in meta:
    c = per.get(m, collections.Counter()); r = meta[m]
    top = ' '.join('%s:%d' % kv for kv in mids[m].most_common(4))
    print('| %s | %s | %s | %sx%s | %d | %d | %d | %d | %s |' % (m, r['mapType'], r['pair'].split('__')[-1], r['w'], r['h'], c['cells'], c['rock'], c['dome'], c['relief'], top))
print('SKIPS', [s for s in skips if s not in per])
