#!/usr/bin/env python3
"""Bake docs/elevation/draw/claude_heightmaps/*.json into mod/data/gen3_heightmaps.lua.

Per cell one token (rows top to bottom):
  .              no ground (wall, void)
  <h>            floor height in courses (flat, water)
  o<h>           ground under a separate prop
  [sw]<dir>[io]<lo>:<hi>  rock ramp, s stair, w vertical waterfall; i/o inner/outer corner
Every source JSON is exact (reviewed per tile, or generated): this script only converts, it repairs nothing.
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
SLOPE = ('ramp', 'stairs', 'waterfall')


def num(v):
    s = ('%.3f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


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
    # A waterfall is a single vertical sheet; every fall tile stands at its upper pool.
    seen = set()
    for y in range(H):
        for x in range(W):
            if T[y][x] != 'waterfall' or (x, y) in seen:
                continue
            run, todo, levels = [], [(x, y)], []
            seen.add((x, y))
            while todo:
                X, Y = todo.pop()
                run.append((X, Y))
                if R[Y][X]:
                    levels.extend(v for v in R[Y][X][:2] if v is not None)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    a, b = X + dx, Y + dy
                    if not (0 <= a < W and 0 <= b < H):
                        continue
                    if T[b][a] == 'waterfall' and (a, b) not in seen:
                        seen.add((a, b)); todo.append((a, b))
                    elif T[b][a] == 'water' and Hm[b][a] is not None:
                        levels.append(Hm[b][a])
            if levels:
                for X, Y in run:
                    R[Y][X] = [min(levels), max(levels), 'N']
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
                toks.append(('o' if t == 'object' else '') + num(h))
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
                tag = 's' if t == 'stairs' else 'w' if t == 'waterfall' else ''
                toks.append('%s%s%s%s:%s' % (tag, up, kind, num(lo), num(hi)))
            else:
                dropped += t in SLOPE
                toks.append('.')
    rows = [' '.join(toks[y * W:(y + 1) * W]) for y in range(H)]
    return W, H, '\n'.join(rows), (inner, outer, straight, dropped)


def main():
    names = sorted(f[:-5] for f in os.listdir(SRC) if f.endswith('.json') and not f.startswith('_'))
    same = {}
    for line in open(SAME):
        if '=' in line:
            a, b = line.split('=', 1)
            same[a.strip()] = [s.strip() for s in b.split(',') if s.strip()]
    out = ['-- GENERATED by tools/heightmaps.py from docs/elevation/draw/claude_heightmaps (do not edit).',
           '-- Per map {width,height,cells}: one token per cell, rows top to bottom. "." = no ground, <h> = floor height',
           '-- in courses, o<h> = prop ground; [s|w]<dir>[i|o]<lo>:<hi> = rock ramp / stair / vertical waterfall.',
           'return {']
    tot = [0, 0, 0, 0]
    for n in names:
        W, H, cells, st = bake(n)
        tot = [a + b for a, b in zip(tot, st)]
        for m in [n] + [s for s in same.get(n, []) if s not in names]:
            out.append('%s={%d,%d,[[\n%s]]},' % (m, W, H, cells))
    out.append('}')
    content = '\n'.join(out) + '\n'
    if '--check' in sys.argv:
        from heightmaps_check import check
        check()
        if not os.path.exists(OUT) or open(OUT).read() != content:
            raise SystemExit('Baked height maps are stale; run python3 tools/heightmaps.py')
    else:
        open(OUT, 'w').write(content)
    print('maps %d  corners inner %d outer %d  diagonal arrows made straight %d  ramps without height %d  -> %s (%d KB)' % (
        len(names), *tot, os.path.relpath(OUT, ROOT), os.path.getsize(OUT) // 1024))


if __name__ == '__main__':
    main()
