#!/usr/bin/env python3
"""Capture cases for detector regions: the nearest walkable cell to each region, for tools/qa_tryp.sh.

  region_cases.py AIR.json [--per-map 6] [--maps A,B] [--extra MAP:x,y ...] [--geo DIR]
Prints one qa_tryp case string ({'MAP',x,y},...) and, on stderr, which region each case looks at.
Walkable = inside the map, coll=0, not water. Run with python3 -I.
"""
import argparse, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def cells(path):
    out = {}
    for l in open(path):
        f = l.split()
        if len(f) < 6:
            continue
        kv = dict(x.split('=', 1) for x in f[5:] if '=' in x)
        out[(int(f[1]), int(f[2]))] = (f[4], kv)
    return out


def walkable_near(cl, W, H, x, y, maxr=8):
    best = None
    for (cx, cy), (kind, kv) in cl.items():
        if not (0 <= cx < W and 0 <= cy < H):
            continue
        if kv.get('coll') != '0' or kind == 'water' or kv.get('bridge') == '1':
            continue
        d = abs(cx - x) + abs(cy - y)
        if d <= maxr * 2 and (best is None or d < best[0]):
            best = (d, cx, cy)
    return best


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('air')
    ap.add_argument('--per-map', type=int, default=6)
    ap.add_argument('--maps')
    ap.add_argument('--extra', nargs='*', default=[])
    ap.add_argument('--geo', default=os.path.join(ROOT, '.autoloop', 'geo'))
    o = ap.parse_args(argv)
    res = json.load(open(o.air))
    want = set(o.maps.split(',')) if o.maps else None
    cases = []
    for r in res:
        m = r['map']
        if want and m not in want:
            continue
        cl = cells(os.path.join(o.geo, m + '.cells'))
        for g in r['regions'][:o.per_map]:
            x, y = g['cell']
            w = walkable_near(cl, r['W'], r['H'], x, y)
            if w:
                cases.append((m, w[1], w[2]))
                print('%s %d,%d -> region cell %d,%d box %s gap %s area %s' % (m, w[1], w[2], x, y, g['box'], g['gap_max'], g['area_px']), file=sys.stderr)
    for e in o.extra:
        m, xy = e.split(':')
        x, y = (int(v) for v in xy.split(','))
        cases.append((m, x, y))
    seen, out = set(), []
    for c in cases:
        if c not in seen:
            seen.add(c)
            out.append("{'%s',%d,%d}" % c)
    print(','.join(out))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
