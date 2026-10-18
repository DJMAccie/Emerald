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
# Caves the cartridge rates one level but draws with ledges and stairs
# (user: "make the cave floors have real height differences"). Their stair
# tiles per tileset; a stair row climbs one row of ledge face (16 px); whole
# floors may be rated 0. Caves whose nibble already carries levels keep it.
CAVE_STAIRS = {'general__cave': {0x204, 0x363}, 'general__meteor_falls': {0x202}, 'general__mirage_tower': {0x204},
               'general__navel_rock': {0x204, 0x37B}, 'general__lavaridge': {0x2AF, 0xAF, 0xCF}}
CAVES = {}

# Navel Rock's summit is a path up an open mountainside, not a walled cave:
# its raised top floated as a bare plane over the slope
CAVE_SKIP = {'EM_NAVEL_ROCK_TOP'}
# Caves whose rating alternates 3/4 from one terrace to the next whichever
# way the stairs climb (a stair's upper floor is often rated the LOWER one):
# their levels are read from the drawing like the unrated caves'
CAVE_DRAWN = {'EM_ARTISAN_CAVE_B1F', 'EM_METEOR_FALLS_1F_1R', 'EM_SHOAL_CAVE_HIGH_TIDE_ENTRANCE_ROOM', 'EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM',
              'EM_SHOAL_CAVE_LOW_TIDE_ENTRANCE_ROOM', 'EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM'}
CAVE_PAIRS = {'general__cave', 'general__meteor_falls', 'general__mirage_tower', 'general__navel_rock', 'general__lavaridge',
              'general__pacifidlog', 'general__rusturf_tunnel'}

def find_caves():
    """cave maps (mapType 4) whose drawing shows more than one floor level
    (cave_levels) while the nibble rates the walkable floor one level"""
    import json, re, cave_levels
    G = sp.voxproto.G
    man = open(os.path.expanduser('~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native/manifest.lua')).read()
    pair = dict(re.findall(r'\["(EM_[A-Z0-9_]+)"\] = \{ pair = "([a-z_0-9]+)"', man))
    census = json.load(open(G + '/map_tree/census.json'))
    out = []
    for g in census['groups']:
        for m in g['maps']:
            h = json.load(open(G + '/map_tree/maps/%s/header.json' % m['slot']))
            if h.get('mapType') != 4: continue
            key = m['id'].replace('_', '').lower()
            ids = [k for k in pair if k[3:].replace('_', '').lower() == key]
            if not ids or pair[ids[0]] not in CAVE_PAIRS: continue
            mp = ids[0]
            if 'UNUSED' in mp or mp in CAVE_SKIP: continue
            W, H, cells = sp.load(mp)
            levels = {v >> 12 for v in cells if not (v >> 10) & 3} - {0, 1, 15}
            if len(levels) > 1 and mp not in CAVE_DRAWN: continue          # the nibble carries its levels
            r = cave_levels.levels(mp, pair[mp], CAVE_STAIRS.get(pair[mp], set()))
            if len(set(r[5].values())) < 2: continue
            CAVES[mp] = r
            out.append(mp)
    return sorted(out)

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

# Outdoor maps whose stairs join floors the cartridge rates the same level
# while other floors ARE rated (user: "do a pass on all the stairs ... make
# sure that all the height levels are correct"). Only the floors a stair
# lifts or lowers against the cartridge's rating are pinned (on=true: every
# other cell keeps its rated height): level = rated level + offset, where a
# stair between same-rated floors puts its north floor one level per stair row
# above its south floor and every other link carries the offset unchanged.
OUTDOOR = ['EM_FARAWAY_ISLAND_ENTRANCE', 'EM_LILYCOVE_CITY', 'EM_ROUTE104', 'EM_ROUTE111', 'EM_ROUTE115', 'EM_ROUTE116',
           'EM_ROUTE119', 'EM_ROUTE120', 'EM_ROUTE121', 'EM_SAFARI_ZONE_NORTHEAST', 'EM_SAFARI_ZONE_SOUTHWEST',
           'EM_SLATEPORT_CITY', 'EM_SOUTHERN_ISLAND_EXTERIOR', 'EM_MOSSDEEP_CITY', 'EM_ROUTE114', 'EM_EVER_GRANDE_CITY']
OUTDOOR += ['EM_ROUTE112', 'EM_METEOR_FALLS_1F_1R', 'EM_SHOAL_CAVE_HIGH_TIDE_ENTRANCE_ROOM', 'EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM',
            'EM_SHOAL_CAVE_LOW_TIDE_ENTRANCE_ROOM', 'EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM', 'EM_ARTISAN_CAVE_B1F', 'EM_SOUTHERN_ISLAND_EXTERIOR']
OUTDOOR = [m for m in dict.fromkeys(OUTDOOR) if m not in CAVE_DRAWN]
OUTDOOR_MIDS = {'EM_METEOR_FALLS_1F_1R': {0x202}, 'EM_ARTISAN_CAVE_B1F': {0x204, 0x363}}
for _m in ('EM_SHOAL_CAVE_HIGH_TIDE_ENTRANCE_ROOM', 'EM_SHOAL_CAVE_HIGH_TIDE_INNER_ROOM', 'EM_SHOAL_CAVE_LOW_TIDE_ENTRANCE_ROOM', 'EM_SHOAL_CAVE_LOW_TIDE_INNER_ROOM'):
    OUTDOOR_MIDS[_m] = {0x204, 0x363}
OUT_DONE = {}

POCKETS = {}
# lone cells in a notch of a mountainside, at no terrace's height in the drawing
POCKET_SKIP = {('EM_ROUTE119', (32, 30)), ('EM_MOSSDEEP_CITY', (57, 16))}
# floors lifted by hand where the cartridge's ratings contradict the drawing and links put a drawn
# stair flat or upside down: {map: [(levels, [cells, one per floor component])]}.
# Tried and left out (2026-10-17): Route 119's middle. Its drawing stacks the lower plateau (33,92),
# the upper plateau (35,86) up the stair at (35,89) level with the log bridge and the west plateau
# (5,82), the grass above that plateau up the stair at (5,80), and the floors above that grass up
# the stairs at (19,53), (6,54) and (21,48). At one level a stair that needs the grass at (26,51)
# 3 up and the forest at (12,28) 6 up, which stood its north edge as tall grass-faced cliffs over
# the floors beside it. The two stairs stay flat and reversed by decision.
# Hand pins spliced into the installed file (not produced here): Lilycove's south strip (30,33),
# rated 5 but drawn as the same flat grass as the field it joins through an elevation-0 row
# (31,13 at level 1), stood 32 px up behind a grass wall with 8 walkable jumps; it is pinned level
# 1, and (31,13) and (53,4) are pinned at their old heights (any pin re-solves the map).
# NOTE: this generator no longer reproduces the installed Route 115 row (it rewrites (19,21) and
# (21,13) to level 5 and drops (17,66)): splice single rows, never regenerate the whole file.
LEVEL_ADD = {}
def build_outdoor(mp):
    # (0xE8: the narrow flight between two posts; rated caves bring their own stair tiles)
    W, H, cells, comps, comp, edges, _, _, _ = sp.analyse(mp, OUTDOOR_MIDS.get(mp, {0xAF, 0xCF, 0xE8}))
    rawnib = lambda k: cells[comps[k][0][1] * W + comps[k][0][0]] >> 12
    # (heights clamp at three levels: floors rated 7 and 9 stand level, and a stair between them is flat too)
    nib = lambda k: min(rawnib(k), 6)
    links = []                                   # (a, b, d): off[b] = off[a] + d
    stairs = set()
    for up, down, n, strip in edges:
        if nib(up) == nib(down): links.append((down, up, n)); stairs.update(strip)
        else: links.append((down, up, 0))
    for (x, y), a in comp.items():               # floors of different rating that touch
        for d in ((1, 0), (0, 1)):
            b = comp.get((x + d[0], y + d[1]))
            if b is not None and b != a: links.append((a, b, 0))
    off = {}
    order = sorted(range(len(comps)), key=lambda k: -len(comps[k]))
    for start in order:
        if start in off: continue
        off[start] = 0; ch = True; net = {start}
        while ch:
            ch = False
            for a, b, d in links:
                if a in off and b not in off: off[b] = off[a] + d; net.add(b); ch = True
                elif b in off and a not in off: off[a] = off[b] - d; net.add(a); ch = True
        m = min(off[k] for k in net)
        for k in net: off[k] -= m
    # a small pocket of floor no stair reaches, cut off from a lifted floor of
    # its own rating only by a rock or two in its own row, stands on that
    # floor's terrace (Route 116: three cells left at the foot beside it)
    linked = {k for l in links for k in l[:2]}
    POCKETS.setdefault(mp, [])
    for k in range(len(comps)):
        if k in linked or len(comps[k]) > 6 or rawnib(k) in (0, 1, 15): continue
        if (mp, comps[k][0]) in POCKET_SKIP: continue
        found = set()
        for x, y in comps[k]:
            for sx in (-1, 1):
                for n in (1, 2, 3):
                    j = comp.get((x + sx * n, y))
                    if j == k: break
                    if j is not None:
                        # (both stand on the terrace's front edge: rock under each)
                        if j in linked and off.get(j, 0) and rawnib(j) == rawnib(k) \
                                and (x, y + 1) not in comp and (x + sx * n, y + 1) not in comp \
                                and (x, y + 1) not in stairs:
                            found.add(off[j])
                        break
        if len(found) == 1: off[k] = found.pop(); POCKETS[mp].append((comps[k][0], len(comps[k]), off[k]))
    add = {}
    for n, pts in LEVEL_ADD.get(mp, []):
        for p in pts:
            k = comp.get(p)
            assert k is not None, (mp, p)
            add[k] = n
    pins = []
    for k in range(len(comps)):
        if (off.get(k, 0) or k in add) and rawnib(k) not in (0, 1, 15):
            pins.append((comps[k][0][0], comps[k][0][1], min(nib(k) - 3, 3) + off.get(k, 0) + add.get(k, 0)))
    return pins, sorted(stairs)

def build(mp):
    if mp in OUT_DONE: return OUT_DONE[mp]
    if mp in CAVES:
        W, H, cells, comps, comp, lv, stairs = CAVES[mp]
        return [(comps[k][0][0], comps[k][0][1], lv.get(k, 0)) for k in range(len(comps))], stairs
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
    caves = find_caves()
    if not sys.argv[1:]: maps = maps + caves
    if not sys.argv[1:]:
        for mp in OUTDOOR:
            r = build_outdoor(mp)
            if r[0]: OUT_DONE[mp] = r; maps.append(mp)
    lua = ['-- GENERATED by tools/elevation/gen_stair_terraces.py: platforms where stairs',
           '-- climb between floors the cartridge rates the same level. pins = one row per',
           '-- walkable component {anchorX,anchorY,level}; stairs = flight cells (incl. a',
           '-- planter between twin flights). rise: world px per stair row (a drawn stair',
           '-- row is about half rise, half depth: 8 px true, 12 px for the extra depth).',
           '-- cave=true: a cave whose floor levels are read from its drawing',
           '-- (tools/elevation/cave_levels.py), on without a switch in Gen3EmeraldTerraces.',
           'return {rise=%d,' % RISE]
    for mp in maps:
        pins, stairs = build(mp)
        r = RISE_BY_MAP.get(mp) or (16 if mp in CAVES or mp in OUT_DONE else None)
        lua.append(' %s={%s%spins={%s},' % (mp, 'cave=true,' if mp in CAVES else 'on=true,' if mp in OUT_DONE else '', ('rise=%d,' % r) if r else '', ','.join('{%d,%d,%d}' % p for p in pins)))
        lua.append('  stairs={%s}},' % ','.join('{%d,%d}' % s for s in stairs))
        print(mp, 'levels', sorted({p[2] for p in pins}), 'stair cells', len(stairs))
    lua.append('}')
    open(OUT, 'w').write('\n'.join(lua) + '\n')
