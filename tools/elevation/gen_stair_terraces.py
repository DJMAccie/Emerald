#!/usr/bin/env python3
"""Generate lib/Gen3StairTerraces.lua: raised platforms where stairs climb
between floors the cartridge rates the SAME level (stair_platforms.py finds
them). One pin per walkable component, the stair cells as flights, and the
blocked cells BETWEEN two paired flights (a planter between twin staircases)
as flight too, so they slope with the stairs instead of standing as a wall.

python3 gen_stair_terraces.py MAP [MAP...]"""
import sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import stair_platforms as sp

OUT = os.path.expanduser('~/Documents/battle-art-notquiteog/lib/Gen3StairTerraces.lua')
RISE = 12

# maps whose stairs are drawn on ordinary cells: their stair metatile ids
STAIR_MIDS = {'EM_SOOTOPOLIS_CITY': {0x244, 0x245},
              # the paving round the big planters (0x5D-0x5F) is not a staircase (user)
              'EM_BATTLE_FRONTIER_OUTSIDE_EAST': {0xAF, 0xCF},
              # the wooden steps up the cliff bands (the mountain is all one
              # nibble level: its terraces are only drawn)
              'EM_MT_CHIMNEY': {0x2AF}, 'EM_JAGGED_PASS': {0x2AF},
              # Mt. Pyre's white stairs climbing the mountain (rated one level)
              'EM_MT_PYRE_EXTERIOR': {0xAF, 0xCF, 0x328, 0x329}, 'EM_MT_PYRE_SUMMIT': {0xAF, 0xCF, 0x328, 0x329}}
# per-map rise per stair row where the default is too steep: Mt. Pyre's
# exterior climbs 14 stair rows through narrow cliff corridors; at 12 px a
# row the player camera is buried in rock
RISE_BY_MAP = {'EM_MT_PYRE_EXTERIOR': 16, 'EM_MT_PYRE_SUMMIT': 16}
# maps where each flight climbs one drawn cliff tier, however many rows it
# has (Mt. Pyre: a tier is drawn one cliff tile tall); rise is then per tier
PER_FLIGHT = {'EM_MT_PYRE_EXTERIOR', 'EM_MT_PYRE_SUMMIT'}
ISOLATED_NEAR = {'EM_MT_PYRE_EXTERIOR', 'EM_MT_PYRE_SUMMIT'}
# one-way ledges join terraces too: the side you jump down from (north) is a
# level above the side you land on (Jagged Pass's ridges)
LEDGE_MIDS = {'EM_JAGGED_PASS': {0x2EA, 0x2F0, 0x2F1, 0x2FC, 0x2FD}}

def ledge_edges(mp, W, H, cells, comp):
    mids = LEDGE_MIDS.get(mp)
    if not mids: return []
    led = {(x, y) for y in range(H) for x in range(W) if cells[y * W + x] & 0x3ff in mids}
    seen = set(); out = []
    for s in sorted(led, key=lambda p: (p[1], p[0])):
        if s in seen: continue
        strip = []; st = [s]; seen.add(s)
        while st:
            q = st.pop(); strip.append(q)
            for d in ((1, 0), (-1, 0)):
                n = (q[0] + d[0], q[1]); 
                if n in led and n not in seen: seen.add(n); st.append(n)
        north = {comp[(x, y - 1)] for x, y in strip if (x, y - 1) in comp}
        south = {comp[(x, y + 1)] for x, y in strip if (x, y + 1) in comp}
        if len(north) == 1 and len(south) == 1 and north != south:
            out.append((north.pop(), south.pop(), 1, []))
    return out

def build(mp):
    W, H, cells, comps, comp, edges, level, lo, rows = sp.analyse(mp, STAIR_MIDS.get(mp))
    nib = lambda k: cells[comps[k][0][1] * W + comps[k][0][0]] >> 12
    same = [e for e in edges if nib(e[0]) == nib(e[1])]
    links = same + [e for e in ledge_edges(mp, W, H, cells, comp) if nib(e[0]) == nib(e[1])]
    if mp in PER_FLIGHT:
        links = [(u, d, 1, st) for u, d, n, st in links]
    # each stair network on its own, its lowest terrace at 0 (a crater city
    # has several networks, each going down to the water)
    lv = {}
    for start in sorted({k for e in links for k in e[:2]}):
        if start in lv: continue
        net = {start: 0}; ch = True
        while ch:
            ch = False
            for up, down, n, _ in links:
                if down in net and up not in net: net[up] = net[down] + n; ch = True
                elif up in net and down not in net: net[down] = net[up] - n; ch = True
        m = min(net.values())
        for k, v in net.items(): lv[k] = v - m
    if not lv:
        base = max(range(len(comps)), key=lambda k: len(comps[k])); lv = {base: 0}
    if mp in ISOLATED_NEAR:
        # a pocket no stair reaches (a mountain's upper graveyard terraces)
        # takes the highest level of a linked terrace within 3 cells, not the
        # foot of the mountain
        changed = True
        while changed:          # a lifted pocket lifts the pockets beside it
            changed = False
            linked = dict(lv)
            for k in range(len(comps)):
                if k in linked: continue
                best = None
                for x, y in comps[k]:
                    for dx in range(-3, 4):
                        for dy in range(-3, 4):
                            j = comp.get((x + dx, y + dy))
                            if j in linked: best = linked[j] if best is None else max(best, linked[j])
                if best is not None: lv[k] = best; changed = True
    pins = [(comps[k][0][0], comps[k][0][1], lv.get(k, 0)) for k in range(len(comps))]
    stairs = {p for e in same for p in e[3]}
    # twin flights: same rows, same floors above and below -> fill the gap
    spans = []
    for up, down, n, strip in same:
        xs = sorted({p[0] for p in strip}); ys = sorted({p[1] for p in strip})
        spans.append((up, down, ys[0], ys[-1], xs[0], xs[-1]))
    for i, a in enumerate(spans):
        for b in spans[i + 1:]:
            if a[:4] == b[:4]:
                l, r = (a, b) if a[4] < b[4] else (b, a)
                for x in range(l[5] + 1, r[4]):
                    for y in range(a[2], a[3] + 1):
                        if (cells[y * W + x] >> 10) & 3:      # blocked: the planter
                            stairs.add((x, y))
    return pins, sorted(stairs)

if __name__ == '__main__':
    maps = sys.argv[1:] or ['EM_BATTLE_FRONTIER_OUTSIDE_EAST', 'EM_SAFARI_ZONE_NORTHEAST', 'EM_SAFARI_ZONE_SOUTHEAST', 'EM_SOOTOPOLIS_CITY',
                            'EM_MT_CHIMNEY', 'EM_JAGGED_PASS', 'EM_MT_PYRE_EXTERIOR', 'EM_MT_PYRE_SUMMIT']
    lua = ['-- GENERATED by tools/elevation/gen_stair_terraces.py: platforms where stairs',
           '-- climb between floors the cartridge rates the same level. pins = one row per',
           '-- walkable component {anchorX,anchorY,level}; stairs = flight cells (incl. a',
           '-- planter between twin flights). rise: world px per stair row (a drawn stair',
           '-- row is about half rise, half depth: 8 px true, 12 px for the extra depth).',
           'return {rise=%d,' % RISE]
    for mp in maps:
        pins, stairs = build(mp)
        r = RISE_BY_MAP.get(mp)
        lua.append(' %s={%spins={%s},' % (mp, ('rise=%d,' % r) if r else '', ','.join('{%d,%d,%d}' % p for p in pins)))
        lua.append('  stairs={%s}},' % ','.join('{%d,%d}' % s for s in stairs))
        print(mp, 'levels', sorted({p[2] for p in pins}), 'stair cells', len(stairs))
    lua.append('}')
    open(OUT, 'w').write('\n'.join(lua) + '\n')
