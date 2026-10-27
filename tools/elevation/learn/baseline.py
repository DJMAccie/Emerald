#!/usr/bin/env python3
"""baseline.py <dump with EM_NOPINS=1>: how well the pre-pin field (cartridge rating + stair platforms) matches the pins, per map.
Offset-free (the user's frame is relative per map: report error after subtracting the per-map median offset) and rank correlation."""
import sys, re, collections, statistics
rows = collections.defaultdict(list)
for l in open(sys.argv[1]):
    if l.startswith('PIN '):
        t = l.split(); m = t[1]; want = int(t[4][5:]) / 16.0; got = t[5][4:]
        kind = t[7][5:]
        if got == 'nil': continue
        rows[m].append((want, float(got) / 16.0, kind, int(t[2]), int(t[3])))
def spearman(a, b):
    def rk(v):
        o = sorted(range(len(v)), key=lambda i: v[i]); r = [0] * len(v)
        for k, i in enumerate(o): r[i] = k
        return r
    ra, rb = rk(a), rk(b); n = len(a)
    if n < 3: return float('nan')
    ma, mb = sum(ra) / n, sum(rb) / n
    num = sum((x - ma) * (y - mb) for x, y in zip(ra, rb)); den = (sum((x - ma) ** 2 for x in ra) * sum((y - mb) ** 2 for y in rb)) ** .5
    return num / den if den else float('nan')
tot = collections.Counter()
for m in sorted(rows):
    r = rows[m]; d = [w - g for w, g, *_ in r]; off = statistics.median(d); e = [x - off for x in d]
    ex = sum(abs(x) <= .5 for x in e); n = len(r)
    print('%-34s n=%3d offset %+5.1f  within 0.5 course %.2f  mean|err| %.2f  max|err| %.1f  rank corr %.2f' % (m, n, off, ex / n, sum(map(abs, e)) / n, max(map(abs, e)), spearman([w for w, *_ in r], [g for _, g, *_ in r])))
    tot['n'] += n; tot['ex'] += ex
print('ALL within 0.5 course %.2f of %d' % (tot['ex'] / tot['n'], tot['n']))
