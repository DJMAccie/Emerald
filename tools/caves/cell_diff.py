#!/usr/bin/env python3
# cell_diff.py <dirA> <dirB>  per-map rock-cell differences (membership, builder, H, base) between two census dirs
import sys, glob, collections
def load(d):
    c = {}
    for f in glob.glob(d + '/dump_*.txt'):
        for l in open(f):
            p = l.split()
            if len(p) >= 11 and p[0] != 'SKIP': c[(p[0], int(p[1]), int(p[2]))] = tuple(p[3:11])
    return c
a, b = load(sys.argv[1]), load(sys.argv[2])
per = collections.defaultdict(collections.Counter)
for k in set(a) | set(b):
    if k not in a: per[k[0]]['added'] += 1
    elif k not in b: per[k[0]]['removed'] += 1
    elif a[k] != b[k]:
        va, vb = a[k], b[k]
        per[k[0]]['H' if va[5] != vb[5] else 'other'] += 1
print('maps changed:', len(per))
for m, c in sorted(per.items(), key=lambda kv: -sum(kv[1].values())): print('%-42s %s' % (m, dict(c)))
