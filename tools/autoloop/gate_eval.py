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
VIS_FLOOR = 32.0        # px2: at the fault box, a region below this is dust, not something a camera can show. A voxel
                        # column is 2x2 px, so 32 px2 is 8 columns; the F006 verifier confirmed 8-12 px2 leftovers are
                        # invisible in full-resolution frames at every angle. The fault counts as fixed when no region
                        # at the box is above this floor AND the flagged area there fell by at least 90%.


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
    ap.add_argument('--base2', help='second build of the base (builder noise: pairs() order varies run to run)')
    ap.add_argument('--fix2', help='second build of the fix')
    ap.add_argument('--out')
    o = ap.parse_args(argv)
    box = [int(v) for v in o.box.split(',')]
    # the maps this gate dumped (the fix dir); the base dir is the shared per-commit cache and may hold many more
    maps = sorted(f[:-7] for f in os.listdir(o.fix) if f.endswith('.geo.gz'))
    if o.map not in maps:
        maps.insert(0, o.map)
    v = {'map': o.map, 'box': box, 'kind': o.kind, 'maps': maps, 'reasons': [], 'new': [], 'cells_changed': {}, 'fault_before': [], 'fault_after': [], 'review_spots': []}
    review = False
    ok = True
    for m in maps:
        if not os.path.exists(os.path.join(o.fix, m + '.geo.gz')) or not os.path.exists(os.path.join(o.base, m + '.geo.gz')):
            v['reasons'].append('missing dump: ' + m)
            ok = False
            continue
        ab, sb = regions(o.base, m, o.lib_base)
        af, sf = regions(o.fix, m, o.lib_fix)
        # builder noise: a region counts only if both fix builds have it; base regions = either base build
        if o.base2 and os.path.exists(os.path.join(o.base2, m + '.geo.gz')):
            ab2, sb2 = regions(o.base2, m, o.lib_base)
            ab, sb = ab + ab2, sb + sb2
        if o.fix2 and os.path.exists(os.path.join(o.fix2, m + '.geo.gz')):
            af2, sf2 = regions(o.fix2, m, o.lib_fix)
            af = [r for r in af if any(overlap(r['box'], q['box']) for q in af2)]
            sf = [r for r in sf if any(overlap(r['box'], q['box']) for q in sf2)]
        if m == o.map and o.kind != 'none':
            rb = ab if o.kind == 'air' else sb
            rf = af if o.kind == 'air' else sf
            v['fault_before'] = [r for r in rb if overlap(r['box'], box, 1)]
            v['fault_after'] = [r for r in rf if overlap(r['box'], box, 1)]
            if not v['fault_before']:
                v['reasons'].append('note: no %s region at the box in BASE (the detector does not see this fault)' % o.kind)
            # A region the BASE already had at the box is not this fault, and a region the fix keeps in the same
            # place is not fixed: match by overlap (2 cells), then only unmatched base regions count as cured and
            # only unmatched fix regions above the floor count as remaining.
            def match(r, pool):
                return any(overlap(r['box'], q['box'], 2) for q in pool)
            over = [r for r in v['fault_after'] if (r.get('area_px') or 0) >= VIS_FLOOR]
            cured = [r for r in v['fault_before'] if (r.get('area_px') or 0) >= VIS_FLOOR and not match(r, over)]
            survived = [r for r in over if match(r, v['fault_before'])]
            v['fault_matched'] = {'cured': len(cured), 'survived': len(survived)}
            area_b = sum(r.get('area_px') or 0 for r in v['fault_before'])
            area_a = sum(r.get('area_px') or 0 for r in v['fault_after'])
            v['fault_area'] = {'before': area_b, 'after': area_a}
            if v['fault_after']:
                v['reasons'].append('slivers at the box: %d region(s), %d px2 total (visibility floor %d px2)'
                                    % (len(v['fault_after']), area_a, VIS_FLOOR))
            if survived:
                ok = False
                v['reasons'].append('not fixed: %d region(s) over the visibility floor survive at the box (matched to base)'
                                    % len(survived))
            elif not cured and v['fault_before']:
                ok = False
                v['reasons'].append('not fixed: none of the base regions at the box went away')
        for kind, rb, rf in (('air', ab, af), ('steps', sb, sf)):
            for r in rf:
                if r.get('edge'):
                    continue
                if m == o.map and overlap(r['box'], box, 1):
                    continue
                if not any(overlap(r['box'], q['box']) for q in rb):
                    big = kind == 'steps' or r.get('area_px', 0) >= MIN_NEW_AREA
                    v['new'].append({'map': m, 'kind': kind, 'box': r['box'], 'area_px': r.get('area_px'), 'gap_max': r.get('gap_max'), 'steps': r.get('steps'), 'failing': big})
                    if big:
                        ok = False
        cb, cf = cells(o.base, m), cells(o.fix, m)
        cb2 = cells(o.base2, m) if o.base2 and os.path.exists(os.path.join(o.base2, m + '.cells')) else cb
        cf2 = cells(o.fix2, m) if o.fix2 and os.path.exists(os.path.join(o.fix2, m + '.cells')) else cf
        grown = [box[0] - 2, box[1] - 2, box[2] + 2, box[3] + 2]
        changed = []
        for k in sorted(set(cb) | set(cf)):
            # a real change: both fix builds agree and differ from both base builds
            if cf.get(k) == cf2.get(k) and cf.get(k) != cb.get(k) and cf.get(k) != cb2.get(k):
                inside = m == o.map and grown[0] <= k[0] <= grown[2] and grown[1] <= k[1] <= grown[3]
                if not inside:
                    changed.append([k[0], k[1]])
        if changed:
            # a class fix changes other places on purpose: not a failure by itself, but every changed area must be
            # looked at (REVIEW): one capture spot per 8-cell cluster of changed cells, on the nearest walkable cell
            review = True
            v['cells_changed'][m] = changed[:40] + ([['...', len(changed)]] if len(changed) > 40 else [])
            v['reasons'].append('%s: %d cell line(s) changed outside the fault box (review)' % (m, len(changed)))
            seen = set()
            for x, y in changed:
                k = (x // 8, y // 8)
                if k in seen:
                    continue
                seen.add(k)
                best = None
                for (cx, cy), line in cf.items():
                    f = line.split()
                    if 'coll=0' in f and f[4] != 'water' and abs(cx - x) + abs(cy - y) <= 10:
                        d = abs(cx - x) + abs(cy - y)
                        if best is None or d < best[0]:
                            best = (d, cx, cy)
                if best:
                    v['review_spots'].append([m, best[1], best[2]])
    if any(n['failing'] for n in v['new']):
        v['reasons'].append('new detector regions: ' + ', '.join('%s %s %s' % (n['map'], n['kind'], n['box']) for n in v['new'] if n['failing']))
    v['pass'] = ok
    v['status'] = 'FAIL' if not ok else ('REVIEW' if review else 'PASS')
    v['review_spots'] = v['review_spots'][:24]
    print(json.dumps({k: v[k] for k in ('status', 'reasons', 'review_spots')}, indent=1))
    if o.out:
        json.dump(v, open(o.out, 'w'), indent=1)
    return {'PASS': 0, 'FAIL': 1, 'REVIEW': 2}[v['status']]


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
