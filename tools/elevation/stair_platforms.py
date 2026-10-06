#!/usr/bin/env python3
"""Platforms implied by stairs, on maps where the cartridge's elevation nibble
does not encode the terrace (Rustboro, Slateport, Fortree's lower town...).

Rule (deliberately strict): stair cells are walkable cells of elevation 0.
Cut them out of the walkable ground (water excluded). A stair strip that then
touches exactly two separate ground components joins two floors; the
component on the strip's NORTH side is the upper one (Gen 3 stairs climb
north), raised by the strip's length in cells. Strips that do not split the
ground (decorative steps) and side-on strips are ignored. Levels propagate
through chains of platforms. Output: {anchorX, anchorY, level} rows like
Gen3EmeraldTerraces (anchor = first cell of the component in reading order).

python3 stair_platforms.py MAP [MAP...]  [--png out.png]"""
import sys, os, json, struct, collections
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
import voxproto

def load(mp):
    G = voxproto.G
    census = json.load(open(G + '/map_tree/census.json'))
    key = mp[3:].replace('_', '').lower()
    for g in census['groups']:
        for m in g['maps']:
            if m['id'].replace('_', '').lower() == key: slot = m['slot']
    h = json.load(open(G + '/map_tree/maps/%s/header.json' % slot))
    W, H = h['width'], h['height']
    cells = struct.unpack('<%dH' % (W * H), open(G + '/map_tree/maps/%s/grid.bin' % slot, 'rb').read())
    return W, H, cells

def analyse(mp, stair_mids=None):
    """stair_mids: metatile ids that are stairs on this map (Sootopolis draws
    its stairs on ordinary e3 cells); default: walkable elevation-0 cells."""
    W, H, cells = load(mp)
    def info(x, y):
        v = cells[y * W + x]; return v & 0x3ff, (v >> 10) & 3, v >> 12
    walk = {}; stair = set()
    for y in range(H):
        for x in range(W):
            mid, col, el = info(x, y)
            if col != 0 or el == 1: continue
            if (stair_mids and mid in stair_mids) or (not stair_mids and el == 0): stair.add((x, y))
            elif el != 0: walk[(x, y)] = el
    D = ((1, 0), (-1, 0), (0, 1), (0, -1))
    comp = {}; comps = []
    for p in sorted(walk, key=lambda p: (p[1], p[0])):
        if p in comp: continue
        k = len(comps); comps.append([]); st = [p]; comp[p] = k
        while st:
            q = st.pop(); comps[k].append(q)
            for d in D:
                n = (q[0] + d[0], q[1] + d[1])
                if n in walk and n not in comp and walk[n] == walk[q]: comp[n] = k; st.append(n)
    # stair strips
    seen = set(); edges = []
    for s in sorted(stair, key=lambda p: (p[1], p[0])):
        if s in seen: continue
        strip = []; st = [s]; seen.add(s)
        while st:
            q = st.pop(); strip.append(q)
            for d in D:
                n = (q[0] + d[0], q[1] + d[1])
                if n in stair and n not in seen: seen.add(n); st.append(n)
        ys = [p[1] for p in strip]; xs = [p[0] for p in strip]
        north = {comp[(x, min(ys) - 1)] for x in xs if (x, min(ys) - 1) in comp}
        south = {comp[(x, max(ys) + 1)] for x in xs if (x, max(ys) + 1) in comp}
        if len(north) == 1 and len(south) == 1 and north != south:
            edges.append((north.pop(), south.pop(), max(ys) - min(ys) + 1, strip))
    # propagate levels from the biggest component (ground = its nibble level)
    base = max(range(len(comps)), key=lambda k: len(comps[k])) if comps else None
    level = {base: 0} if base is not None else {}
    changed = True
    while changed:
        changed = False
        for up, down, n, _ in edges:
            if down in level and up not in level: level[up] = level[down] + n; changed = True
            elif up in level and down not in level: level[down] = level[up] - n; changed = True
    lo = min(level.values()) if level else 0
    rows = [(comps[k][0][0], comps[k][0][1], lv - lo, len(comps[k])) for k, lv in level.items() if lv != lo or k == base]
    return W, H, cells, comps, comp, edges, level, lo, rows

if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    png = sys.argv[sys.argv.index('--png') + 1] if '--png' in sys.argv else None
    if png: args = [a for a in args if a != png]
    for mp in args:
        W, H, cells, comps, comp, edges, level, lo, rows = analyse(mp)
        print(mp, 'components', len(comps), 'splitting stairs', len(edges))
        for up, down, n, strip in edges: print('  stair at', strip[0], 'cells', len(strip), 'rise', n, 'up comp', up, '(%d cells)' % len(comps[up]), 'down', down, '(%d)' % len(comps[down]))
        print('  pins', [(x, y, l) for x, y, l, _ in rows])
