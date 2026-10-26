#!/usr/bin/env python3
# flat_audit.py <census dir>  rock-mass cells that stand no higher than their floor (invisible rock), by map and tile
import sys, glob, collections
per = collections.defaultdict(collections.Counter); tot = collections.Counter(); n = collections.Counter()
for f in sorted(glob.glob(sys.argv[1] + '/dump_*.txt')):
    for l in open(f):
        p = l.split()
        if len(p) < 11 or p[0] == 'SKIP': continue
        m, x, y, mid, b, rel, sea, H, base, kind, coll = p[:11]
        n[m] += 1
        if H == '-' or base in ('nil', 'None'): continue
        if int(H) <= int(base) + 2: per[m][mid] += 1; tot[m] += 1
print('maps with invisible rock cells:', len(tot), 'cells', sum(tot.values()))
for m, c in tot.most_common(40): print('%-40s %4d / %4d  %s' % (m, c, n[m], ' '.join('%s:%d' % kv for kv in per[m].most_common(6))))
