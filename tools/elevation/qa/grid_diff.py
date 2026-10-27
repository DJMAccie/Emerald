#!/usr/bin/env python3
"""grid_diff.py <dirA> <dirB> [max_list]: per map, cells whose GRID height char differs between the pins_*.txt dumps
of two pins_gate.sh labels; prints `MAP n_changed (x,y a->b ...)` and a total. Chars = height in half courses (base 36)."""
import sys, glob, os, collections
def load(d):
    g = collections.defaultdict(dict)
    for f in glob.glob(os.path.join(d, 'pins_*.txt')):
        for line in open(f):
            p = line.split()
            if p and p[0] == 'GRID': g[p[1]][int(p[2])] = p[3]
    return g
a, b = load(sys.argv[1]), load(sys.argv[2]); n = int(sys.argv[3]) if len(sys.argv) > 3 else 6
total = 0
for m in sorted(set(a) | set(b)):
    if m not in a or m not in b: print(m, 'MISSING in', 'A' if m not in a else 'B'); continue
    ch = []
    for y in sorted(a[m]):
        ra, rb = a[m][y], b[m].get(y, '')
        for x, (ca, cb) in enumerate(zip(ra, rb)):
            if ca != cb: ch.append('(%d,%d %s->%s)' % (x, y, ca, cb))
    total += len(ch)
    if ch: print(m, len(ch), ' '.join(ch[:n]))
print('TOTAL changed cells', total)
