#!/usr/bin/env python3
"""Compare two whole-map cell dumps (tools/em_cells_driver.lua output) and ignore the known unstable cells.

  heights_compare.py flips RUN1 RUN2 FLIPS      write FLIPS = cells whose line differs between two runs of the same code
  heights_compare.py diff  BASELINE NEW FLIPS   print the cells that differ and are not in FLIPS (exit 1 if any)
Dump line: MAP x y TILE KIND coll=.. prop=.. col=.. base=.. stairs=.. ... (space separated, one cell per line).
Why FLIPS: two runs of identical code differ in about 0.2% of cells (heights near map edges and a few tile
classes), so 'identical dumps' cannot be the gate by itself; a change is real when it touches a cell outside FLIPS.
Run with python3 -I.
"""
import sys, collections


def load(p):
    d = {}
    for l in open(p):
        f = l.rstrip('\n').split(' ')
        d[(f[0], int(f[1]), int(f[2]))] = f[3:]
    return d


def field_names(a, b):
    out = []
    for x, y in zip(a, b):
        if x != y:
            out.append(x.split('=')[0] if '=' in x else 'tile')
    if len(a) != len(b):
        out.append('shape')
    return out


def main():
    cmd = sys.argv[1]
    if cmd == 'flips':
        a, b = load(sys.argv[2]), load(sys.argv[3])
        flips = sorted(k for k in set(a) | set(b) if a.get(k) != b.get(k))
        with open(sys.argv[4], 'w') as f:
            for k in flips:
                f.write('%s %d %d\n' % k)
        by = collections.Counter(k[0] for k in flips)
        fields = collections.Counter(x for k in flips if k in a and k in b for x in field_names(a[k], b[k]))
        print('cells', len(a), 'unstable', len(flips), 'maps affected', len(by), dict(fields))
        for m, n in by.most_common(8):
            print('  ', m, n)
    elif cmd == 'diff':
        a, b = load(sys.argv[2]), load(sys.argv[3])
        flips = {tuple([l.split(' ')[0], int(l.split(' ')[1]), int(l.split(' ')[2])]) for l in open(sys.argv[4])}
        bad = [k for k in sorted(set(a) | set(b)) if a.get(k) != b.get(k) and k not in flips]
        by = collections.Counter(k[0] for k in bad)
        print('differing cells outside the unstable list:', len(bad), 'in', len(by), 'maps')
        for m, n in by.most_common(15):
            print('  ', m, n)
        for k in bad[:10]:
            print('   e.g.', k, a.get(k), '->', b.get(k))
        sys.exit(1 if bad else 0)


main()
