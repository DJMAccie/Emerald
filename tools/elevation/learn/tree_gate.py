#!/usr/bin/env python3
"""tree_gate.py <em_cells_driver dump>...: per map, tree cells whose scene base lies outside the heights of the walkable ground round their tree cluster
(sunk = below every rim cell, floating = above every rim cell), and how many sit at a different height than the rim's most common ground."""
import sys, re, collections
cells = collections.defaultdict(dict)
for p in sys.argv[1:]:
    for l in open(p):
        t = l.split()
        if len(t) < 7 or t[0] == 'SKIP': continue
        m = re.search(r'base=(\S+)', l); c = re.search(r'coll=(\S+)', l)
        if not m or m.group(1) == 'nil': continue
        cells[t[0]][(int(t[1]), int(t[2]))] = (t[4], c.group(1) if c else None, float(m.group(1)))
tot = collections.Counter()
for m, cs in sorted(cells.items()):
    seen = set(); n = sunk = float_ = other = 0; ex = []
    for k, (kind, coll, b) in cs.items():
        if kind != 'tree' or k in seen: continue
        cl = []; st = [k]; seen.add(k)
        while st:
            a = st.pop(); cl.append(a)
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (a[0] + d[0], a[1] + d[1])
                if q not in seen and q in cs and cs[q][0] == 'tree': seen.add(q); st.append(q)
        rim = collections.Counter()
        for a in cl:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (a[0] + dx, a[1] + dy); v = cs.get(q)
                    if v and v[0] != 'tree' and v[1] == '0': rim[v[2]] += 1
        if not rim: continue
        lo, hi = min(rim), max(rim); common = rim.most_common(1)[0][0]
        for a in cl:
            if cs[a][1] == 'nil': continue   # off-map border cell: no pin, no meaning
            ba = cs[a][2]; n += 1
            if ba < lo - 2: sunk += 1; ex.append((a, ba, lo, hi, 'sunk'))
            elif ba > hi + 2: float_ += 1; ex.append((a, ba, lo, hi, 'float'))
            elif abs(ba - common) > 2: other += 1
    print('%-24s tree cells %5d  sunk %4d  floating %4d  at another rim height %4d   e.g. %s' % (m, n, sunk, float_, other, ex[:2]))
    tot['n'] += n; tot['s'] += sunk; tot['f'] += float_; tot['o'] += other
print('ALL tree cells %d sunk %d floating %d other-height %d' % (tot['n'], tot['s'], tot['f'], tot['o']))
