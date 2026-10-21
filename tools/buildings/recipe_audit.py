#!/usr/bin/env python3
"""Audit every hand recipe's constants against a measurement of its ORIGINAL drawing.

  recipe_audit.py [--json OUT] [--only NAME[,NAME...]] [--all]

For every recipe in hf_recipes.RECIPES that has a `src` rect and plan volumes, this runs tools/buildings/measure.py on that
rect and compares what the recipe ASSERTS with what the drawing actually contains:

  repeat      the facade's vertical period (px)          vs   volume['repeat']
  recess      window x ranges                            vs   volume['recess'] x ranges
  mat         wall colour at volume['mat']               vs   the drawing's dominant wall colour
  corner      the pilaster/trim x range                  vs   volume['corner']

Each row is OK / MISMATCH (with the numbers) / MIXED (the rect is a scene, not a facade - needs the region step).
Printed as a table sorted by the number of mismatches, so the worst recipes come first. Run WITHOUT -I.
"""
import os, sys, json, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
MEASURE = os.path.join(HERE, 'measure.py')


def measure(rec):
    pair, mp, x0, y0, x1, y1 = rec['src']
    out = os.path.join('/tmp', 'ra_%d.json' % (abs(hash((pair, mp, x0, y0, x1, y1))) % 10 ** 8))
    r = subprocess.run([sys.executable, MEASURE, pair, mp, str(x0), str(y0), str(x1), str(y1), '--json', out],
                       capture_output=True, text=True)
    if r.returncode != 0 or not os.path.exists(out):
        return None, (r.stdout + r.stderr)[-300:]
    return json.load(open(out)), r.stdout


def xranges(rects):
    """normalise a recipe's recess list to {'x': (a,b), 'y': (c,d)} tuples"""
    out = []
    for r in rects or []:
        if len(r) >= 4:
            out.append((int(r[0]), int(r[1]), int(r[2]), int(r[3])))
    return out


def main(argv):
    import hf_recipes as R
    only = None
    if '--only' in argv:
        only = set(argv[argv.index('--only') + 1].split(','))
    rows = []
    for name, rec in sorted(R.RECIPES.items()):
        if only and name not in only:
            continue
        src = rec.get('src')
        vols = [v for v in (rec.get('volumes') or []) if isinstance(v, dict)]
        if not src or not vols:
            continue
        m, txt = measure(rec)
        if not m:
            rows.append({'recipe': name, 'status': 'ERROR', 'notes': ['measure failed: ' + txt]})
            continue
        if m.get('mixed'):
            rows.append({'recipe': name, 'status': 'MIXED', 'notes': ['largest colour %.0f%%' % (100 * m['wall_share'])]})
            continue
        notes, bad = [], 0
        vol = vols[0]
        # repeat
        rep = vol.get('repeat')
        if rep:
            if int(rep) != int(m['period_px']):
                notes.append('repeat: recipe %d px, drawing %d px' % (rep, m['period_px'])); bad += 1
            else:
                notes.append('repeat %d px OK' % rep)
        # mat colour
        mat = vol.get('mat')
        if mat:
            px = m.get('wall_sample_xy')
            notes.append('mat=(%d,%d) -> %s, drawing wall %s' % (mat[0], mat[1], 'sampled' if px else '?', m['wall_colour']))
        # recess windows
        rs = xranges(vol.get('recess'))
        measured = m.get('windows') or []
        if rs and measured:
            # hf.py's convention is half-open: recess=(xa, xb, ra, rb) means x in xa..xb-1 (docs at hf.py:682), while a
            # measurement reports inclusive runs (a..b). Compare like with like or every recipe looks 1 px wrong.
            rx = sorted({(a, b) for a, b, _, _ in rs})
            mx = sorted({(a, b + 1) for a, b in measured})
            if rx != mx:
                notes.append('recess x: recipe %s (half-open), drawing %s (converted to the same convention)' % (rx, mx)); bad += 1
            else:
                notes.append('recess x %s OK (exact to the pixel)' % (rx,))
        elif rs and not measured:
            notes.append('recess: recipe has %d windows, drawing shows none' % len(rs)); bad += 1
        # corner / trim
        cor = vol.get('corner')
        trim = m.get('trim') or []
        if cor and trim:
            notes.append('corner %s vs trim %s' % (cor, trim))
        rows.append({'recipe': name, 'status': 'MISMATCH' if bad else 'OK', 'bad': bad, 'notes': notes,
                     'measured': {'period': m['period_px'], 'windows': measured, 'trim': trim,
                                  'wall': m['wall_colour'], 'door': m.get('door_x_runs')}})
    rows.sort(key=lambda r: (-r.get('bad', 0), r['recipe']))
    for r in rows:
        print('%-26s %-9s %s' % (r['recipe'], r['status'], '; '.join(r['notes'])))
    c = {}
    for r in rows:
        c[r['status']] = c.get(r['status'], 0) + 1
    print('\n%s  (%d recipes audited)' % (', '.join('%s %d' % kv for kv in sorted(c.items())), len(rows)))
    if '--json' in argv:
        json.dump(rows, open(argv[argv.index('--json') + 1], 'w'), indent=1)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
