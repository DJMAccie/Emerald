#!/usr/bin/env python3
"""Derive Battle Art shape tables for every Emerald tileset pair.

Inputs: world.json (tools output: every map's grid/border/pair/type plus the
engine's canonical per-pair behaviors) and atlases/<pair>/ (baked RGBA layers).

Outdoor pairs (general__*):
  * Buildings are anchored on door tiles (WARP_DOOR 0x69, or CAVE_DOOR 0x60 on a
    secondary tile). A 4-connected blob of blocked, unclassified cells reached
    from a door is a building: its two bottom rows are walls, the rows above
    are roof, and the walkable row directly above the blob is the roof's
    overhang when it is not ordinary ground (Hoenn lets you walk behind roofs).
  * Water, ledges, rails and grass come from behaviors at runtime, so they are
    skipped here; General-tileset art is hand-authored in Gen3EmeraldShapes.
  * Other blocked secondary tiles: cave walls in cave pairs; elsewhere large
    brown blobs become cliffs, brown/grey singles rocks, green ones shrubs.
Interior pairs (building__*, secret_base__*):
  * Blocked cells on the top two rows are the north wall; other blocked cells
    are relief props; counters are low bins. Doors, warps, ladders and
    escalators are skipped. The floor is the most common walkable tile.
Votes are counted per pair across every map that uses it; the majority wins.

  python3 gen_emerald_tables.py <workdir> <out.lua>
"""
import collections, os, sys, json, struct, collections

W_DIR = sys.argv[1]
OUT = sys.argv[2]
world = json.load(open(os.path.join(W_DIR, 'world.json')))
maps = world['maps']
behaviors = {pair: {int(k): v for k, v in t.items()} for pair, t in world['behaviors'].items()}  # JSON keys are strings

# --- behaviors (canonical ids, see src/core/game3/mb.lua) -----------------
B = dict(TALL_GRASS=0x02, LONG_GRASS=0x103, JUMP=set([0x38, 0x39, 0x3A, 0x3B, 0x13E, 0x13F]),
         MOUNTAIN_TOP=0x0C, LADDER=0x61, WARP_DOOR=0x69, CAVE_DOOR=0x60,
         RAILS=set([0x1D6, 0x1D5, 0x1D4, 0x1D3]), COUNTER=0x80, PC=0x83,
         WATER=set([0x10, 0x12, 0x15, 0x17, 0x13, 0x16, 0x111, 0x114, 0x22, 0x12A]))
def is_warpish(b):
    return b is not None and (0x60 <= b <= 0x7F or b == B['LADDER'] or 0x6A <= b <= 0x6B)

# --- hand-authored General art (mirrors Gen3EmeraldShapes.lua) ------------
def span(s, a, b):
    s.update(range(a, b + 1))
G_TREE = set([0x1D4, 0x1D5, 0x1D6, 0x1D7, 0x1DC, 0x1DD, 0x1E4, 0x1E5, 0x1E6, 0x1E7, 0x1CE, 0x1CF, 0x1C6, 0x1C7])
G_CLIFF = set()
for a, b in ((0x068, 0x06D), (0x070, 0x07D), (0x080, 0x084), (0x088, 0x08C), (0x090, 0x094), (0x09B, 0x09E),
             (0x0A2, 0x0A4), (0x0A8, 0x0AC), (0x0B4, 0x0B7), (0x0E0, 0x0E2), (0x175, 0x17F), (0x182, 0x184)):
    span(G_CLIFF, a, b)
G_CLIFF.update([0x0A0, 0x0BD, 0x0BE, 0x0E4, 0x0E7, 0x0EE, 0x0EF, 0x158, 0x15C, 0x187, 0x1EE, 0x1EF, 0x1F0, 0x1F1])
G_HAND_BUILDING = set()
for a, b in ((0x008, 0x00C), (0x010, 0x014), (0x018, 0x01A), (0x020, 0x022), (0x028, 0x02B), (0x030, 0x033),
             (0x038, 0x03B), (0x040, 0x043), (0x048, 0x04B), (0x050, 0x053), (0x058, 0x05B), (0x060, 0x063),
             (0x130, 0x132), (0x1C0, 0x1C5), (0x1C8, 0x1CD), (0x1AA, 0x1AC), (0x1B2, 0x1B4), (0x1B8, 0x1BC)):
    span(G_HAND_BUILDING, a, b)
G_HAND_ROOF = set(); G_HAND_WALL = set()
for a, b in ((0x008, 0x00A), (0x010, 0x012), (0x028, 0x02B), (0x030, 0x033), (0x048, 0x04B), (0x050, 0x053),
             (0x130, 0x132), (0x1AA, 0x1AC), (0x1B2, 0x1B4)):
    span(G_HAND_ROOF, a, b)
for a, b in ((0x018, 0x01A), (0x020, 0x022), (0x00B, 0x00C), (0x013, 0x014), (0x038, 0x03B), (0x040, 0x043),
             (0x058, 0x05B), (0x060, 0x063), (0x1C0, 0x1C5), (0x1C8, 0x1CD), (0x1B8, 0x1BC)):
    span(G_HAND_WALL, a, b)
G_MISC = set([0x003, 0x01B, 0x004, 0x0C7, 0x193, 0x0C6, 0x0CD, 0x18C, 0x194, 0x06E])
G_GROUND = set([0x000, 0x001, 0x002, 0x005, 0x006, 0x007, 0x00D, 0x015, 0x11C, 0x121, 0x201])
for a, b in ((0x100, 0x102), (0x108, 0x10A), (0x110, 0x112), (0x1D0, 0x1D2), (0x1D8, 0x1DA), (0x1E0, 0x1E2), (0x118, 0x12A), (0x13D, 0x13E)):
    span(G_GROUND, a, b)
CAVE_SECONDARIES = set(['cave', 'meteor_falls', 'rusturf_tunnel', 'mirage_tower', 'navel_rock', 'underwater'])

# --- atlas pixels -----------------------------------------------------------
class Atlas:
    def __init__(self, pair):
        d = os.path.join(W_DIR, 'atlases', pair)
        self.ok = os.path.exists(os.path.join(d, 'meta.json'))
        if not self.ok:
            return
        m = json.load(open(os.path.join(d, 'meta.json')))
        self.cols, self.rows = m['cols'], m['rows']
        self.w, self.h = self.cols * 16, self.rows * 16
        self.u = open(os.path.join(d, 'atlas_u.rgba'), 'rb').read()
        p = os.path.join(d, 'atlas_o.rgba'); self.o = open(p, 'rb').read() if os.path.exists(p) else None
        self.slot = {int(x): i for i, x in enumerate(open(os.path.join(d, 'ids.txt')).read().split())}
        self.cache = {}
    def stats(self, mid):
        """mean r,g,b and fraction of 'ground-coloured' pixels for one metatile"""
        if not self.ok or mid not in self.slot:
            return None
        if mid in self.cache:
            return self.cache[mid]
        s = self.slot[mid]; x0, y0 = (s % self.cols) * 16, (s // self.cols) * 16
        r = g = b = 0; n = 0; dark = 0
        for y in range(16):
            for x in range(16):
                o = ((y0 + y) * self.w + x0 + x) * 4
                pr, pg, pb, pa = self.u[o], self.u[o+1], self.u[o+2], self.u[o+3]
                if self.o is not None and self.o[o+3]:
                    k = self.o[o+3] / 255.0
                    pr, pg, pb = int(self.o[o]*k + pr*(1-k)), int(self.o[o+1]*k + pg*(1-k)), int(self.o[o+2]*k + pb*(1-k))
                r += pr; g += pg; b += pb; n += 1
                if pr + pg + pb < 60:
                    dark += 1
        st = (r // n, g // n, b // n, dark / float(n))
        self.cache[mid] = st
        return st

def colour_kind(st):
    if st is None:
        return 'rock'
    r, g, b = st[0], st[1], st[2]
    if g > r + 12 and g > b + 12:
        return 'shrub'
    if r >= g >= b and r - b > 25:
        return 'brown'
    return 'rock'

# --- votes --------------------------------------------------------------------
outdoor = collections.defaultdict(lambda: collections.defaultdict(collections.Counter))   # pair -> mid -> kind -> n
outdoor_floor = collections.defaultdict(collections.Counter)                               # pair -> walkable mid -> n
general_extra = collections.defaultdict(collections.Counter)                                # mid -> kind -> n
interior = collections.defaultdict(lambda: {'walls': collections.Counter(), 'props': collections.Counter(), 'floor': collections.Counter(), 'kind': {}})
atlases = {}

def atlas(pair):
    if pair not in atlases:
        atlases[pair] = Atlas(pair)
    return atlases[pair]

BOXES = []
def classify_outdoor(m):
    pair = m['pair']; beh = behaviors.get(pair, {}); W, H = m['w'], m['h']
    sec = pair.split('__', 1)[1]
    cells = m['cells']
    def at(x, y):
        if 0 <= x < W and 0 <= y < H:
            v = cells[y * W + x]; return v & 0x3FF, bool((v >> 10) & 3)
        return None, None
    def general_known(mid):
        return mid < 0x200 and (mid in G_TREE or mid in G_CLIFF or mid in G_MISC or mid in G_GROUND)
    def candidate(x, y):
        mid, blocked = at(x, y)
        if mid is None or not blocked:
            return False
        b = beh.get(mid)
        if b in B['WATER'] or b in B['RAILS'] or b in B['JUMP'] or b == B['MOUNTAIN_TOP']:
            return False
        if general_known(mid):
            return False
        return True
    used = set()
    walkable_count = {}
    for v in cells:
        if not (v >> 10) & 3:
            walkable_count[v & 0x3FF] = walkable_count.get(v & 0x3FF, 0) + 1
    for v in cells:
        # the tileset's ground is LAND: on a sea map the commonest walkable tile
        # is water, and a sign or flower standing on a square of sea is wrong
        if not (v >> 10) & 3 and beh.get(v & 0x3FF) not in B['WATER'] and beh.get(v & 0x3FF) not in B['JUMP'] and beh.get(v & 0x3FF) != B['MOUNTAIN_TOP']:
            outdoor_floor[pair][v & 0x3FF] += 1
    # 1. buildings from doors
    # A building is a BOX standing on its door row. The facade's width is the
    # run of building cells along the door row; the box rises row by row while
    # most of that width is still building; each row may then be wider than
    # the door row (a gym's entrance bay is narrower than its hall, the Battle
    # Dome's wings stand either side of its porch). Tiles the hand tables
    # already name are part of the box but keep their hand classification, and
    # decide their whole row (so one row is never half roof, half wall).
    A0 = atlas(pair)
    def hand(mid):
        return 'roof' if mid in G_HAND_ROOF else 'wall' if mid in G_HAND_WALL else None
    for y in range(H):
        for x in range(W):
            mid, blocked = at(x, y)
            b = beh.get(mid)
            if b != B['WARP_DOOR']:  # CAVE_DOOR tiles are cave exits, not buildings
                continue
            if (x, y) in used:
                continue
            def part(cx, cy):
                if (cx, cy) == (x, y): return True
                if (cx, cy) in used: return False
                m2, blk = at(cx, cy)
                if m2 is None: return False
                return candidate(cx, cy) or (blk and hand(m2) is not None)
            x0 = x
            while part(x0 - 1, y): x0 -= 1
            x1 = x
            while part(x1 + 1, y): x1 += 1
            if x1 - x0 < 1 or x1 - x0 > 17:
                continue
            top = y
            while y - (top - 1) <= 11:
                n = sum(1 for cx in range(x0, x1 + 1) if part(cx, top - 1))
                if n * 10 < (x1 - x0 + 1) * 6:
                    break
                top -= 1
            if top == y:
                continue
            rows = {}
            for cy in range(top, y + 1):
                lo, hi = x0, x1
                while x0 - (lo - 1) <= 4 and part(lo - 1, cy): lo -= 1
                while (hi + 1) - x1 <= 4 and part(hi + 1, cy): hi += 1
                rows[cy] = [cx for cx in range(lo, hi + 1) if part(cx, cy)]
            # a bay row narrower than the hall above it stands on the row above
            bx0 = min(min(r) for r in rows.values()); bx1 = max(max(r) for r in rows.values())
            comp = set((cx, cy) for cy, r in rows.items() for cx in r)
            if not comp:
                continue
            def rowcol(r):
                st = [A0.stats(at(cx, cy)[0]) for (cx, cy) in comp if cy == r]
                st = [q for q in st if q]
                if not st:
                    return None
                return tuple(sum(c[i] for c in st) // len(st) for i in range(3))
            def dist(a, b):
                return None if a is None or b is None else sum(abs(a[i] - b[i]) for i in range(3))
            BOXES.append(dict(map=m['id'], door=[x, y], box=[bx0, top, bx1, y], rows={str(k): [min(v), max(v)] for k, v in rows.items()}))
            bottom = y
            # A facade that runs off the top of the map shows no roof at all
            # (Lilycove's Department Store): every row is wall.
            if top == 0:
                wall_top = 0
            else:
                wall_top = bottom - 1
                ref = rowcol(bottom - 1) or rowcol(bottom)
                r = bottom - 2
                while r > top:
                    d = dist(rowcol(r), ref)
                    if d is None or d > 45:
                        break
                    wall_top = r; r -= 1
            for cy, r in rows.items():
                votes = collections.Counter(hand(at(cx, cy)[0]) for cx in r)
                votes.pop(None, None)
                kind = votes.most_common(1)[0][0] if votes else ('wall' if cy >= wall_top else 'roof')
                for cx in r:
                    mid, _ = at(cx, cy)
                    if hand(mid) is None:
                        (outdoor[pair][mid] if mid >= 0x200 else general_extra[mid])[kind] += 1
                    used.add((cx, cy))
            # the roof's back row, drawn over the cells behind the building
            ref_top = rowcol(top)
            for cx in rows[top]:
                mid, blocked = at(cx, top - 1)
                if mid is None or (cx, top - 1) in used or mid in G_GROUND or general_known(mid) or hand(mid):
                    continue
                if not blocked and walkable_count.get(mid, 0) > 12:
                    continue
                if beh.get(mid) in B['WATER'] or beh.get(mid) in B['JUMP'] or beh.get(mid) == B['TALL_GRASS']:
                    continue
                st = A0.stats(mid)
                if not st or ref_top is None or sum(abs(st[i] - ref_top[i]) for i in range(3)) > 70:
                    continue
                (outdoor[pair][mid] if mid >= 0x200 else general_extra[mid])['roof'] += 1
    # 2. leftovers
    A = atlas(pair)
    # blobs of remaining candidates for cliff sizing
    seen = set()
    for y in range(H):
        for x in range(W):
            if (x, y) in used or (x, y) in seen or not candidate(x, y):
                continue
            comp = set(); stack = [(x, y)]
            while stack:
                cx, cy = stack.pop()
                if (cx, cy) in comp or (cx, cy) in used or not candidate(cx, cy):
                    continue
                comp.add((cx, cy))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    stack.append((cx + dx, cy + dy))
            seen |= comp
            for (cx, cy) in comp:
                mid, _ = at(cx, cy)
                if sec in CAVE_SECONDARIES:
                    kind = 'caveWall'
                else:
                    ck = colour_kind(A.stats(mid))
                    kind = 'cliff' if (ck == 'brown' and len(comp) >= 6) else ('rock' if ck == 'brown' else ck)
                (outdoor[pair][mid] if mid >= 0x200 else general_extra[mid])[kind] += 1

def classify_interior(m):
    pair = m['pair']; beh = behaviors.get(pair, {}); W, H = m['w'], m['h']
    sec = pair.split('__', 1)[1]
    cells = m['cells']; rec = interior[sec]
    A = atlas(pair)
    def blocked_at(x, y):
        if 0 <= x < W and 0 <= y < H:
            v = cells[y * W + x]
            return bool((v >> 10) & 3) and not is_warpish(beh.get(v & 0x3FF))
        return False
    # Room dividers: a horizontal run of five or more blocked cells below the
    # north wall is a wall, not a row of furniture.
    divider = set()
    for y in range(2, H):
        x = 0
        while x < W:
            if blocked_at(x, y):
                x0 = x
                while x < W and blocked_at(x, y):
                    x += 1
                if x - x0 >= 5:
                    divider.update((xx, y) for xx in range(x0, x))
            else:
                x += 1
    for y in range(H):
        for x in range(W):
            v = cells[y * W + x]; mid, blocked = v & 0x3FF, bool((v >> 10) & 3)
            b = beh.get(mid)
            if not blocked:
                rec['floor'][mid] += 1
                continue
            if is_warpish(b):
                continue
            st = A.stats(mid)
            dark = st is not None and (st[0] + st[1] + st[2] < 75 or st[3] > 0.25)   # void / shadow art: never stand it up
            if y <= 1 or (x, y) in divider:
                if not dark:
                    rec['walls'][mid] += 1
            elif dark:
                continue
            elif b == B['COUNTER']:
                rec['props'][(mid, 'bin', 12)] += 1
            else:
                rec['props'][(mid, 'relief', 18)] += 1

for m in maps:
    fam = m['pair'].split('__', 1)[0]
    if fam == 'general':
        classify_outdoor(m)
    else:
        classify_interior(m)

# --- emit ---------------------------------------------------------------------
def hexlist(ids):
    return ','.join('0x%03X' % i for i in sorted(ids))

lines = ['-- GENERATED by tools/gen_emerald_tables.py from the imported Emerald maps.',
         '-- Per-pair majority votes: buildings from door anchors, props from pixels.',
         '-- Hand-authored tables in Gen3EmeraldShapes.lua / Gen3EmeraldInteriors.lua win.',
         'return {', ' outdoor={']
for pair in sorted(outdoor):
    kinds = collections.defaultdict(set)
    for mid, votes in outdoor[pair].items():
        kind, _ = votes.most_common(1)[0]
        kinds[kind].add(mid)
    sec = pair.split('__', 1)[1]
    lines.append("  ['%s']={floor=0x%03X," % (sec, outdoor_floor[pair].most_common(1)[0][0]))
    for kind in ('roof', 'wall', 'cliff', 'caveWall', 'rock', 'shrub'):
        if kinds.get(kind):
            lines.append('   %s={%s},' % (kind, hexlist(kinds[kind])))
    lines.append('  },')
lines.append(' },')
gk = collections.defaultdict(set)
for mid, votes in general_extra.items():
    if mid in G_HAND_BUILDING:
        continue
    kind, _ = votes.most_common(1)[0]
    gk[kind].add(mid)
lines.append(' general={')
for kind in ('roof', 'wall', 'cliff', 'rock', 'shrub'):
    if gk.get(kind):
        lines.append('  %s={%s},' % (kind, hexlist(gk[kind])))
lines.append(' },')
lines.append(' interiors={')
for sec in sorted(interior):
    rec = interior[sec]
    if not rec['floor']:
        continue
    floor = rec['floor'].most_common(1)[0][0]
    walls = set(rec['walls'])
    props = [k for k in rec['props'] if k[0] not in walls]
    lines.append("  ['%s']={floor=0x%03X,walls={%s},props={%s}}," % (
        sec, floor, hexlist(walls),
        ','.join("{0x%03X,'%s',%d}" % p for p in sorted(props))))
lines.append(' },')
lines.append('}')
open(OUT, 'w').write('\n'.join(lines) + '\n')
print('outdoor pairs:', len(outdoor), 'general extra mids:', sum(len(v) for v in gk.values()), 'interiors:', len(interior))
for pair in sorted(outdoor):
    c = collections.Counter(votes.most_common(1)[0][0] for votes in outdoor[pair].values())
    print('  %-28s %s' % (pair, dict(c)))
json.dump(BOXES, open(os.path.join(W_DIR, 'gen_boxes.json'), 'w'))
