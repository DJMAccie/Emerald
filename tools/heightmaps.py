#!/usr/bin/env python3
"""Bake docs/elevation/draw/claude_heightmaps/*.json into mod/data/gen3_heightmaps.lua.

Per cell one token (rows top to bottom):
  .              no ground (wall, void)
  <h>            floor height in courses (flat, water, object)
  <dir>[io]<lo>:<hi>  45-degree ramp rising toward dir (N S E W NE NW SE SW); a corner is i (inner) or o (outer)
Ramps with no height are stacked one course per tile from the nearest known height (R-38).
"""
import json, math, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'docs/elevation/draw/claude_heightmaps')
SAME = os.path.join(ROOT, 'docs/elevation/draw/_same.txt')
OUT = os.path.join(ROOT, 'mod/data/gen3_heightmaps.lua')
VEC = {'N': (0, -1), 'S': (0, 1), 'E': (1, 0), 'W': (-1, 0), 'NE': (1, -1), 'NW': (-1, -1), 'SE': (1, 1), 'SW': (-1, 1)}
# corners 0=NW 1=NE 2=SE 3=SW as vertex offsets
CORNER = [(0, 0), (1, 0), (1, 1), (0, 1)]
HIGH = {'N': (0, 1), 'S': (2, 3), 'E': (1, 2), 'W': (0, 3)}
APEX = {'NW': 0, 'NE': 1, 'SE': 2, 'SW': 3}
FLAT = ('flat', 'water', 'object')
# Petya's corrections on single tiles: map -> {(x, y): (lo, hi, dir)}
FIX = {
    # Seafloor Cavern room 1 (2026-11-02): the diagonal rock pieces right of the stairs and along the east wall
    # rise to the upper right and are plain corners; the area above them is 1 high
    'EM_SEAFLOOR_CAVERN_ROOM1': {(11, 4): (0, 1, 'NE'), (12, 5): (0, 1, 'NE'), (13, 6): (0, 1, 'NE'),
                                 (14, 1): (1, 2, 'NE'), (15, 2): (1, 2, 'NE'), (16, 3): (1, 2, 'NE'),
                                 (17, 6): (1, 2, 'NE'), (18, 8): (1, 2, 'NE')},
}
# Cave doors that stand in a slope: the warp tile and the arch tile above it are flat on the warp's low end (Petya: a door is two tiles)
DOORS = {'EM_GRANITE_CAVE_STEVENS_ROOM': [(7, 3)], 'EM_CAVE_OF_ORIGIN_ENTRANCE': [(9, 5)],
         'EM_SHOAL_CAVE_LOW_TIDE_ENTRANCE_ROOM': [(6, 2), (27, 2)], 'EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM': [(30, 25)],
         'EM_MAGMA_HIDEOUT_4F': [(46, 7)], 'EM_MAGMA_HIDEOUT_3F_1R': [(21, 9)]}
SLOPE = ('ramp', 'stairs', 'waterfall')


def num(v):
    s = ('%.3f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def spikes(W, H, T, Hm, R):
    """Forget ramp heights 3+ courses away from every neighbour (stacking slips in the source)."""
    out = []
    for y in range(H):
        for x in range(W):
            r = R[y][x]
            if not (T[y][x] in SLOPE and r and r[0] is not None):
                continue
            nb = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                X, Y = x + dx, y + dy
                if 0 <= X < W and 0 <= Y < H:
                    q = R[Y][X]
                    v = q[0] if (T[Y][X] in SLOPE and q and q[0] is not None) else (Hm[Y][X] if T[Y][X] in FLAT else None)
                    if v is not None:
                        nb.append(v)
            if nb and min(abs(r[0] - v) for v in nb) >= 3:
                out.append((x, y))
    for x, y in out:
        R[y][x][0] = R[y][x][1] = None
    return len(out)


def fill(d, W, H, T, Hm, R):
    """Give ramps without heights one course per tile from the nearest known height."""
    stats = 0
    for _ in range(40):
        changed = False
        for y in range(H):
            for x in range(W):
                if T[y][x] not in SLOPE or not R[y][x]:
                    continue
                r = R[y][x]
                lo, hi, up = r[0], r[1], r[2]
                if lo is not None and hi is not None:
                    continue
                if lo is not None or hi is not None:
                    r[0], r[1] = (lo, lo + 1) if lo is not None else (hi - 1, hi)
                    changed = True; stats += 1
                    continue
                dx, dy = VEC[up]
                got = None
                for k in range(1, 13):  # back, against the arrow
                    X, Y = x - dx * k, y - dy * k
                    if not (0 <= X < W and 0 <= Y < H):
                        break
                    if T[Y][X] in FLAT and Hm[Y][X] is not None:
                        got = Hm[Y][X] + (k - 1); break
                    q = R[Y][X]
                    if T[Y][X] in SLOPE and q and q[1] is not None:
                        got = q[1] + (k - 1); break
                if got is not None:
                    r[0], r[1] = got, got + 1
                    changed = True; stats += 1
                    continue
                for k in range(1, 13):  # forward, along the arrow
                    X, Y = x + dx * k, y + dy * k
                    if not (0 <= X < W and 0 <= Y < H):
                        break
                    if T[Y][X] in FLAT and Hm[Y][X] is not None:
                        got = Hm[Y][X] - (k - 1); break
                    q = R[Y][X]
                    if T[Y][X] in SLOPE and q and q[0] is not None:
                        got = q[0] - (k - 1); break
                if got is not None:
                    r[0], r[1] = got - 1, got
                    changed = True; stats += 1
        if not changed:
            break
    return stats


OPP = {'N': 'S', 'S': 'N', 'E': 'W', 'W': 'E'}


def orient(W, H, T, Hm, R):
    """A straight ramp between two floors always rises toward the higher floor; flip arrows that point down."""
    flips = []
    for y in range(H):
        for x in range(W):
            r = R[y][x]
            if not (T[y][x] == 'ramp' and r and r[0] is not None and r[2] in HIGH):
                continue
            dx, dy = VEC[r[2]]

            def walk(s):
                k = 1
                while True:
                    X, Y = x + dx * s * k, y + dy * s * k
                    if not (0 <= X < W and 0 <= Y < H):
                        return None, k
                    if T[Y][X] in FLAT and Hm[Y][X] is not None:
                        return Hm[Y][X], k
                    q = R[Y][X]
                    if not (T[Y][X] == 'ramp' and q and q[2] == r[2]):
                        return None, k
                    k += 1
            hb, k = walk(-1)
            ha, m = walk(1)
            if hb is not None and ha is not None and ha < hb:
                n = k + m - 1
                flips.append((x, y, OPP[r[2]], ha + (hb - ha) * (m - 1) / n, ha + (hb - ha) * m / n))
    for x, y, up, lo, hi in flips:
        R[y][x][0], R[y][x][1], R[y][x][2] = lo, hi, up
    return len(flips)


def corners(t, h, r):
    """Known corner heights of one tile (None = not fixed by the tile itself)."""
    if t in FLAT and h is not None:
        return [h] * 4
    if t in SLOPE and r and r[0] is not None and r[1] is not None:
        lo, hi, up = r
        c = [lo] * 4
        if up in HIGH:
            for i in HIGH[up]:
                c[i] = hi
            return c
        a = APEX[up]
        c = [None] * 4
        c[a], c[(a + 2) % 4] = hi, lo
        return c
    return [None] * 4


def bake(name):
    d = json.load(open(os.path.join(SRC, name + '.json')))
    W, H, T, Hm, R = d['width'], d['height'], d['type'], d['height_map'], d['ramp']
    R = [[list(r) if r else None for r in row] for row in R]
    spiked = spikes(W, H, T, Hm, R)
    filled = fill(d, W, H, T, Hm, R)
    flipped = orient(W, H, T, Hm, R)
    for (x, y), (lo, hi, up) in FIX.get(name, {}).items():
        T[y][x], Hm[y][x], R[y][x] = 'ramp', (lo + hi) / 2, [lo, hi, up]
    for x, y in DOORS.get(name, []):
        lo = R[y][x][0] if T[y][x] in SLOPE and R[y][x] and R[y][x][0] is not None else Hm[y][x]
        for yy in (y, y - 1):
            if T[yy][x] in SLOPE:
                T[yy][x], Hm[yy][x], R[yy][x] = 'flat', lo, None
    # floors and ramp feet below 0 are not built (black holes, Shoal Cave low tide, Navel Rock top):
    # heights are per map, so lift a dry map until its lowest floor or ramp foot is 0
    low = min([Hm[y][x] for y in range(H) for x in range(W) if T[y][x] in FLAT and Hm[y][x] is not None]
              + [r[0] for row in R for r in row if r and r[0] is not None] or [0])
    if low < 0 and not any(t == 'water' for row in T for t in row):
        s = math.ceil(-low)
        Hm = [[v + s if v is not None else None for v in row] for row in Hm]
        R = [[[r[0] + s if r[0] is not None else None, r[1] + s if r[1] is not None else None, r[2]] if r else None for r in row] for row in R]
    vert = {}
    for y in range(H):
        for x in range(W):
            for i, v in enumerate(corners(T[y][x], Hm[y][x], R[y][x])):
                if v is not None:
                    ox, oy = CORNER[i]
                    vert.setdefault((x + ox, y + oy), []).append((x, y, v))
    toks, inner, outer, straight, dropped = [], 0, 0, 0, 0
    for y in range(H):
        for x in range(W):
            t, h, r = T[y][x], Hm[y][x], R[y][x]
            if t in FLAT and h is not None:
                toks.append(num(h))
            elif t in SLOPE and r and r[0] is not None and r[1] is not None:
                lo, hi, up = r
                kind = ''
                if up in APEX:
                    # each side corner votes high or low: both high = inner corner, both low = outer corner,
                    # one high one low = a straight ramp drawn with a diagonal arrow (its high edge is apex + the high corner)
                    a, mid, votes = APEX[up], (lo + hi) / 2, []
                    for i in ((a + 1) % 4, (a + 3) % 4):
                        ox, oy = CORNER[i]
                        s = 0
                        for (X, Y, v) in vert.get((x + ox, y + oy), []):
                            if (X, Y) != (x, y):
                                s += (v > mid + 1e-6) - (v < mid - 1e-6)
                        votes.append((i, s))
                    (i1, s1), (i2, s2) = votes
                    if s1 * s2 < 0:
                        hi_c = i1 if s1 > 0 else i2
                        up = next(d for d, pair in HIGH.items() if set(pair) == {a, hi_c})
                        straight += 1
                    else:
                        kind = 'i' if s1 + s2 > 0 else 'o'
                        inner += kind == 'i'; outer += kind == 'o'
                toks.append('%s%s%s:%s' % (up, kind, num(lo), num(hi)))
            else:
                dropped += t in SLOPE
                toks.append('.')
    rows = [' '.join(toks[y * W:(y + 1) * W]) for y in range(H)]
    return W, H, '\n'.join(rows), (spiked, filled, flipped, inner, outer, straight, dropped)


def main():
    names = sorted(f[:-5] for f in os.listdir(SRC) if f.endswith('.json') and not f.startswith('_'))
    same = {}
    for line in open(SAME):
        if '=' in line:
            a, b = line.split('=', 1)
            same[a.strip()] = [s.strip() for s in b.split(',') if s.strip()]
    out = ['-- GENERATED by tools/heightmaps.py from docs/elevation/draw/claude_heightmaps (do not edit).',
           '-- Per map {width,height,cells}: one token per cell, rows top to bottom. "." = no ground, <h> = floor height',
           '-- in courses, <dir>[i|o]<lo>:<hi> = 45-degree ramp rising toward dir (corner: i inner, o outer).',
           'return {']
    tot = [0, 0, 0, 0, 0, 0, 0]
    for n in names:
        W, H, cells, st = bake(n)
        tot = [a + b for a, b in zip(tot, st)]
        for m in [n] + [s for s in same.get(n, []) if s not in names]:
            out.append('%s={%d,%d,[[\n%s]]},' % (m, W, H, cells))
    out.append('}')
    open(OUT, 'w').write('\n'.join(out) + '\n')
    print('maps %d  spikes reset %d  filled ramps %d  arrows flipped uphill %d  corners inner %d outer %d  diagonal arrows made straight %d  ramps left without height %d  -> %s (%d KB)' % (
        len(names), tot[0], tot[1], tot[2], tot[3], tot[4], tot[5], tot[6], os.path.relpath(OUT, ROOT), os.path.getsize(OUT) // 1024))


if __name__ == '__main__':
    main()
