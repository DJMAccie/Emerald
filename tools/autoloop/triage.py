#!/usr/bin/env python3
"""Turn a world sweep's detector output into a ranked fault queue (docs/AUTOLOOP.md discovery step).

  triage.py WORLD_DIR [--gap 4] [--area 200] [--class outdoor] [--top 40] [--json OUT] [--cases OUT]

Reads world_air.json / world_steps.json from WORLD_DIR (tools/autoloop/sweep.sh), keeps regions that are not at the
dump edge, drops soft-rock shoulders (gap below --gap px: the user accepts rounding up to ~3 px) and slivers (area
below --area px2), groups what is left into clusters (same map, same cell kind, within 8 cells) and ranks the clusters
by total area x gap. Prints the queue and, with --cases, writes a qa_tryp case string (one walkable spot per cluster,
from the map's .cells file) for judging them by eye.

Caves are listed separately: Gen3 dumps no cave ceiling, so the sky flood reaches every cave interior and the air rule
cannot judge caves (docs/AUTOLOOP.md, calibration).
Run with python3 -I.
"""
import argparse, json, os, sys, collections

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def spots(path):
    out = {}
    for l in open(path):
        f = l.split()
        if len(f) >= 3:
            out[f[0]] = (int(f[1]), int(f[2]))
    return out


def cells(path):
    out = {}
    try:
        for l in open(path):
            f = l.split()
            if len(f) >= 6:
                kv = dict(x.split('=', 1) for x in f[5:] if '=' in x)
                out[(int(f[1]), int(f[2]))] = (f[4], kv)
    except FileNotFoundError:
        pass
    return out


def walkable_near(cl, W, H, x, y, maxr=10):
    best = None
    for (cx, cy), (kind, kv) in cl.items():
        if not (0 <= cx < W and 0 <= cy < H) or kv.get('coll') != '0' or kind == 'water' or kv.get('bridge') == '1':
            continue
        d = abs(cx - x) + abs(cy - y)
        if d <= maxr and (best is None or d < best[0]):
            best = (d, cx, cy)
    return best


def near(a, b, r):
    return not (a[2] + r < b[0] or b[2] + r < a[0] or a[3] + r < b[1] or b[3] + r < a[1])


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('world')
    ap.add_argument('--gap', type=float, default=4.0)
    ap.add_argument('--area', type=float, default=200.0)
    ap.add_argument('--class', dest='cls', default='outdoor', choices=['outdoor', 'cave', 'all'])
    ap.add_argument('--top', type=int, default=40)
    ap.add_argument('--json')
    ap.add_argument('--cases')
    o = ap.parse_args(argv)
    out_spots = spots(os.path.join(ROOT, 'docs/ledger/outdoor_spots.txt'))
    cave_spots = spots(os.path.join(ROOT, 'docs/ledger/cave_spots.txt'))
    maps = {}
    for name, f in (('air', 'world_air.json'), ('steps', 'world_steps.json')):
        p = os.path.join(o.world, f)
        if os.path.exists(p):
            for m in json.load(open(p)):
                maps.setdefault(m['map'], {})[name] = m['regions']
    out_maps, cave_maps = set(out_spots), set(cave_spots)
    keep, caves = [], collections.Counter()
    for name, kinds in sorted(maps.items()):
        cls = 'outdoor' if name in out_maps else ('cave' if name in cave_maps else 'other')
        if cls == 'cave' or cls == 'other':
            caves[cls] += len([r for r in kinds.get('air', []) if not r.get('edge')])
            if o.cls == 'cave' and cls == 'cave':
                pass
        if o.cls == 'outdoor' and cls != 'outdoor':
            continue
        for kind, regs in kinds.items():
            for r in regs:
                if r.get('edge'):
                    continue
                if kind == 'air' and (r['gap_max'] < o.gap or r['area_px'] < o.area):
                    continue
                if kind == 'steps' and r.get('steps', 0) < 3:
                    continue
                keep.append({'map': name, 'kind': kind, 'box': r['box'], 'area_px': r.get('area_px'),
                             'gap_max': r.get('gap_max'), 'steps': r.get('steps'), 'run': r.get('run'),
                             'heights': r.get('heights'), 'cell': r.get('cell'),
                             'tile': (r.get('cell_info') or {}).get('tile'), 'cell_kind': (r.get('cell_info') or {}).get('kind')})
    # cluster: same map, same kind, same cell kind, boxes within 8 cells
    clusters = []
    for c in sorted(keep, key=lambda c: -(c['area_px'] or 0)):
        for cl in clusters:
            if cl['map'] == c['map'] and cl['kind'] == c['kind'] and cl['cell_kind'] == c['cell_kind'] and near(cl['box'], c['box'], 8):
                cl['regions'].append(c)
                cl['box'] = [min(cl['box'][0], c['box'][0]), min(cl['box'][1], c['box'][1]), max(cl['box'][2], c['box'][2]), max(cl['box'][3], c['box'][3])]
                cl['area'] += c['area_px'] or 0
                cl['gap'] = max(cl['gap'], c['gap_max'] or 0)
                break
        else:
            clusters.append({'map': c['map'], 'kind': c['kind'], 'cell_kind': c['cell_kind'], 'box': list(c['box']),
                             'regions': [c], 'area': c['area_px'] or 0, 'gap': c['gap_max'] or 0})
    # Ranking for a person looking at captures: things that should not float (props, roofs, awnings, trees, ledges,
    # signs, extruded furniture, flat ground) come before cliff masses, because a big cliff mass with air under its top
    # is usually a terraced mountain's inside (checked by eye 2026-10-20 on Ever Grande, Route 111, Sootopolis, Route 115:
    # all correct in game), while F006's real fault was 3 small flat/cliff cells beside a stair.
    for cl in clusters:
        cl['score'] = round(cl['area'] * max(cl['gap'], 1))
        cl['order'] = (2 if cl['cell_kind'] == 'cliff' and cl['area'] > 5000 else
                       (0 if cl['cell_kind'] not in ('cliff', None) else 1))
    clusters.sort(key=lambda c: (c['order'], -c['score']))
    print('%-30s %-6s %-8s %-18s %5s %4s %7s %s' % ('map', 'kind', 'cell', 'box', 'regs', 'gap', 'area', 'score'))
    for cl in clusters[:o.top]:
        print('%-30s %-6s %-8s %-18s %5d %4.0f %7d %7d' % (cl['map'], cl['kind'], cl['cell_kind'], ','.join(map(str, cl['box'])),
                                                         len(cl['regions']), cl['gap'], cl['area'], cl['score']))
    print('\n%d clusters from %d regions (%s); caves skipped: %d air regions' % (len(clusters), len(keep), o.cls, sum(caves.values())))
    if o.json:
        json.dump(clusters, open(o.json, 'w'), indent=1)
    if o.cases:
        cases, seen = [], set()
        for cl in clusters[:o.top]:
            spot = out_spots.get(cl['map'])
            cl2 = cells(os.path.join(o.world, cl['map'] + '.cells'))
            W = max((k[0] for k in cl2), default=0) + 1
            H = max((k[1] for k in cl2), default=0) + 1
            w = walkable_near(cl2, W, H, *(cl.get('cell') or spot or (0, 0)))
            if w:
                key = (cl['map'], w[1], w[2])
                if key not in seen:
                    seen.add(key)
                    cases.append("{'%s',%d,%d}" % key)
        open(o.cases, 'w').write(','.join(cases))
        print('%d cases -> %s' % (len(cases), o.cases))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
