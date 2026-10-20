#!/usr/bin/env python3
"""Gate verdict for one autoloop fix: compare geometry dumps of the base tree and the fix tree.

  gate_eval.py BASE_GEO_DIR FIX_GEO_DIR --map MAP --box x0,y0,x1,y1 [--kind air|steps|none] [--out verdict.json]

Pass = all of:
  fixed      no detector region of --kind intersecting --box (grown by 1 cell) remains on MAP in FIX
             (kind 'none': skipped, for faults no detector measures; the captures and the verifier decide)
  no_new     no region in FIX (any map, air and steps) that overlaps no region of BASE, except inside the box
  cells      .cells lines identical outside the box grown by 2 cells, on every map
  complete   every map dumped in both trees
Prints the reasons. Run with python3 -I (numpy, scipy).
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import detect

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MIN_NEW_AREA = 32.0     # px2: a new air region smaller than this is a sliver, reported but not failing


def overlap(a, b, grow=0):
    return not (a[2] + grow < b[0] or b[2] + grow < a[0] or a[3] + grow < b[1] or b[3] + grow < a[1])


def regions(geo_dir, m, lib):
    p = os.path.join(geo_dir, m + '.geo.gz')
    air = detect.detect_air(p, libdir=lib)['regions']
    steps = detect.detect_steps(p.replace('.geo.gz', '.cells'), faces=detect.step_faces(p, lib))
    return air, steps


def cells(geo_dir, m):
    out = {}
    for l in open(os.path.join(geo_dir, m + '.cells')):
        f = l.split(' ', 3)
        if len(f) >= 4:
            out[(int(f[1]), int(f[2]))] = l.rstrip('\n')
    return out


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('base')
    ap.add_argument('fix')
    ap.add_argument('--map', required=True)
    ap.add_argument('--box', required=True)
    ap.add_argument('--kind', default='air', choices=['air', 'steps', 'none'])
    ap.add_argument('--lib-base', default=os.path.join(ROOT, '.autoloop', 'rc', 'lib'))
    ap.add_argument('--lib-fix', default=os.path.join(ROOT, '.autoloop', 'rc', 'lib'))
    ap.add_argument('--out')
    o = ap.parse_args(argv)
    box = [int(v) for v in o.box.split(',')]
    maps = sorted(f[:-7] for f in os.listdir(o.base) if f.endswith('.geo.gz'))
    v = {'map': o.map, 'box': box, 'kind': o.kind, 'maps': maps, 'reasons': [], 'new': [], 'cells_changed': {}, 'fault_before': [], 'fault_after': []}
    ok = True
    for m in maps:
        if not os.path.exists(os.path.join(o.fix, m + '.geo.gz')):
            v['reasons'].append('missing fix dump: ' + m)
            ok = False
            continue
        ab, sb = regions(o.base, m, o.lib_base)
        af, sf = regions(o.fix, m, o.lib_fix)
        if m == o.map and o.kind != 'none':
            rb = ab if o.kind == 'air' else sb
            rf = af if o.kind == 'air' else sf
            v['fault_before'] = [r for r in rb if overlap(r['box'], box, 1)]
            v['fault_after'] = [r for r in rf if overlap(r['box'], box, 1)]
            if not v['fault_before']:
                v['reasons'].append('note: no %s region at the box in BASE (the detector does not see this fault)' % o.kind)
            if v['fault_after']:
                ok = False
                v['reasons'].append('not fixed: %d %s region(s) still at the box' % (len(v['fault_after']), o.kind))
        for kind, rb, rf in (('air', ab, af), ('steps', sb, sf)):
            for r in rf:
                if m == o.map and overlap(r['box'], box, 1):
                    continue
                if not any(overlap(r['box'], q['box']) for q in rb):
                    big = kind == 'steps' or r.get('area_px', 0) >= MIN_NEW_AREA
                    v['new'].append({'map': m, 'kind': kind, 'box': r['box'], 'area_px': r.get('area_px'), 'gap_max': r.get('gap_max'), 'steps': r.get('steps'), 'failing': big})
                    if big:
                        ok = False
        cb, cf = cells(o.base, m), cells(o.fix, m)
        grown = [box[0] - 2, box[1] - 2, box[2] + 2, box[3] + 2]
        changed = []
        for k in sorted(set(cb) | set(cf)):
            if cb.get(k) != cf.get(k):
                inside = m == o.map and grown[0] <= k[0] <= grown[2] and grown[1] <= k[1] <= grown[3]
                if not inside:
                    changed.append([k[0], k[1]])
        if changed:
            ok = False
            v['cells_changed'][m] = changed[:40] + ([['...', len(changed)]] if len(changed) > 40 else [])
            v['reasons'].append('%s: %d cell line(s) changed outside the fault box' % (m, len(changed)))
    if any(n['failing'] for n in v['new']):
        v['reasons'].append('new detector regions: ' + ', '.join('%s %s %s' % (n['map'], n['kind'], n['box']) for n in v['new'] if n['failing']))
    v['pass'] = ok
    print(json.dumps({k: v[k] for k in ('pass', 'reasons')}, indent=1))
    if o.out:
        json.dump(v, open(o.out, 'w'), indent=1)
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
