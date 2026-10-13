#!/usr/bin/env python3
"""Ortho45 sweep over every baked building: one picture per building, scored
against the original 2D art with diff.py --rect and --shift auto.

  python3 sweep.py plan   parse data/buildings/*.lua (regex, no Lua), choose a
                          walkable player cell, write plan.json and the batches
  python3 sweep.py run    run the QA batches (qa_tryp.sh, 3 at a time)
  python3 sweep.py score  check each run.log, diff each shot, write the
                          sheets, docs/ortho45/BUILDINGS.md and buildings.json

Scratch: SWEEP (plan.json, batch_NN/ QA output, diff/ scores).
Docs:    docs/ortho45/BUILDINGS.md, buildings.json, sheets/<name>.png
"""
import os, re, sys, json, glob, shutil, subprocess, time
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ref
import numpy as np
from PIL import Image

HOME = os.path.expanduser('~')
EMERALD = os.path.join(HOME, 'Documents', 'Emerald')
TOOLS = os.path.join(EMERALD, 'tools')
DIFF = os.path.join(TOOLS, 'ortho45', 'diff.py')
QA_TRYP = os.path.join(TOOLS, 'qa_tryp.sh')
DRIVER = os.path.join(TOOLS, 'em_ortho_driver.lua')
DATA = os.path.join(HOME, 'Documents', 'battle-art-notquiteog', 'data', 'buildings')
DOCS = os.path.join(EMERALD, 'docs', 'ortho45')
SHEETS = os.path.join(DOCS, 'sheets')
SWEEP = '/private/tmp/claude-501/-Users-user-Documents-Emerald/fec03359-0ca0-44c6-8339-007ace534169/scratchpad/sweep'
PLAN = os.path.join(SWEEP, 'plan.json')
DIFFDIR = os.path.join(SWEEP, 'diff')
# a batch holds at most one building per map: a second load of the same map in one QA process can come
# out blank (seen 3 times in the first sweep), so the k-th building of every map goes into batch k
RADIUS = 8             # player search radius (Manhattan) around the cell below the rect

RX = {
    'name': re.compile(r"\bname='([^']+)'"),
    'map': re.compile(r"\bmap='([^']+)'"),
    'pair': re.compile(r"\bpair='([^']+)'"),
    'rect': re.compile(r"\bx0=(-?\d+),y0=(-?\d+),x1=(-?\d+),y1=(-?\d+)"),
}

def parse_file(path):
    s = open(path, encoding='utf-8').read()
    out = {'file': os.path.basename(path)}
    for k in ('name', 'map', 'pair'):
        m = RX[k].search(s)
        out[k] = m.group(1) if m else None
    m = RX['rect'].search(s)
    out['rect'] = [int(v) for v in m.groups()] if m else None
    return out

def pick_player(m, x0, y0, x1, y1):
    bx, by = (x0 + x1) // 2, y1 + 1          # directly below the bottom row, middle column
    for R in range(0, RADIUS + 1):
        ring = [(bx + dx, by + dy) for dy in range(-R, R + 1) for dx in range(-R, R + 1)
                if abs(dx) + abs(dy) == R]
        ring.sort(key=lambda c: (c[1] < by, abs(c[0] - bx), c[1]))   # below first, then nearest column
        for x, y in ring:
            if 0 <= x < m['W'] and 0 <= y < m['H'] and int(m['coll'][y, x]) == 0:
                return x, y, R
    return None

def cmd_plan():
    t0 = time.time()
    # index.lua is the list of buildings, not a building: the 122 others are swept
    files = sorted(f for f in glob.glob(os.path.join(DATA, '*.lua')) if os.path.basename(f) != 'index.lua')
    entries, seen_names = [], {}
    for path in files:
        e = parse_file(path)
        e['status'] = 'pending'
        if not (e['name'] and e['map'] and e['pair'] and e['rect']):
            e['status'] = 'failed'; e['reason'] = 'could not parse name/map/pair/rect'
            entries.append(e); continue
        if e['name'] in seen_names:
            raise SystemExit('duplicate name %s (%s, %s)' % (e['name'], seen_names[e['name']], e['file']))
        seen_names[e['name']] = e['file']
        x0, y0, x1, y1 = e['rect']
        e['centre'] = [(x0 + x1) // 2, (y0 + y1) // 2]
        try:
            m = ref.load_map(e['map'], pair=e['pair'])
        except SystemExit as err:
            e['status'] = 'failed'; e['reason'] = 'map load: %s' % err
            entries.append(e); continue
        pc = pick_player(m, x0, y0, x1, y1)
        if pc is None:
            e['status'] = 'failed'; e['reason'] = 'no walkable player cell within %d cells' % RADIUS
        else:
            e['player'] = [pc[0], pc[1]]; e['player_radius'] = pc[2]
        entries.append(e)
    ok = [e for e in entries if e['status'] == 'pending']
    ok.sort(key=lambda e: (e['map'], e['name']))
    keys = [(e['map'], e['centre'][0], e['centre'][1]) for e in ok]
    if len(set(keys)) != len(keys):
        raise SystemExit('two buildings share a map and centre cell: the shot and diff names would clash')
    per_map = {}
    for e in ok:
        per_map[e['map']] = per_map.get(e['map'], 0) + 1
        e['batch'] = per_map[e['map']]
        e['shot'] = '%s_%d_%d_ortho.png' % (e['map'], e['centre'][0], e['centre'][1])
    os.makedirs(SWEEP, exist_ok=True)
    json.dump({'entries': entries, 'planned_s': round(time.time() - t0, 2)},
              open(PLAN, 'w'), indent=1)
    for b in sorted({e['batch'] for e in ok}):
        bd = os.path.join(SWEEP, 'batch_%02d' % b)
        os.makedirs(bd, exist_ok=True)
        cases = ','.join("{'%s',%d,%d,%d,%d}" % (e['map'], e['player'][0], e['player'][1],
                                                  e['centre'][0], e['centre'][1])
                         for e in ok if e['batch'] == b)
        open(os.path.join(bd, 'cases.txt'), 'w').write(cases + '\n')
    print('plan: %d files, %d planned in %d batches, %d failed at plan time'
          % (len(files), len(ok), len({e['batch'] for e in ok}), len(entries) - len(ok)))
    for e in entries:
        if e['status'] == 'failed':
            print('  FAILED', e['file'], e.get('reason'))
    radius = [e['player_radius'] for e in ok]
    print('player radius: max %d, cells not directly below: %d' % (max(radius or [0]), sum(1 for r in radius if r)))

def load_plan():
    return json.load(open(PLAN))

def cmd_run():
    plan = load_plan()
    batches = sorted({e['batch'] for e in plan['entries'] if e['status'] == 'pending'})
    env = dict(os.environ, EM_DRIVER=DRIVER)
    t0 = time.time()
    def job(b):
        bd = os.path.join(SWEEP, 'batch_%02d' % b)
        cases = open(os.path.join(bd, 'cases.txt')).read().strip()
        t = time.time()
        with open(os.path.join(bd, 'qa_stdout.txt'), 'w') as fo:
            # 150 frames per case (qa_run's EM_WAIT): at 60 some shots were taken before the map's geometry was built
            r = subprocess.run([QA_TRYP, 'Voxel3D.lua', bd, cases, '4', '0', '150'], env=env,
                               stdout=fo, stderr=subprocess.STDOUT)
        return b, r.returncode, round(time.time() - t, 1)
    with ThreadPoolExecutor(max_workers=3) as ex:
        for b, rc, secs in ex.map(job, batches):
            last = open(os.path.join(SWEEP, 'batch_%02d' % b, 'qa_stdout.txt')).read().strip().splitlines()
            print('batch %02d rc %d %ss: %s' % (b, rc, secs, last[-1] if last else '(no output)'), flush=True)
    print('run wall time %.1f s' % (time.time() - t0))

# Lua print() separates arguments with tabs; string.format lines use spaces
RE_LOAD = re.compile(r'\[EM view\]\s+load\s+(\S+)\s+(true|false)(.*)')
RE_ORTHO = re.compile(r'\[EM ortho\] (\S+) (\d+) (\d+) view (\d+) (\d+) ')
RE_ACTIVE = re.compile(r'\[EM view\]\s+(\S+)\s+level\s+(\d+)\s+active\s+(\S+)\s+rendered')

def check_batch(b, todo):
    """Per-case result of one batch from its run.log: dict shot -> reason or None."""
    bd = os.path.join(SWEEP, 'batch_%02d' % b)
    lines = open(os.path.join(bd, 'run.log'), errors='replace').read().splitlines() if os.path.exists(os.path.join(bd, 'run.log')) else []
    segs = []
    for ln in lines:
        m = RE_LOAD.search(ln)
        if m:
            segs.append({'map': m.group(1), 'ok': m.group(2) == 'true', 'err': m.group(3).strip(), 'lines': []})
            continue
        if segs:
            segs[-1]['lines'].append(ln)
    res = {}
    if len(segs) != len(todo):
        for e in todo:
            res[e['shot']] = 'run.log has %d load lines for %d cases' % (len(segs), len(todo))
        return res
    for e, sg in zip(todo, segs):
        if sg['map'] != e['map']:
            res[e['shot']] = 'log order mismatch: %s' % sg['map']; continue
        if not sg['ok']:
            res[e['shot']] = 'load failed: %s' % sg['err']; continue
        act = [RE_ACTIVE.search(x) for x in sg['lines']]
        act = [a for a in act if a]
        if not act or act[-1].group(3) != 'true':
            res[e['shot']] = 'active %s' % (act[-1].group(3) if act else 'missing'); continue
        orth = [RE_ORTHO.search(x) for x in sg['lines']]
        orth = [o for o in orth if o]
        if not orth or (int(orth[-1].group(4)), int(orth[-1].group(5))) != tuple(e['centre']):
            res[e['shot']] = 'ortho view line missing or not the centre cell'; continue
        fb = sum(1 for x in sg['lines'] if 'fallback' in x)
        if fb:
            res[e['shot']] = 'fallback %d' % fb; continue
        if not os.path.exists(os.path.join(bd, e['shot'])):
            res[e['shot']] = 'no shot file'; continue
        if len(np.unique(np.asarray(Image.open(os.path.join(bd, e['shot'])).convert('RGB')).reshape(-1, 3), axis=0)) < 8:
            res[e['shot']] = 'blank or unfinished capture (fewer than 8 colours)'; continue
        res[e['shot']] = None
    return res

def cmd_score():
    t0 = time.time()
    plan = load_plan()
    ents = plan['entries']
    os.makedirs(DIFFDIR, exist_ok=True)
    os.makedirs(SHEETS, exist_ok=True)
    for f in glob.glob(os.path.join(SHEETS, '*.png')):
        os.remove(f)
    checks = {}
    for b in sorted({e['batch'] for e in ents if e['status'] == 'pending'}):
        # the same order as the batch's cases.txt (plan sorts by map, then name)
        todo = sorted([e for e in ents if e['status'] == 'pending' and e['batch'] == b],
                      key=lambda e: (e['map'], e['name']))
        # the batch's last stdout line carries the script's own fallback count
        last = open(os.path.join(SWEEP, 'batch_%02d' % b, 'qa_stdout.txt')).read().strip().splitlines()
        tail = last[-1] if last else ''
        checks.update(check_batch(b, todo))
        print('batch %02d: %s' % (b, tail))
    for e in ents:
        if e['status'] != 'pending':
            continue
        reason = checks.get(e['shot'], 'not run')
        if reason is not None:
            e['status'] = 'failed'; e['reason'] = reason
            print('  FAILED', e['name'], reason); continue
        shot = os.path.join(SWEEP, 'batch_%02d' % e['batch'], e['shot'])
        x0, y0, x1, y1 = e['rect']
        r = subprocess.run(['python3', DIFF, e['map'], str(e['centre'][0]), str(e['centre'][1]), shot,
                            DIFFDIR, '--rect', '%d,%d,%d,%d' % (x0, y0, x1, y1), '--shift', 'auto',
                            '--pair', e['pair'], '--mask', 'building'], capture_output=True, text=True)
        if r.returncode != 0:
            e['status'] = 'failed'; e['reason'] = 'diff.py: ' + r.stderr.strip().splitlines()[-1]
            print('  FAILED', e['name'], e['reason']); continue
        d = json.load(open(os.path.join(DIFFDIR, '%s_%d_%d_diff.json' % (e['map'], e['centre'][0], e['centre'][1]))))
        e['status'] = 'scored'
        for k in ('rect_differ', 'rect_of', 'rect_percent', 'rect_percent_all', 'rect_differ_all', 'rect_of_all',
                  'mask_px', 'rect_px', 'above_differ', 'above_of', 'percent', 'pixels_differ', 'pixels_compared'):
            e[k] = d[k]
        e['shift'] = d['shift']
        e['sheet'] = 'sheets/%s.png' % e['name']
        shutil.copy(os.path.join(DIFFDIR, '%s_%d_%d_cmp.png' % (e['map'], e['centre'][0], e['centre'][1])),
                    os.path.join(SHEETS, e['name'] + '.png'))
        # window clipping: rect cells outside the 1280x720 window (640x360 map px at 2x)
        cx0, cy0 = e['centre'][0] * 16 + 8, e['centre'][1] * 16 + 8
        e['clipped'] = bool(x0 * 16 < cx0 - 320 or x1 * 16 + 16 > cx0 + 320 or
                            y0 * 16 < cy0 - 180 or y1 * 16 + 16 > cy0 + 180)
    scored = [e for e in ents if e['status'] == 'scored']
    failed = [e for e in ents if e['status'] == 'failed']
    scored.sort(key=lambda e: (-e['rect_percent'], e['name']))
    failed.sort(key=lambda e: e['name'])
    order = scored + failed
    for i, e in enumerate(order):
        e['rank'] = i + 1
    json.dump({'entries': order}, open(os.path.join(DOCS, 'buildings.json'), 'w'), indent=1)
    write_md(order)
    print('scored %d, failed %d, wall %.1f s' % (len(scored), len(failed), time.time() - t0))

def bucket(p):
    if p < 2: return 'under 2%'
    if p < 10: return '2-10%'
    if p <= 30: return '10-30%'
    return 'over 30%'

def write_md(order):
    scored = [e for e in order if e['status'] == 'scored']
    failed = [e for e in order if e['status'] == 'failed']
    L = []
    L.append('# Buildings vs the original 2D art (ortho45)\n')
    L.append('One picture per building: the 3D scene from the ortho45 camera (1280x720, 2 px per map px), '
             'centred on the rectangle centre cell, player on the walkable cell below the rectangle. '
             'Scored by `tools/ortho45/diff.py --rect <rect> --shift auto --mask building` (tol 12). '
             'MASK: only BUILDING pixels count. `ref.building_mask` takes the original art only: the ring of cells '
             '2 cells around the rectangle gives the ground metatiles; a rectangle pixel equal to the same in-cell pixel '
             'of one of them is ground (water, paving, terrain), the rest is building; one hole-closing pass '
             '(a ground pixel with 6+ building neighbours becomes building). '
             '`masked %` = differing building pixels / building pixels in the rectangle (the scored number, sorted by it). '
             '`all px %` = the same over every pixel of the rectangle, as before the mask. '
             '`mask px` = building map px / rectangle map px. '
             '`above_differ` = differing pixels in the 3 cell rows directly above the rectangle, same columns (unmasked). '
             'Sheets are the cropped cmp strips: reference (cyan = mask border) | shot | reference dimmed with differing '
             'building pixels in magenta.\n')
    L.append('Sorted worst first. Sheet paths are relative to docs/ortho45/. The data folder holds 122 building '
             'files plus index.lua (the list, not a building); the 122 are all here.\n')
    L.append('| # | name | map | rect | masked % | all px % | mask px | above_differ | shift | sheet |')
    L.append('|---|---|---|---|---|---|---|---|---|---|')
    for e in order:
        rect = '%d,%d,%d,%d' % tuple(e['rect'])
        if e['status'] == 'scored':
            L.append('| %d | %s | %s | %s | %.3f | %.3f | %.1f%% | %d | %d,%d | %s |' % (
                e['rank'], e['name'], e['map'], rect, e['rect_percent'], e['rect_percent_all'],
                100.0 * e['mask_px'] / max(1, e['rect_px']), e['above_differ'],
                e['shift'][0], e['shift'][1], e['sheet']))
        else:
            L.append('| %d | %s | %s | %s | FAILED: %s | - | - | - | - | - |' % (
                e['rank'], e['name'], e['map'], rect, e.get('reason', '?')))
    L.append('')
    L.append('## Counts (rect_percent)\n')
    L.append('| bucket | buildings |')
    L.append('|---|---|')
    for b in ('under 2%', '2-10%', '10-30%', 'over 30%'):
        L.append('| %s | %d |' % (b, sum(1 for e in scored if bucket(e['rect_percent']) == b)))
    L.append('| failed | %d |' % len(failed))
    L.append('| total | %d |' % len(order))
    L.append('')
    L.append('Buckets (masked %): under 2% is < 2; 2-10% is 2 to < 10; 10-30% is 10 to 30; over 30% is > 30.\n')
    os.makedirs(DOCS, exist_ok=True)
    open(os.path.join(DOCS, 'BUILDINGS.md'), 'w').write('\n'.join(L) + '\n')

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    if cmd == 'plan': cmd_plan()
    elif cmd == 'run': cmd_run()
    elif cmd == 'score': cmd_score()
    else: raise SystemExit(__doc__)

if __name__ == '__main__':
    main()
