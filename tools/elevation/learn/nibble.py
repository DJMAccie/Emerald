#!/usr/bin/env python3
"""nibble.py: pins vs the cartridge's elevation nibble (uncapped), per map: want ~ a*(elev-3) + b on pins that sit on walkable cells with elev >= 3 (water 0)."""
import sys, glob, os, collections, statistics
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
PD = '/Users/user/Documents/Emerald/docs/elevation/pins/'
def pins(m):
    out = []
    for l in open(PD + m + '.txt'):
        t = l.split('#')[0].split()
        if len(t) >= 3 and t[2].lstrip('-').isdigit(): out.append((int(t[0]), int(t[1]), int(t[2]), len(t) > 3 and t[3] == 'top'))
    return out
tot = collections.Counter()
for f in sorted(glob.glob(PD + 'EM_*.txt')):
    m = os.path.basename(f)[:-4]
    if m.endswith('_proposed'): continue
    L = emdata.Layout(m); pts = []
    for x, y, h, top in pins(m):
        if L.blocked(x, y) or L.role_at(x, y) == 'water': continue
        e = L.elevation(x, y)
        if e >= 3 and e != 15: pts.append((e - 3, h, x, y))
    if len(pts) < 3: print('%-34s only %d walkable pins' % (m, len(pts))); continue
    d = [h - e for e, h, *_ in pts]; off = statistics.median(d)
    ex = sum(abs(x - off) <= .5 for x in d)
    # also: how many distinct nibble values, and agreement of order
    levels = collections.defaultdict(list)
    for e, h, *_ in pts: levels[e].append(h)
    print('%-34s n=%3d offset %+4.1f  nibble-exact (after offset) %.2f   per nibble: %s' % (m, len(pts), off, ex / len(pts), ' '.join('e%d:%s' % (k + 3, '/'.join(map(str, sorted(set(v))))) for k, v in sorted(levels.items()))))
    tot['n'] += len(pts); tot['ex'] += ex
print('ALL', tot['ex'] / tot['n'], tot['n'])
