#!/usr/bin/env python3
"""Generate walkthrough waypoints for tools/qa_tryp.sh from a whole-map cell dump and outdoor_spots.txt.

  python3 -I tools/waypoints.py [DUMP] [SPOTS] [OUT_CASES] [--stride 8] [--radius 12]

For every map in SPOTS (default: docs/ledger/outdoor_spots.txt), reads its cells from DUMP
(tools/em_cells_driver.lua / tools/heights_compare.py format) and places waypoints at:
  - the map's starting spot in SPOTS;
  - every door (warp cell or the walkable step in front of it);
  - every stair flight;
  - every jump ledge (every ~8 cells along long runs);
  - every building front (walkable cell in front of the bottom-centre of each building column group);
  - an ~8-cell walkable grid (ordered by BFS from the starting spot), plus greedy fill so every
    walkable cell is within <= 12 cells (Manhattan and Euclidean) of a waypoint.
Writes a Lua cases file (`return { {'EM_MAP',x,y}, ... }`) when OUT_CASES is given and prints
waypoint counts, feature breakdown, max distance, and <=12-cell coverage per outdoor map.
"""
import argparse
import collections
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DUMP = os.path.expanduser('~/Documents/gen1recomp-modwork/baselines/heights-2026-10-20-fix-F025.txt')
DEFAULT_SPOTS = os.path.join(ROOT, 'docs', 'ledger', 'outdoor_spots.txt')
MAPS_JSON = os.path.join(ROOT, 'docs', 'ledger', 'maps.json')

# Metatile IDs used as stairs on outdoor maps when stairs=1 is not set on the cell
STAIR_MIDS = {0xAF, 0xCF, 0xE8, 0x244, 0x245, 0x2AF, 0x328, 0x329}


def load_map_dims(path=MAPS_JSON):
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        return {m['id']: (int(m['w']), int(m['h'])) for m in json.load(f)}


def load_spots(path):
    spots = []
    with open(path) as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 3 and not line.lstrip().startswith('#'):
                spots.append((parts[0], int(parts[1]), int(parts[2])))
    return spots


def load_dump(path, dims=None):
    dims = dims or {}
    by_map = collections.defaultdict(dict)
    with open(path) as f:
        for line in f:
            p = line.rstrip('\n').split(' ')
            if len(p) < 5 or p[0] == 'SKIP':
                continue
            mp = p[0]
            try:
                x, y = int(p[1]), int(p[2])
                mid = int(p[3], 16)
            except ValueError:
                continue
            if mp in dims:
                w, h = dims[mp]
                if not (0 <= x < w and 0 <= y < h):
                    continue
            elif x < 0 or y < 0:
                continue
            kind = p[4]
            kv = {}
            for tok in p[5:]:
                if '=' in tok:
                    k, v = tok.split('=', 1)
                    kv[k] = v
            by_map[mp][(x, y)] = (mid, kind, kv)
    return by_map


def is_walkable(cell):
    _mid, kind, kv = cell
    return kv.get('coll') in ('0', '24') and kind not in ('water', 'tree')


def components(pts, eight=False):
    pts = set(pts)
    dirs = (
        ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))
        if eight
        else ((1, 0), (-1, 0), (0, 1), (0, -1))
    )
    seen, out = set(), []
    for p in sorted(pts, key=lambda k: (k[1], k[0])):
        if p in seen:
            continue
        comp, q = [], collections.deque([p])
        seen.add(p)
        while q:
            u = q.popleft()
            comp.append(u)
            for dx, dy in dirs:
                v = (u[0] + dx, u[1] + dy)
                if v in pts and v not in seen:
                    seen.add(v)
                    q.append(v)
        out.append(sorted(comp, key=lambda k: (k[1], k[0])))
    return out


def bfs_order(walk_set, start):
    """Return BFS distance map {cell: dist} over 4-connected walkable cells starting from start."""
    dist = {}
    seeds = [start] if start in walk_set else []
    seeds += sorted(walk_set, key=lambda k: (k[1], k[0]))
    for s in seeds:
        if s in dist:
            continue
        dist[s] = 0 if s == start else (max(dist.values(), default=0) + 1)
        q = collections.deque([s])
        while q:
            u = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                v = (u[0] + dx, u[1] + dy)
                if v in walk_set and v not in dist:
                    dist[v] = dist[u] + 1
                    q.append(v)
    return dist


def map_waypoints(cells, start_xy, stride=8, radius=12):
    """Compute ordered waypoints and coverage metrics for a single map."""
    walk = sorted(
        [k for k, c in cells.items() if is_walkable(c)],
        key=lambda k: (k[1], k[0]),
    )
    walk_set = set(walk)
    bfs_dist = bfs_order(walk_set, start_xy)

    wps = {}  # (x, y) -> category
    counts = collections.Counter()

    def add_wp(pt, cat):
        if pt not in wps:
            wps[pt] = cat
            counts[cat] += 1

    # 1. Seed spot from outdoor_spots.txt
    if start_xy in cells or not walk:
        add_wp(start_xy, 'start')

    # 2. Doors (warps): prefer walkable cell immediately south of door if present
    doors = [k for k, (_m, _k, kv) in cells.items() if kv.get('door') == '1']
    for comp in components(doors):
        c = comp[len(comp) // 2]
        front = (c[0], c[1] + 1)
        add_wp(front if front in walk_set else c, 'door')

    # 3. Stairs
    stairs = [
        k for k, (mid, kind, kv) in cells.items()
        if kv.get('stairs') == '1' or kind == 'steps' or mid in STAIR_MIDS
    ]
    for comp in components(stairs):
        add_wp(comp[len(comp) // 2], 'stair')

    # 4. Ledges (every `stride` cells along connected ledge runs)
    ledges = [
        k for k, (_m, kind, kv) in cells.items()
        if kv.get('ledge') == '1' or kind == 'ledge'
    ]
    for comp in components(ledges):
        for i in range(0, len(comp), stride):
            chunk = comp[i:i + stride]
            add_wp(chunk[len(chunk) // 2], 'ledge')

    # 5. Building fronts (bottom-centre of each 8-connected building column group)
    blds = [
        k for k, (_m, kind, kv) in cells.items()
        if kv.get('col') == 'y' or kind in ('wall', 'roof')
    ]
    for comp in components(blds, eight=True):
        xs = [p[0] for p in comp]
        ys = [p[1] for p in comp]
        mx, my = (min(xs) + max(xs)) // 2, max(ys)
        front = (mx, my + 1)
        if front in walk_set:
            add_wp(front, 'building')
        else:
            # Check along the front row for a walkable cell before falling back to (mx, my)
            front_walk = [
                (x, my + 1) for x in range(min(xs), max(xs) + 1)
                if (x, my + 1) in walk_set
            ]
            if front_walk:
                best_fw = min(front_walk, key=lambda p: abs(p[0] - mx))
                add_wp(best_fw, 'building')
            else:
                add_wp((mx, my), 'building')

    # 6. Walkable grid every ~stride cells (in BFS order from start_xy)
    by_blk = collections.defaultdict(list)
    for pt in sorted(walk, key=lambda p: (bfs_dist.get(p, 10**9), p[1], p[0])):
        by_blk[(pt[0] // stride, pt[1] // stride)].append(pt)
    for _blk, pts in sorted(
        by_blk.items(),
        key=lambda kv: min(bfs_dist.get(p, 10**9) for p in kv[1]),
    ):
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        best = min(pts, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
        if not any(abs(best[0] - w[0]) + abs(best[1] - w[1]) <= stride // 2 - 1 for w in wps):
            add_wp(best, 'grid')

    # 7. Guarantee every walkable cell is within <= radius cells (Manhattan) of a waypoint
    while walk:
        far_d, far_p = max(
            (min(abs(p[0] - w[0]) + abs(p[1] - w[1]) for w in wps), p)
            for p in walk
        )
        if far_d <= radius:
            break
        add_wp(far_p, 'grid')

    ordered = sorted(
        wps.keys(),
        key=lambda p: (0 if p == start_xy else 1, bfs_dist.get(p, 10**9), p[1], p[0]),
    )

    if walk:
        manhattan_dists = [min(abs(p[0] - w[0]) + abs(p[1] - w[1]) for w in ordered) for p in walk]
        euclid_dists = [min(math.hypot(p[0] - w[0], p[1] - w[1]) for w in ordered) for p in walk]
        covered = sum(1 for d in manhattan_dists if d <= radius)
        max_manhattan = max(manhattan_dists)
        max_euclid = max(euclid_dists)
    else:
        covered = 0
        max_manhattan = 0
        max_euclid = 0.0

    stats = {
        'walkable': len(walk),
        'waypoints': len(ordered),
        'doors': counts['door'],
        'stairs': counts['stair'],
        'ledges': counts['ledge'],
        'buildings': counts['building'],
        'grid': counts['grid'] + counts['start'],
        'covered': covered,
        'coverage_pct': (100.0 * covered / len(walk)) if walk else 100.0,
        'max_manhattan': max_manhattan,
        'max_euclid': round(max_euclid, 2),
    }
    return [( x, y, wps[(x, y)]) for x, y in ordered], stats


def format_cases_lua(all_cases):
    lines = ['return {']
    for mp, x, y, _cat in all_cases:
        lines.append(" {'%s',%d,%d}," % (mp, x, y))
    lines.append('}')
    return '\n'.join(lines) + '\n'


def main(argv=None):
    ap = argparse.ArgumentParser(description='Generate walkthrough waypoints for qa_tryp.sh from a cell dump.')
    ap.add_argument('dump', nargs='?', default=DEFAULT_DUMP, help='cell dump path (heights_compare.py format)')
    ap.add_argument('spots', nargs='?', default=DEFAULT_SPOTS, help='outdoor_spots.txt path ("MAP x y" lines)')
    ap.add_argument('out', nargs='?', default=None, help='output Lua cases file path (or --out)')
    ap.add_argument('--out', '-o', dest='out_flag', help='output Lua cases file path')
    ap.add_argument('--stride', type=int, default=8, help='grid spacing in walkable cells (default: 8)')
    ap.add_argument('--radius', type=int, default=12, help='max allowed distance from a waypoint (default: 12)')
    args = ap.parse_args(argv)

    out_path = args.out_flag or args.out
    dims = load_map_dims()
    spots = load_spots(args.spots)
    by_map = load_dump(args.dump, dims)

    all_cases = []
    per_map = []
    for mp, sx, sy in spots:
        cells = by_map.get(mp, {})
        wps, st = map_waypoints(cells, (sx, sy), stride=args.stride, radius=args.radius)
        for x, y, cat in wps:
            all_cases.append((mp, x, y, cat))
        per_map.append((mp, st))

    if out_path:
        with open(out_path, 'w') as f:
            f.write(format_cases_lua(all_cases))

    print('%-34s %6s %5s %5s %5s %6s %5s %5s %8s %6s %6s' % (
        'Map', 'Walk', 'WPs', 'Door', 'Stair', 'Ledge', 'Bld', 'Grid', 'Cov<=%d' % args.radius, 'MaxM', 'MaxE'))
    print('-' * 102)
    tot_walk = tot_wps = tot_cov = 0
    tot_door = tot_stair = tot_ledge = tot_bld = tot_grid = 0
    worst_m = 0
    worst_e = 0.0
    for mp, st in per_map:
        tot_walk += st['walkable']
        tot_wps += st['waypoints']
        tot_cov += st['covered']
        tot_door += st['doors']
        tot_stair += st['stairs']
        tot_ledge += st['ledges']
        tot_bld += st['buildings']
        tot_grid += st['grid']
        worst_m = max(worst_m, st['max_manhattan'])
        worst_e = max(worst_e, st['max_euclid'])
        print('%-34s %6d %5d %5d %5d %6d %5d %5d %7.1f%% %6d %6.2f' % (
            mp, st['walkable'], st['waypoints'], st['doors'], st['stairs'],
            st['ledges'], st['buildings'], st['grid'], st['coverage_pct'],
            st['max_manhattan'], st['max_euclid']))
    print('-' * 102)
    overall_pct = (100.0 * tot_cov / tot_walk) if tot_walk else 100.0
    print('%-34s %6d %5d %5d %5d %6d %5d %5d %7.1f%% %6d %6.2f' % (
        'TOTAL (%d outdoor maps)' % len(per_map), tot_walk, tot_wps, tot_door,
        tot_stair, tot_ledge, tot_bld, tot_grid, overall_pct, worst_m, worst_e))
    if out_path:
        print('wrote %d cases to %s' % (len(all_cases), out_path))
    return 0


if __name__ == '__main__':
    sys.exit(main())
