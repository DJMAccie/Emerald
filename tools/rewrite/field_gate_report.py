#!/usr/bin/env python3
"""field_gate_report.py <label_dir> [<label_dir> ...]
Merges the pins/cls dumps of several field_gate.sh runs (each /tmp/<label> with pins_*.txt + cls_*.txt) and
compares them map by map with the M0 baseline (.rewrite/baseline/s4a/gates): COUNT diff, GRID cell heights,
CLS class counts. Prints one line per differing map and a final coverage/summary block."""
import sys, glob, os, collections

BASE = os.path.expanduser('~/Documents/Emerald/.rewrite/baseline/s4a/gates')
CLS_KEYS = ['PLATEAU', 'FACE', 'MASS', 'WATER', 'DECK', 'OTHER', 'rock', 'unclassified', 'faceHigh']


def load(dirs, prefix):
    grids, counts, cls = {}, {}, {}
    for d in dirs:
        for f in glob.glob(os.path.join(d, prefix + '*.txt')):
            for line in open(f):
                p = line.split()
                if not p:
                    continue
                if p[0] == 'GRID':
                    grids.setdefault(p[1], {})[int(p[2])] = p[3]
                elif p[0] == 'COUNT':
                    kv = dict(x.split('=', 1) for x in p[2:] if '=' in x)
                    counts[p[1]] = kv
                elif p[0] == 'CLS':
                    kv = dict(x.split('=', 1) for x in p[2:] if '=' in x)
                    # keep the first occurrence: baseline cls_*.txt repeat maps
                    cls.setdefault(p[1], kv)
    return grids, counts, cls


def grid_cells(a, b):
    out = []
    for y in sorted(set(a) | set(b)):
        ra, rb = a.get(y, ''), b.get(y, '')
        for x, (ca, cb) in enumerate(zip(ra, rb)):
            if ca != cb:
                out.append((x, y, ca, cb))
    return out


dirs = sys.argv[1:] or sorted(glob.glob('/tmp/p2f*')) + ['/tmp/p2e8']
dirs = [d for d in dirs if os.path.isdir(d)]
if not dirs:
    sys.exit('no label dirs')
# baseline: grids in pins_*.txt, counts in G01.txt, class counts in G02.txt
base_grids = load([BASE], 'pins_')[0]
base_counts, base_cls = {}, {}
for line in open(os.path.join(BASE, 'G01.txt')):
    p = line.split()
    if p and p[0] == 'COUNT':
        base_counts[p[1]] = dict(x.split('=', 1) for x in p[2:] if '=' in x)
for line in open(os.path.join(BASE, 'G02.txt')):
    p = line.split()
    if p and p[0] == 'CLS':
        base_cls[p[1]] = dict(x.split('=', 1) for x in p[2:] if '=' in x)

new_grids, new_counts, new_cls = load(dirs, 'pins_')[0], load(dirs, 'pins_')[1], load(dirs, 'cls_')[2]

want = set(base_counts)
have_pins = set(new_counts)
have_cls = set(new_cls)
missing = sorted(want - (have_pins & have_cls))
print('coverage: %d maps in baseline, %d with pins, %d with cls, %d missing either'
      % (len(want), len(have_pins), len(have_cls), len(missing)))
if missing:
    print('  missing:', ' '.join(missing))

bad = 0
for m in sorted(want & have_pins):
    kv = new_counts.get(m, {})
    bkv = base_counts[m]
    notes = []
    if kv.get('diff') != bkv.get('diff') or kv.get('ok') != bkv.get('ok'):
        notes.append('COUNT %s/%s -> %s/%s' % (bkv.get('ok'), bkv.get('diff'), kv.get('ok'), kv.get('diff')))
    cells = grid_cells(base_grids.get(m, {}), new_grids.get(m, {}))
    if cells:
        show = ' '.join('(%d,%d %s->%s)' % c for c in cells[:6])
        notes.append('GRID %d: %s' % (len(cells), show))
    if m in new_cls and m in base_cls:
        d = ['%s %s->%s' % (k, base_cls[m].get(k), new_cls[m].get(k)) for k in CLS_KEYS
             if base_cls[m].get(k) != new_cls[m].get(k)]
        if d:
            notes.append('CLS ' + ' '.join(d))
    if notes:
        bad += 1
        print(m, '; '.join(notes))
print('MAPS DIFFERING: %d of %d measured' % (bad, len(want & have_pins)))
