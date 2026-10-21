#!/usr/bin/env python3
"""analyze_census.py <census.txt ...>   per map: cells by tree path (F rows), foliage cells no tree path claimed, and E->F class changes.
rows (tools/em_trees_driver.lua): stage map cx cy pair mid coll kind path gU gO base"""
import sys, collections
paths = collections.defaultdict(lambda: collections.Counter())
unclaimed = collections.defaultdict(collections.Counter)
early, full = {}, {}
for fn in sys.argv[1:]:
    for l in open(fn):
        p = l.split()
        if len(p) < 11: continue
        st, m, cx, cy, pair, mid, coll, kind, path, gu, go = p[:11]
        key = (m, int(cx), int(cy))
        if st == 'E': early[key] = (path, kind, pair, mid)
        elif st == 'F':
            full[key] = (path, kind, pair, mid)
            paths[m][path] += 1
            # plain grass tiles (0x001/0x00D) are walkable and green: only blocked cells (coll 7) can be an unclaimed tree
            if path == '-' and coll == '7' and mid not in ('001', '00D') and (float(gu) >= .30 or float(go) >= .30):
                unclaimed[m][(pair, mid, kind, coll)] += 1
print('== cells by tree path (full build) ==')
for m in sorted(paths):
    print(m, dict(paths[m].most_common()))
print('\n== blocked (coll 7) foliage-looking cells (green share >= .30, not plain grass) no tree path claimed: map -> (pair mid kind coll): n ==')
for m in sorted(unclaimed):
    top = unclaimed[m].most_common(6)
    print(m, sum(unclaimed[m].values()), ' | '.join('%s %s %s c%s:%d' % (k[0].replace('general__', 'g_'), k[1], k[2], k[3], n) for k, n in top))
print('\n== class changes between the first-area build (E) and the full build (F), cells in both ==')
ch = collections.defaultdict(collections.Counter)
same = collections.Counter()
for key, e in early.items():
    f = full.get(key)
    if f is None: continue
    if e[0] != f[0]: ch[key[0]][(e[0], f[0])] += 1
    else: same[key[0]] += 1
for m in sorted(set(ch) | set(same)):
    print(m, 'same', same[m], 'changed', sum(ch[m].values()), dict(ch[m].most_common(5)))
