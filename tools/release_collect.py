#!/usr/bin/env python3
"""Helper of tools/release_check.sh: splits the map list into batches, then reads every gate's output into
results.json / results.md. Run with plain python3 (PIL lives in the user site, which -I hides).

  release_collect.py batches OUT NAME COUNT [--outdoor-only] [--warmup]   create OUT/NAME/bNN/maps.txt, print the dirs
  release_collect.py finish OUT                                            parse the gates that ran -> results.json, results.md, sheets/

results.json schema 1: {run_id, date, scope 'full'|'subset', maps, mod_hash, gates:{id:{status, target, metrics, per_map?,
details?, source}}, not_scripted:[..]}. status: pass | fail | info | incomplete | skipped.
"""
import sys, os, re, json, glob, statistics, subprocess, datetime, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
OUTDOOR = ('town_city', 'route', 'water_route')


def read_maps(p):
    rows = []
    for l in open(p):
        f = l.split()
        if len(f) >= 3:
            rows.append((f[0], int(f[1]), int(f[2])))
    return rows


def outdoor_ids():
    m = json.load(open(os.path.join(ROOT, 'docs', 'ledger', 'maps.json')))
    return {x['id'] for x in m if x['kind'] in OUTDOOR}


def cmd_batches(out, name, count, flags):
    maps = read_maps(os.path.join(out, 'maps.txt'))
    if '--outdoor-only' in flags:
        o = outdoor_ids()
        maps = [m for m in maps if m[0] in o]
    warm = maps[0] if maps else None
    n = int(count)
    chunks = [maps[i:i + n] for i in range(0, len(maps), n)] or [[]]
    for i, ch in enumerate(chunks):
        d = os.path.join(out, name, 'b%02d' % i)
        os.makedirs(d, exist_ok=True)
        if '--warmup' in flags and warm:
            ch = [warm] + ch      # the first map is entered twice; the collector drops the first result
        with open(os.path.join(d, 'maps.txt'), 'w') as f:
            for m in ch:
                f.write('%s %d %d\n' % m)
        print(d)


def batch_dirs(out, name):
    return sorted(glob.glob(os.path.join(out, name, 'b*')))


def log_of(d):
    p = os.path.join(d, 'out', 'run.log')
    return open(p, errors='replace').read().splitlines() if os.path.exists(p) else []


ERR = re.compile(r'(^|\s)Error\b|lua:\d+:|stack traceback|\[EM view\] load \S+ false|attempt to ')


def scan_views(dirs, levels=2):
    """fallbacks and Lua errors attributed to the map being loaded; shots and missing maps"""
    res = dict(shots=0, expected=0, fallbacks=0, lua_errors=0, watchdogs=0, missing=[])
    per = collections.defaultdict(lambda: {'fallbacks': 0, 'lua_errors': 0})
    examples = []
    for d in dirs:
        maps = [m[0] for m in read_maps(os.path.join(d, 'maps.txt'))]
        lines = log_of(d)
        cur = None
        for l in lines:
            m = re.match(r'\[EM view\] load (\S+)', l)
            if m:
                cur = m.group(1)
            if 'fallback' in l and not l.startswith('[qa_tryp]'):
                res['fallbacks'] += 1; per[cur or '?']['fallbacks'] += 1
            if ERR.search(l):
                res['lua_errors'] += 1; per[cur or '?']['lua_errors'] += 1
                if len(examples) < 8: examples.append('%s: %s' % (cur, l.strip()[:160]))
            if l.startswith('WATCHDOG'):
                res['watchdogs'] += 1
        shots = glob.glob(os.path.join(d, 'out', '*.png'))
        res['shots'] += len(shots)
        res['expected'] += len(maps) * levels
        have = {re.sub(r'_\d+(_\d+)?\.png$', '', os.path.basename(s)) for s in shots}
        res['missing'] += [m for m in maps if m not in have]
        if not lines:
            res['missing'] += maps
    res['missing'] = sorted(set(res['missing']))
    res['examples'] = examples
    return res, {k: v for k, v in per.items() if v['fallbacks'] or v['lua_errors']}


def gate(status, target, metrics, source, **kw):
    g = {'status': status, 'target': target, 'metrics': metrics, 'source': source}
    g.update(kw)
    return g


def g_sweep(out, cfg):
    tot = dict(shots=0, expected=0, fallbacks=0, lua_errors=0, watchdogs=0, missing=[])
    per, ex = {}, []
    for y in cfg['yaws']:
        r, p = scan_views(batch_dirs(out, 'sweep_y' + y))
        for k in ('shots', 'expected', 'fallbacks', 'lua_errors', 'watchdogs'):
            tot[k] += r[k]
        tot['missing'] += r['missing']; ex += r['examples']
        for k, v in p.items():
            per['%s yaw %s' % (k, y)] = v
    tot['missing'] = sorted(set(tot['missing']))
    ok = tot['fallbacks'] == 0 and tot['lua_errors'] == 0
    st = 'incomplete' if (tot['missing'] or tot['shots'] < tot['expected'] or tot['watchdogs']) else ('pass' if ok else 'fail')
    return gate(st, '0 fallbacks, 0 Lua errors', {k: v for k, v in tot.items()}, 'tools/qa_tryp.sh sweep, levels 4+7, yaws ' + ' '.join(cfg['yaws']),
                per_map=per, details=ex)


def g_magenta(out, cfg):
    import magenta_score
    # Pass/fail counts the level-7 frames. At level 4 a spot near the map's edge shows the world's far edge in the lower
    # frame (the pale underlay beyond the built map, magenta in the probe): not a hole, so level 4 is reported as info.
    frames = low = anym = low4 = 0
    bad, bad4, fb, miss = [], [], 0, []
    for y in cfg['yaws']:
        dirs = batch_dirs(out, 'magenta_y' + y)
        r, _ = scan_views(dirs)
        fb += r['fallbacks']; miss += r['missing']
        rows = magenta_score.score([os.path.join(d, 'out') for d in dirs])
        frames += len(rows)
        for tot, lo, band, d, f in rows:
            if tot > 0.0005: anym += 1
            if lo > 0.0005:
                if f.endswith('_4.png'):
                    low4 += 1; bad4.append('%s/%s low %.4f' % ('y' + y, f, lo))
                else:
                    low += 1; bad.append('%s/%s low %.4f' % ('y' + y, f, lo))
    st = 'incomplete' if (miss or frames == 0) else ('pass' if low == 0 and fb == 0 else 'fail')
    return gate(st, '0 level-7 frames with magenta in the lower 45%', {'frames': frames, 'frames_with_magenta': anym, 'frames_low': low, 'level4_frames_low_info': low4, 'fallbacks': fb},
                'tools/magenta_score.py on a probe tree (Gen3SceneOptions colour line)', details=bad[:40] + ['level 4 (info, edge of world?): ' + x for x in bad4[:40]])


def concat_dump(out, name):
    """-> (path, skipped, maps) of the run's cell dumps joined, SKIP lines dropped"""
    p = os.path.join(out, name + '_all.txt')
    skipped, maps = [], set()
    with open(p, 'w') as f:
        for d in batch_dirs(out, name):
            fp = os.path.join(d, 'dump.txt')
            if not os.path.exists(fp): continue
            for l in open(fp):
                if l.startswith('SKIP'): skipped.append(l.strip()); continue
                f.write(l); maps.add(l.split(' ', 1)[0])
    return p, skipped, maps


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def expected_dump_maps(out):
    o = outdoor_ids()
    return {m[0] for m in read_maps(os.path.join(out, 'maps.txt')) if m[0] in o}


def g_stairs(out, cfg):
    p, skipped, maps = concat_dump(out, 'dump1')
    os.makedirs(os.path.join(out, 'st'), exist_ok=True)
    dst = os.path.join(out, 'st', 'dump1.txt')
    if os.path.lexists(dst): os.remove(dst)
    os.symlink(p, dst)
    want = expected_dump_maps(out)
    if not maps:
        return gate('incomplete', '0 flat / 0 reversed / 0 cliff jumps; 0 ledges that do not drop', {}, 'tools/elevation/stairs_audit.py')
    rc, txt = run(['python3', '-I', os.path.join(ROOT, 'tools', 'elevation', 'stairs_audit.py'), out])
    open(os.path.join(out, 'stairs_audit.log'), 'w').write(txt)
    m = re.search(r'^ok (\d+) flat (\d+) odd (\d+) \(odd includes reversed (\d+)\)', txt, re.M)
    cl = re.search(r'^total (\d+) maps (\d+)', txt, re.M)
    blk = re.search(r'^blocked by elevation .*?: total (\d+)', txt, re.M)
    lg = re.search(r'== ledges \(outdoor\): (\d+) checked, (\d+) where', txt)
    if not (m and cl and lg):
        return gate('incomplete', '', {'error': 'stairs_audit output not understood (rc %d)' % rc}, 'tools/elevation/stairs_audit.py')
    met = {'stairs_ok': int(m.group(1)), 'flat': int(m.group(2)), 'reversed': int(m.group(4)), 'odd': int(m.group(3)) - int(m.group(4)),
           'cliff_jumps': int(cl.group(1)), 'blocked_cliffs': int(blk.group(1)) if blk else 0,
           'ledges_checked': int(lg.group(1)), 'ledges_bad': int(lg.group(2)), 'maps': len(maps)}
    bad = met['flat'] + met['reversed'] + met['cliff_jumps'] + met['ledges_bad']
    st = 'incomplete' if (want - maps or skipped) else ('pass' if bad == 0 else 'fail')
    return gate(st, '0 flat / 0 reversed / 0 cliff jumps; 0 ledges that do not drop', met, 'tools/elevation/stairs_audit.py on tools/em_cells_driver.lua dumps',
                details=sorted(want - maps) and ['missing maps: ' + ', '.join(sorted(want - maps))])


def g_repeat(out, cfg):
    p1, s1, m1 = concat_dump(out, 'dump1')
    p2, s2, m2 = concat_dump(out, 'dump2')
    if not m1 or not m2:
        return gate('incomplete', '0 cells differ between two runs and from the baseline', {}, 'tools/heights_compare.py')
    hc = os.path.join(ROOT, 'tools', 'heights_compare.py')
    flips = os.path.join(out, 'flips.txt')
    rc, t1 = run(['python3', '-I', hc, 'flips', p1, p2, flips])
    um = re.search(r'cells (\d+) unstable (\d+)', t1)
    # the baseline, cut to the maps of this run; empty flips list = strict
    base = cfg['baseline']
    sub = os.path.join(out, 'baseline_subset.txt')
    with open(sub, 'w') as f:
        for l in open(base):
            if l.split(' ', 1)[0] in m1: f.write(l)
    empty = os.path.join(out, 'noflips.txt'); open(empty, 'w').close()
    rc2, t2 = run(['python3', '-I', hc, 'diff', sub, p1, empty])
    dm = re.search(r'outside the unstable list: (\d+)', t2)
    if not (um and dm):
        return gate('incomplete', '', {'error': t1[-200:] + t2[-200:]}, 'tools/heights_compare.py')
    met = {'cells': int(um.group(1)), 'unstable_between_runs': int(um.group(2)), 'differ_from_baseline': int(dm.group(1)),
           'baseline': os.path.basename(base)}
    st = 'incomplete' if (expected_dump_maps(out) - m1 - m2) else ('pass' if met['unstable_between_runs'] == 0 and met['differ_from_baseline'] == 0 else 'fail')
    return gate(st, '0 cells differ between two runs of the same code', met, 'tools/heights_compare.py flips/diff', details=t2.splitlines()[:12])


def g_load(out, cfg):
    rows = []
    for d in batch_dirs(out, 'times'):
        part = []
        for l in log_of(d):
            m = re.match(r'\[EM t\]\t(\S+)\t(\d+)\t(\d+)\t(\w+)', l)
            if m: part.append((m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)))
        rows += part[1:]    # the first result of a batch is the warm-up
    if not rows:
        return gate('incomplete', 'every map in 3D within 1000 ms', {}, 'tools/em_times_driver_all.lua')
    ms = [r[2] for r in rows]
    slow = max(rows, key=lambda r: r[2])
    over = [r[0] + ' %d ms' % r[2] for r in rows if r[2] > 1000]
    timeouts = [r[0] for r in rows if r[1] > 900 or r[3] != 'true']
    want = {m[0] for m in read_maps(os.path.join(out, 'maps.txt'))}
    got = {r[0] for r in rows}
    met = {'maps': len(rows), 'median_ms': int(statistics.median(ms)), 'max_ms': slow[2], 'slowest': slow[0], 'over_1000ms': len(over),
           'timeouts_or_load_errors': len(timeouts), 'load_avg_1m': round(os.getloadavg()[0], 1)}
    st = 'incomplete' if (want - got) else ('pass' if not over and not timeouts else 'fail')
    return gate(st, 'under 1000 ms, serial, warm machine (noise from other apps does not count)', met, 'tools/em_times_driver_all.lua serial run',
                per_map={r[0]: r[2] for r in rows}, details=over + timeouts)


def g_defects(out, cfg):
    p = os.path.join(out, 'defects.log')
    if not os.path.exists(p):
        return gate('incomplete', '0 flagged', {}, 'tools/buildings/defect_scan.py')
    rows, flagged = 0, []
    cls = collections.Counter()
    for l in open(p):
        m = re.match(r'(\S+)\s+faces\s+\d+\s+flagged\s+(\d+)\s*(.*)', l)
        if m:
            rows += 1
            if int(m.group(2)) > 0:
                flagged.append('%s (%s)' % (m.group(1), m.group(3).strip()))
                for k, v in re.findall(r'(\w+) (\d+)', m.group(3)): cls[k] += 1
    st = 'incomplete' if rows == 0 else ('pass' if not flagged else 'fail')
    return gate(st, '0 flagged bakes, none unexplained', {'bakes': rows, 'flagged_bakes': len(flagged), 'by_class': dict(cls)},
                'tools/buildings/defect_scan.py', details=flagged)


def g_floats(out, cfg):
    fl, border, audited, maps, bad = [], [], 0, 0, []
    dims = {m['id']: (m['w'], m['h']) for m in json.load(open(os.path.join(ROOT, 'docs', 'ledger', 'maps.json')))}
    for d in batch_dirs(out, 'floats'):
        for l in log_of(d):
            if l.startswith('[RK1 float]'):
                # a float whose lowest cell lies outside the map is in the border scenery (no floor height there): info only
                mm = re.match(r'\[RK1 float\] (\S+) .*lowest=(-?\d+),(-?\d+)', l)
                w, h = dims.get(mm.group(1), (0, 0)) if mm else (0, 0)
                if mm and not (0 <= int(mm.group(2)) < w and 0 <= int(mm.group(3)) < h): border.append(l.strip())
                else: fl.append(l.strip())
            m = re.match(r'\[EM float\]\t(\S+)\t(\d+)\t(\w+)', l)
            if m:
                maps += 1; audited += int(m.group(2))
                if m.group(3) != 'true': bad.append(m.group(1))
    if maps == 0:
        return gate('incomplete', '0 floating props', {}, 'Gen3Rock.audit')
    want = len(read_maps(os.path.join(out, 'maps.txt')))
    st = 'incomplete' if (maps < want or bad or audited == 0) else ('pass' if not fl else 'fail')
    return gate(st, '0 floating rock masses', {'maps': maps, 'masses_audited': audited, 'floats': len(fl), 'border_floats_info': len(border)},
                'Gen3Rock.audit via tools/em_float_driver.lua', details=sorted(set(fl))[:40] + ['border (info): ' + x for x in sorted(set(border))[:20]])


def g_sheets(out, cfg):
    from PIL import Image, ImageDraw
    os.makedirs(os.path.join(out, 'sheets'), exist_ok=True)
    made = []
    for y in cfg['yaws']:
        files = []
        for d in batch_dirs(out, 'sweep_y' + y):
            files += sorted(glob.glob(os.path.join(d, 'out', '*.png')))
        for lvl in (4, 7):
            sel = [f for f in files if re.search(r'_%d(_\d+)?\.png$' % lvl, os.path.basename(f))]
            for i in range(0, len(sel), 30):
                chunk = sel[i:i + 30]
                tw, th = 320, 180
                sheet = Image.new('RGB', (6 * tw, ((len(chunk) + 5) // 6) * th), (20, 20, 20))
                dr = ImageDraw.Draw(sheet)
                for j, f in enumerate(chunk):
                    im = Image.open(f).convert('RGB').resize((tw, th))
                    x, yy = (j % 6) * tw, (j // 6) * th
                    sheet.paste(im, (x, yy))
                    name = re.sub(r'^EM_|_\d+(_\d+)?\.png$', '', os.path.basename(f))
                    dr.rectangle([x, yy, x + 8 * len(name) + 4, yy + 12], fill=(0, 0, 0))
                    dr.text((x + 2, yy + 1), name, fill=(255, 255, 255))
                p = os.path.join(out, 'sheets', 'L%d_yaw%s_%02d.png' % (lvl, y, i // 30))
                sheet.save(p); made.append(os.path.relpath(p, out))
    return gate('info' if made else 'incomplete', 'the user looks at the final sheet and says yes', {'sheets': len(made)},
                'PIL montage of the sweep shots, levels 4 and 7', details=made)


GATES = {'sweep': g_sweep, 'magenta': g_magenta, 'stairs': g_stairs, 'repeat': g_repeat, 'load': g_load,
         'defects': g_defects, 'floats': g_floats, 'sheets': g_sheets}
NOT_SCRIPTED = [
    "The user's yes on the final sheet: only the user sets a ledger row to done (docs/DONE.md rule 5).",
    "Frame time 'within the current numbers': no stored baseline exists; tools/em_perf_driver.lua reports a frame interval on Route 101 only.",
    "Buried props: Gen3Rock.audit detects floating rock masses only; trees and other props have no audit.",
    "Whether a shot looks right (hairlines, stretched faces, plain walls): needs eyes or the vision rubric of the loop's discovery step.",
]


def cmd_finish(out):
    cfg = json.load(open(os.path.join(out, 'config.json')))
    maps = read_maps(os.path.join(out, 'maps.txt'))
    res = {'schema': 1, 'run_id': cfg['run_id'], 'date': datetime.date.today().isoformat(),
           'scope': 'full' if (cfg['default_scope'] and set(cfg['gates']) >= set(GATES)) else 'subset',
           'maps': sorted({m[0] for m in maps}), 'mod_hash': cfg['mod_hash'], 'gates': {}, 'not_scripted': NOT_SCRIPTED}
    for g, fn in GATES.items():
        if g in cfg['gates'] or (g in ('stairs', 'repeat') and False):
            res['gates'][g] = fn(out, cfg)
        else:
            res['gates'][g] = gate('skipped', '', {}, '')
    json.dump(res, open(os.path.join(out, 'results.json'), 'w'), indent=1)
    md = ['# Release check %s (%s, %s scope, mod %s)' % (res['run_id'], res['date'], res['scope'], res['mod_hash']), '',
          '| Gate | Status | Target | Numbers |', '|---|---|---|---|']
    for g, v in res['gates'].items():
        md.append('| %s | %s | %s | %s |' % (g, v['status'], v['target'], ', '.join('%s %s' % (k, x) for k, x in v['metrics'].items())))
    md += ['', 'Not scripted:'] + ['- ' + n for n in NOT_SCRIPTED]
    for g, v in res['gates'].items():
        if v.get('details') and v['status'] in ('fail', 'incomplete'):
            md += ['', '## ' + g] + ['- ' + str(x) for x in v['details'][:20]]
    open(os.path.join(out, 'results.md'), 'w').write('\n'.join(md) + '\n')
    print('\n'.join(md[:4 + len(res['gates'])]))


if __name__ == '__main__':
    if sys.argv[1] == 'batches':
        cmd_batches(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5:])
    elif sys.argv[1] == 'finish':
        cmd_finish(sys.argv[2])
