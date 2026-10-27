#!/usr/bin/env python3
"""score_proposed.py: the _proposed.txt files (made before the user drew those maps) against the user's pins of the same map, per area.
A proposal counts for an area when the user pinned a walkable/water cell of the same area (node of tools/elevation/learn/proposer.py)."""
import sys, os, glob, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proposer as P
tot = collections.Counter(); rows = []
for f in sorted(glob.glob(P.PD + 'EM_*_proposed.txt')):
    m = os.path.basename(f)[:-len('_proposed.txt')]
    if not os.path.exists(P.PD + m + '.txt'): continue
    g = P.G(m); res = []
    for l in open(f):
        t = l.split('#')[0].split()
        if len(t) < 3: continue
        k = g.node.get((int(t[0]), int(t[1])))
        if k in g.truth: res.append((float(t[2]), g.truth[k], len(t) > 3 and t[3] == '?'))
    if not res: continue
    e = [abs(p - u) for p, u, _ in res]; ex = sum(x <= .5 for x in e)
    ec = [abs(p - u) for p, u, un in res if not un]; eu = [abs(p - u) for p, u, un in res if un]
    rows.append((m, len(res), ex / len(res), sum(e) / len(e), len(ec), (sum(x <= .5 for x in ec) / len(ec)) if ec else float('nan'), len(eu), (sum(x <= .5 for x in eu) / len(eu)) if eu else float('nan'), max(u for _, u, _ in res)))
    tot['n'] += len(res); tot['ex'] += ex; tot['abs'] += sum(e); tot['nc'] += len(ec); tot['exc'] += sum(x <= .5 for x in ec); tot['nu'] += len(eu); tot['exu'] += sum(x <= .5 for x in eu)
    tot['w1'] += sum(x <= 1 for x in e)
for r in rows: print('%-28s areas %3d  within .5: %.2f  mean|err| %.2f  | confident %3d -> %.2f | unsure %3d -> %.2f | user max height %g' % r)
print('ALL areas %d  within .5: %.2f  within 1: %.2f  mean|err| %.2f | confident %d -> %.2f | unsure %d -> %.2f' % (tot['n'], tot['ex'] / tot['n'], tot['w1'] / tot['n'], tot['abs'] / tot['n'], tot['nc'], tot['exc'] / max(tot['nc'], 1), tot['nu'], tot['exu'] / max(tot['nu'], 1)))
