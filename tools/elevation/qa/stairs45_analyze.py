#!/usr/bin/env python3
"""stairs45_analyze.py <dir-with-st_*.txt> [--list]
Summarise em_stairs45_driver.lua dumps (FLIGHT lines, columns and rows) against R-34.
Per run: n tiles, R = hi - lo (px) of the floors at the two ends, cells ordered from the LOWER end.
  steep      R > 16 n + .25 (more than one course per tile)
  flat       R < .25 (equal pins: a flat deck; every cell must be low == high == lo)
  foot riser lowest cell's low minus the lower floor lo (R-34: 0 for a climbing run)
  bad        a climbing run whose cells do not rise evenly from lo to hi (profile mismatch)
"""
import sys, glob, collections
d = sys.argv[1]; lst = '--list' in sys.argv
runs = []
for fn in sorted(glob.glob(d + '/st_*.txt')):
    for line in open(fn):
        if not line.startswith('FLIGHT '): continue
        p = line.split()
        mp, axis, x, y, n = p[1], p[2], int(p[3]), int(p[4]), int(p[5])
        kv = dict(t.split('=', 1) for t in p[6:9])
        cells = []
        for c in line.split('cells=')[1].strip().split(','):
            lo_, hi_, mid, ext = c.split('/')
            cells.append((None if lo_ == 'nil' else float(lo_), None if hi_ == 'nil' else float(hi_), mid, ext == 'e'))
        def num(v): return None if v == 'nil' else float(v)
        runs.append(dict(map=mp, axis=axis, x=x, y=y, n=n, lo=num(kv['lo']), hi=num(kv['hi']), climbs=kv['climbs'] == 'true', cells=cells, ext=sum(1 for c in cells if c[3])))
cat = collections.Counter(); foot = collections.Counter(); per = collections.Counter(); bad = []; steep = []; noend = []
for r in runs:
    lo, hi, n = r['lo'], r['hi'], r['n']
    if lo is None or hi is None:
        cat['no end floor'] += 1; noend.append(r); continue
    R = hi - lo
    per[r['axis']] += 1
    if R < .25:
        ok = all(c[0] is not None and abs(c[0] - lo) < .25 and abs(c[1] - lo) < .25 for c in r['cells'])
        cat['flat'] += 1
        if not ok: bad.append((r, 'flat run not flat'))
        continue
    rise = R / n
    cat['climb'] += 1
    if rise > 16.25:
        cat['STEEP (>45 deg)'] += 1; steep.append(r)
    c0 = r['cells'][0]
    if c0[0] is None: bad.append((r, 'no profile')); continue
    fr = round(c0[0] - lo, 1); foot[fr] += 1
    # even profile: cell k low = lo + R (k-1)/n, high = lo + R k/n
    for k, c in enumerate(r['cells']):
        if c[0] is None or abs(c[0] - (lo + R * k / n)) > .3 or abs(c[1] - (lo + R * (k + 1) / n)) > .3:
            bad.append((r, 'cell %d %s expected %.1f/%.1f' % (k, c[:2], lo + R * k / n, lo + R * (k + 1) / n))); break
    if not r['climbs'] and r['cells'][0][0] is not None:
        pass
print('runs %d  (columns %d, rows %d)' % (len(runs), per['v'], per['h']))
for k, v in cat.items(): print('  %-18s %d' % (k, v))
print('rise per tile of climbing runs (px):', dict(sorted(collections.Counter(round((r['hi'] - r['lo']) / r['n'], 1) for r in runs if r['lo'] is not None and r['hi'] is not None and r['hi'] - r['lo'] >= .25).items())))
print('FOOT RISER (lowest cell low - lower floor, climbing runs):', dict(sorted(foot.items())))
print('extension cells: %d in %d runs' % (sum(r['ext'] for r in runs), sum(1 for r in runs if r['ext'])))
print('profile mismatches (not an even rise lo->hi):', len(bad))
south = [r for r in runs if r['lo'] is not None and r['hi'] is not None and r['hi'] - r['lo'] >= .25 and r['climbs']]
print('runs the player climbs (stairUp set):', len(south))
if lst or True:
    print('\n== STEEP'); [print(' ', r['map'], r['axis'], r['x'], r['y'], 'n=%d R=%.1f' % (r['n'], r['hi'] - r['lo']), 'ext=%d' % r['ext']) for r in steep]
    print('== MISMATCH'); [print(' ', r['map'], r['axis'], r['x'], r['y'], 'n=%d lo=%s hi=%s' % (r['n'], r['lo'], r['hi']), why) for r, why in bad[:60]]
    print('== NO END FLOOR (old profile kept)'); [print(' ', r['map'], r['axis'], r['x'], r['y'], 'n=%d' % r['n'], 'lo=%s hi=%s' % (r['lo'], r['hi'])) for r in noend[:40]]
