#!/usr/bin/env python3
"""Emerald 3DS's terrace counting, ported to our map cache (offline only).

Port of 3ds_port/scripts/voxel_terraces.py and the ledge berms of
gen_voxel_relief.py (Emerald 3DS, commit b98cc23, MIT - see NOTICE.md).
Their method in one line: the General tileset draws a mountain with square
pieces that each span exactly one level (16 px), so a mountain's heights are
counted, not solved:

1. each cell is read off its pixels: ground, top (rim), rock, or unknown
   (trees, props), with bands (the west / east slopes) by a tile table;
2. every column of rock between two flat cells, and every row of bands,
   votes how many levels the upper flat stands over the lower; terraces are
   the flats joined like to like (union-find); levels are taken greatest
   vote first, a vote that contradicts what is decided is dropped;
3. each rock cell hangs from its upper level U;
4. each cell becomes one piece - F (top), S (south face), W/E (bands),
   corner pieces - settled together so neighbours meet without cracks;
5. heights live on a 5 x 5 lattice per 16 px cell (piece_grid), and a
   point of the art at height h is placed at (u, h, v + h): at 45 degrees
   the result is the drawing.

Departures from the original (all marked "ours" in the code):
- one map at a time (3DS solves maps drawn across a seam on one canvas and
  lifts blocks to its world solve; here each block's biggest ground is 0);
- no props (voxel_props), so modelled boulders read as their drawing;
- Fallarbor's brown terrace (0x268-0x27A), which 3DS's tables do not know,
  is read as General face tiles (OWN_TWINS) so it gets counted at all;
- signposts are read from sign events only (3DS also reads lamps).
- not ported: cut tiles, records (cliff-wall flags), the seam/world anchors.

    python3 terraces.py Route114 [Route111 ...] [--out DIR]
writes DIR/<Map>.json: per-cell 5x5 lattice heights (pixels), pieces,
kinds, and the tile ids the renderer needs.
"""
import argparse
import collections
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import emdata as E  # noqa: E402

LEVEL = 16
N = 4                       # lattice steps per cell side (5 x 5 points)
STEP = 16 // N
PER_CELL = N

# -- tables (gen_voxel_relief.py 620-651, voxel_terraces.py 76-108) ----------

ROCK_TOP = {E.t5(c) for c in ((0xde, 0xb4, 0xa4), (0xbd, 0x94, 0x8b))}
ROCK_RIM = {E.t5((0xee, 0xd5, 0xcd))}
ROCK_FACE = {E.t5(c) for c in ((0x83, 0x5a, 0x5a), (0x62, 0x41, 0x52), (0x41, 0x31, 0x41))}
ROCK_FLECK = {E.t5((0x9c, 0x73, 0x73))}
ROCK_ALL = ROCK_TOP | ROCK_RIM | ROCK_FACE | ROCK_FLECK
TOP_COLOURS = ROCK_TOP | ROCK_RIM
FACE_COLOURS = ROCK_FACE
FLECK = ROCK_FLECK
DIRT = {0x113, 0x114, 0x115, 0x14b, 0x14c, 0x14d}
BOULDER = {0x93, 0x94, 0x9b, 0x9c}
BOULDER_HEADS = {0x93: 0x9b, 0x94: 0x9c}
SIDE_WEST = {0x070, 0x073}
SIDE_EAST = {0x072, 0x075, 0x0a2}
SEA_CAPS = {0x172, 0x174}
FACE_SOUTH = {0x07c, 0x0a9, 0x09f, 0x0a7, 0x091, 0x079, 0x1b0, 0x0af, 0x0cf,
              0x1f0, 0x1f1, 0x33b, 0x33c}
ROCK_TILES = ({0x070, 0x072, 0x073, 0x074, 0x075, 0x07b, 0x07c, 0x07d, 0x089, 0x0a9}
              | FACE_SOUTH | SIDE_WEST | SIDE_EAST)
ALIAS_ROLES = ROCK_TILES | SIDE_WEST | SIDE_EAST | SEA_CAPS | BOULDER

BAND_WEST = {0x070, 0x073, 0x088, 0x06b, 0x080, 0x083, 0x068,     # high side east
             0x172, 0x175, 0x177, 0x17a}
BAND_EAST = {0x072, 0x075, 0x0a2, 0x08a, 0x06d, 0x082, 0x084, 0x06a,  # high side west
             0x174, 0x176, 0x17c,
             0x0a4}
HEADS = {0x068: "W", 0x083: "W", 0x080: "W", 0x06a: "E", 0x084: "E", 0x082: "E"}
ON_TOP = BOULDER
BOULDER_FOOT = {0x09b, 0x09c}
BOULDER_HEAD = {0x093, 0x094}
LOOSE = {0x0df, 0x0e0, 0x0e1, 0x0e2}
CARVED_STEPS = {0x0e8, 0x0e9, 0x0ea, 0x0eb}
UPPER_END = {0x074, 0x089}
LOWER_END = {0x07d, 0x07b, 0x078, 0x092, 0x090}
MOUNTAIN = (set(range(0x064, 0x0c0)) | set(range(0x172, 0x193)) | {0x1a0, 0x1a8, 0x1b0, 0x1f0, 0x1f1}
            | FACE_SOUTH | BOULDER) - DIRT

# ours: Fallarbor's brown terrace (Route 114's north, Fallarbor Town) is no
# redrawing of the General rock, so 3DS's alias finds no twin and reads it as
# flat ground. Read as General faces it gets counted, one level a tile.
# 0x270, the dark side strip down a step's west end, reads as a band falling
# west (shaded as the General's 070 is: dark on its left) - as a face it
# was counted a level a row down whole columns of the staircase (a pillar).
# 0x26A over 0x27A is a diagonal edge drawn as face ends (Fallarbor's
# terrace turning south-east): the General's 074 over 07d, one level a pair.
OWN_TWINS = {E.TS_FALLARBOR: {0x268: 0x07c, 0x269: 0x07c, 0x26a: 0x074,
                              0x270: 0x070, 0x278: 0x07c, 0x27a: 0x07d}}

GROUND, TOP, ROCK, UNKNOWN = "G", "T", "R", "?"
WORLD = ("world",)
MAX_FALL = 3 * 16
ANCHOR_MIN = 12

# voxel_tree.c: the General tileset's trees drawn as cards
SMALL_TRUNKS = {0x016, 0x017, 0x0C6, 0x0C7, 0x1F4, 0x1F5}
TREE_CARDS = SMALL_TRUNKS | {0x1D4, 0x1D5, 0x1D6, 0x1D7, 0x1DC, 0x1DD, 0x1DE, 0x1DF, 0x1E4, 0x1E5,
                             0x1E6, 0x1E7, 0x1EC, 0x1ED, 0x1F2, 0x1F3, 0x1FC, 0x1FD}
FACES = (0x07c, 0x0a9, 0x079, 0x091)   # a step's wall: the first face the map draws

# ledge berms (gen_voxel_relief.py)
LIP = 6
LIP_WIDTH = 8
LIP_BACK = 8


# -- 1. cells -----------------------------------------------------------------

_CLASSES = {}


def _key(art, m):
    return (art.id, isinstance(art, E.AliasArt), m)


def pixel_classes(art, m):
    """16 x 16 of 'T' (top or rim), 'F' (face) or 'G' for metatile m; a
    fleck goes with the most of its neighbours."""
    key = _key(art, m)
    if key in _CLASSES:
        return _CLASSES[key]
    img = art.colours5(m)
    cls = [["G"] * 16 for _ in range(16)]
    if m >= 0x200 and len({c for row in img for c in row}) == 1:
        if img[0][0] in FACE_COLOURS:
            cls = [["T"] * 16 for _ in range(16)]
        _CLASSES[key] = cls
        return cls
    flecks = []
    for y in range(16):
        for x in range(16):
            c = img[y][x]
            if c in TOP_COLOURS:
                cls[y][x] = "T"
            elif c in FACE_COLOURS:
                cls[y][x] = "F"
            elif c in FLECK:
                flecks.append((x, y))
    fl = set(flecks)
    for x, y in flecks:
        votes = collections.Counter(cls[ny][nx] for ny in range(max(0, y - 1), min(16, y + 2))
                                    for nx in range(max(0, x - 1), min(16, x + 2))
                                    if (nx, ny) not in fl)
        votes.pop("G", None)
        cls[y][x] = votes.most_common(1)[0][0] if votes else "T"
    _CLASSES[key] = cls
    return cls


def rim_pixels(art, m):
    img = art.colours5(m)
    return sum(1 for y in range(6) for x in range(16) if img[y][x] in ROCK_RIM)


_TWINS = {}
TWIN_MATCH = 0.85
HEAD_MATCH = 0.6


def twin(art, m):
    """The General mountain tile a map's own tile is drawn as, or m."""
    if m < 0x200:
        return m
    key = _key(art, m)
    if key not in _TWINS:
        mine = pixel_classes(art, m)
        rock = {(x, y) for y in range(16) for x in range(16) if mine[y][x] != "G"}
        best, score = m, 0.0
        general = art.primary == 'ts_083df704'
        drawing = art.colours5(m)
        exact = [r for r in sorted(MOUNTAIN) if r < 0x200 and art.colours5(r) == drawing]
        if exact and general:
            best, score = exact[0], 1.0
        elif len(rock) >= 64 and general:
            for r in sorted(MOUNTAIN):
                if r >= 0x200:
                    continue
                theirs = pixel_classes(art, r)
                both = {(x, y) for y in range(16) for x in range(16) if theirs[y][x] != "G"} | rock
                same = sum(1 for (x, y) in both if theirs[y][x] == mine[y][x]) / len(both)
                if same > score and same >= TWIN_MATCH:
                    best, score = r, same
        if best == m and hasattr(art, "own_metatile"):
            face = {(x, y) for y in range(16) for x in range(16) if mine[y][x] == "F"}
            for r in sorted(HEADS):
                cls = pixel_classes(art, r)
                theirs = {(x, y) for y in range(16) for x in range(16) if cls[y][x] == "F"}
                same = len(face & theirs) / float(len(face | theirs) or 1)
                if same > score and same >= HEAD_MATCH:
                    best, score = r, same
        _TWINS[key] = best
    return _TWINS[key]


def terrace_art(layout):
    """The drawing as the terraces read it: the alias reading of a
    Fallarbor / Lavaridge map (3DS: gr.terrace_art), plus OWN_TWINS (ours)."""
    a = E.alias_of(layout, ALIAS_ROLES, BOULDER_HEADS)
    own = OWN_TWINS.get(layout.secondary, {})
    if own:
        alias, back, colour = a if a else ({}, {}, {})
        used = {layout.metatile(x, y) for y in range(layout.h) for x in range(layout.w)}
        for m, g in own.items():
            if m in used and m not in alias:
                alias[m] = g
                back.setdefault(g, m)
        a = (alias, back, colour) if alias else None
    return E.AliasArt(layout, a) if a else E.LayoutArt(layout)


class Cells:
    """What each cell of a map is drawn as (voxel_terraces.Cells, one map)."""

    def __init__(self, layout):
        self.layout = layout
        lid = layout.id
        self.members = [(lid, 0, 0)]
        self.id = lid
        art = terrace_art(layout)
        self.arts = {lid: art}
        self.roles_of = {lid: layout}
        self.src = {}
        self.kind, self.band, self.rim = {}, {}, set()
        self.ledges, self.keep = set(), set()
        self.props = set()
        self.prop_of = {}
        self.walked_tops = set()
        self._over_water = {}
        self.bridge_codes = E.BRIDGES
        self.bridges = set()
        self.falls = set()
        self.puddles = set()
        self.mud = E.MB['MUDDY_SLOPE']
        roles = layout
        ledges = E.ledge_cells(layout)
        self.ledge_dirs = ledges
        for y in range(art.h):
            for x in range(art.w):
                cell = (x, y)
                self.src[cell] = (lid, x, y)
                m = art.metatile(x, y)
                b = roles.behaviour(x, y)
                if cell in ledges:
                    self.ledges.add(cell)
                if b in self.bridge_codes:
                    self.bridges.add(cell)
                if b == E.MB['WATERFALL']:
                    self.falls.add(cell)
                if b == E.MB['PUDDLE']:
                    self.puddles.add(cell)
                if cell in ledges or b == E.MB['BERRY_TREE_SOIL'] or m in DIRT:
                    self.keep.add(cell)
                self._read(cell, art, roles, m, cell in ledges, False)
                if cell in self.keep and self.kind[cell] == ROCK:
                    self.kind[cell] = GROUND
                    self.band.pop(cell, None)
                    self.rim.discard(cell)
        # a walkway of treads across the water: a deck, level with its banks
        for cell in sorted(self.kind):
            if self.role(cell) != "stair" or cell in self.bridges:
                continue
            x, y = cell
            reach = {}
            for side in (-1, 1):
                for d in (1, 2, 3):
                    n = (x + side * d, y)
                    if self.water(n):
                        reach[side] = d
                        break
                    if n not in self.src or self.role(n) not in ("floor", "stair"):
                        break
            if len(reach) == 2:
                for side, d in reach.items():
                    for k in range(d):
                        n = (x + side * k, y)
                        self.bridges.add(n)
                        self.kind[n] = GROUND
                        self.band.pop(n, None)
        self.lone_bridge = {b for b in self.bridges
                            if (b[0] - 1, b[1]) not in self.bridges and (b[0] + 1, b[1]) not in self.bridges}
        self.bridges -= self.lone_bridge
        self.cheeks = set()
        for cell, k in list(self.kind.items()):
            if k != GROUND or self.role(cell) == "floor":
                continue
            x, y = cell
            if not any(self.kind.get(n) == ROCK and self.is_stair(n) for n in ((x - 1, y), (x + 1, y))):
                continue
            cls = pixel_classes(self.art(cell), self.metatile(cell))
            if sum(r.count("F") + r.count("T") for r in cls) >= 0.4 * 256:
                self.kind[cell] = ROCK
                self.cheeks.add(cell)
        self.wide_boulder = set()
        for (x, y), k in list(self.kind.items()):
            if self.metatile((x, y)) != 0x093:
                continue
            e = x + 1
            while (e, y) in self.src and self.metatile((e, y)) not in BOULDER_HEAD | BOULDER_FOOT:
                e += 1
            ends = [((e, y), 0x094), ((x, y + 1), 0x09b), ((e, y + 1), 0x09c)]
            if e == x + 1 or any(c not in self.src or self.metatile(c) != m for c, m in ends):
                continue
            middle = [(i, j) for i in range(x + 1, e) for j in (y, y + 1)]
            if all(self.kind.get(c) in (TOP, ROCK) for c in middle):
                whole = [(i, j) for i in range(x, e + 1) for j in (y, y + 1)]
                for c in whole:
                    self.kind[c] = TOP
                    self.rim.discard(c)
                self.wide_boulder.update(whole)
        xs = [x for x, _ in self.src]
        ys = [y for _, y in self.src]
        self.xs = range(min(xs), max(xs) + 1)
        self.ys = range(min(ys), max(ys) + 1)

    def _read(self, cell, art, roles, m, ledge, prop):
        lx, ly = self.src[cell][1:]
        cls = pixel_classes(art, m)

        def rock_beside():
            for nx in (lx - 1, lx + 1):
                if 0 <= nx < art.w:
                    nc = pixel_classes(art, art.metatile(nx, ly))
                    if sum(r.count("F") + r.count("T") for r in nc) >= 128:
                        return True
            return False
        own = art.own_metatile(lx, ly) if hasattr(art, "own_metatile") else m
        if not (m >= 0x200 and (lx, ly) in roles.warps) or rock_beside():
            m = twin(art, m)
        t = sum(r.count("T") for r in cls) / 256.0
        f = sum(r.count("F") for r in cls) / 256.0
        role = roles.role_at(lx, ly)
        alien = hasattr(art, "own_metatile") and m >= E.NUM_PRIMARY and m not in MOUNTAIN
        if hasattr(art, "own_metatile") and own >= E.NUM_PRIMARY and role == "floor":
            alien = True
            if m in MOUNTAIN and f < 0.08 and t >= 0.45:
                self.walked_tops.add(cell)
        tree = role == "tree" and not (m in MOUNTAIN and t + f >= 0.25)
        if prop:
            self.props.add(cell)
        if tree or prop or m in LOOSE:
            k = UNKNOWN
        elif (m in HEADS and not ledge and ly + 1 < art.h and self._top_tile(art, art.metatile(lx, ly + 1))
              and not (hasattr(art, "own_metatile") and rim_pixels(art, art.metatile(lx, ly + 1)) >= 3)):
            k = TOP
        elif (m in BAND_WEST or m in BAND_EAST) and not ledge:
            k = ROCK
            self.band[cell] = "W" if m in BAND_WEST else "E"
        elif ledge or role in ("water", "ledge") or cell in self.bridges:
            k = GROUND
        elif ((role == "stair" or roles.behaviour(lx, ly) == self.mud
               or (role == "floor" and art.metatile(lx, ly) in CARVED_STEPS))
              and self._in_face(art, lx, ly)):
            k = ROCK
        elif role == "floor" and m in MOUNTAIN and f >= 0.5 and not alien:
            k = ROCK if (lx, ly) in roles.warps else TOP
        elif role == "floor" and m in MOUNTAIN and f < 0.08 and t >= 0.45 and not alien:
            k = TOP
        elif role in ("floor", "stair", "signpost") or (m not in MOUNTAIN and t + f < 0.9) or alien:
            k = GROUND
        elif m in BOULDER_FOOT and ly > 0 and twin(art, art.metatile(lx, ly - 1)) in BAND_WEST | BAND_EAST:
            k = ROCK
        elif m in ON_TOP:
            k = TOP
        elif t + f < 0.25:
            k = GROUND
        elif f < 0.08 and t >= 0.45:
            k = TOP
        else:
            k = ROCK
        self.kind[cell] = k
        if k in (TOP, ROCK) or cell in self.walked_tops:
            g_top = sum(1 for yy in range(4) for xx in range(16) if cls[yy][xx] == "G")
            if rim_pixels(art, m) >= 3 or g_top >= 12:
                self.rim.add(cell)

    def art(self, cell):
        return self.arts[self.src[cell][0]]

    def is_stair(self, cell):
        return self.role(cell) == "stair" or (self.kind.get(cell) == ROCK
                                             and self.metatile(cell) in CARVED_STEPS)

    def on_top(self, cell):
        return self.metatile(cell) in ON_TOP and cell not in self.wide_boulder

    def at_edge(self, cell):
        lid, x, y = self.src[cell]
        art = self.arts[lid]
        return x in (0, art.w - 1) or y in (0, art.h - 1)

    def metatile(self, cell):
        lid, x, y = self.src[cell]
        return self.arts[lid].metatile(x, y)

    def own_metatile(self, cell):
        lid, x, y = self.src[cell]
        return self.layout.metatile(x, y)

    def role_id(self, cell):
        lid, x, y = self.src[cell]
        return twin(self.arts[lid], self.arts[lid].metatile(x, y))

    def role(self, cell):
        if cell in getattr(self, "puddles", ()):
            return "floor"
        lid, x, y = self.src[cell]
        return self.roles_of[lid].role_at(x, y)

    def water(self, cell):
        if cell not in self.src:
            return False
        if self.role(cell) == "water" or cell in getattr(self, "lone_bridge", ()):
            return True
        if cell not in self._over_water:
            self._over_water[cell] = self.crown(cell) and any(
                self._lower(cell) == self._lower(n) for n in self._four(cell)
                if n in self.src and self.role(n) == "water")
        return self._over_water[cell]

    def _four(self, cell):
        x, y = cell
        return ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))

    def _lower(self, cell):
        return self.layout.art.lower(self.own_metatile(cell)).tobytes()

    def crown(self, cell):
        """The top of a tree drawn over what is behind it."""
        if cell not in self.src:
            return False
        lid, x, y = self.src[cell]
        roles = self.roles_of[lid]
        if y + 1 >= roles.h or roles.role_at(x, y) == "tree" or roles.role_at(x, y + 1) != "tree":
            return False
        m = roles.metatile(x, y)
        hi = roles.art.image(m).astype(int)
        lo = roles.art.lower(m)
        lo_rgb = lo[..., :3].astype(int) * (lo[..., 3:4] > 0)
        return int((abs(hi - lo_rgb).sum(2) > 0).sum()) >= 64

    def muddy(self, cell):
        if cell not in self.src:
            return False
        lid, x, y = self.src[cell]
        return self.roles_of[lid].behaviour(x, y) == self.mud

    def walked(self, cell):
        return cell in self.src and self.role(cell) == "floor" and cell not in getattr(self, "lone_bridge", ())

    @staticmethod
    def _top_tile(art, m):
        if twin(art, m) not in MOUNTAIN:
            return False
        cls = pixel_classes(art, m)
        return (sum(r.count("F") for r in cls) < 0.08 * 256
                and sum(r.count("T") for r in cls) >= 0.45 * 256)

    @staticmethod
    def _in_face(art, x, y):
        for nx in (x - 1, x + 1):
            if 0 <= nx < art.w:
                cls = pixel_classes(art, art.metatile(nx, y))
                if sum(r.count("F") for r in cls) >= 96:
                    return True
        return False


# -- 2. terraces and their levels ---------------------------------------------

class Offsets:
    """Union-find keeping each item's level over its root's."""

    def __init__(self):
        self.parent, self.off = {}, {}

    def find(self, a):
        if a not in self.parent:
            self.parent[a], self.off[a] = a, 0
            return a, 0
        path = []
        while self.parent[a] != a:
            path.append(a)
            a = self.parent[a]
        root = a
        total = 0
        for p in reversed(path):
            total += self.off[p]
            self.off[p] = total
            self.parent[p] = root
        return root, (self.off[path[0]] if path else 0)

    def join(self, a, b, d):
        """level(a) - level(b) = d. False when it contradicts what is known."""
        ra, oa = self.find(a)
        rb, ob = self.find(b)
        if ra == rb:
            return oa - ob == d
        self.parent[rb] = ra
        self.off[rb] = oa - ob - d
        return True


def runs_of(c):
    """[(direction, upper cell, rock cells from the upper end, lower cell)]."""
    def flat(cell):
        return c.kind.get(cell) in (TOP, GROUND)

    runs = []
    for x in c.xs:
        for y in c.ys:
            nxt = (x, y + 1)
            if not flat((x, y)) or c.kind.get(nxt) != ROCK or nxt in c.band or c.water((x, y)):
                continue
            k = 1
            while c.kind.get((x, y + 1 + k)) == ROCK and (x, y + 1 + k) not in c.band:
                k += 1
            end = (x, y + 1 + k)
            cells = [(x, y + 1 + i) for i in range(k)]
            if flat(end) and end not in c.rim:
                runs.append(("S", (x, y), cells, end))
    for y in c.ys:
        for x in c.xs:
            nxt = (x + 1, y)
            if not flat((x, y)) or nxt not in c.band:
                continue
            side = c.band[nxt]
            k = 1
            while c.band.get((x + 1 + k, y)) == side:
                k += 1
            end = (x + 1 + k, y)
            cells = [(x + 1 + i, y) for i in range(k)]
            if not flat(end):
                continue
            if side == "E" and not c.water((x, y)):
                runs.append(("E", (x, y), cells, end))
            elif side == "W" and not c.water(end):
                runs.append(("W", end, cells[::-1], (x, y)))
    return runs


def terraces(c, runs):
    """{cell: terrace id} of the tops and grounds, joined like to like."""
    uf = {}
    apart = collections.defaultdict(set)
    for _, hi, cells, lo in runs:
        apart[hi].add(lo)
        apart[lo].add(hi)
    members = {}

    def find(a):
        while uf.setdefault(a, a) != a:
            uf[a] = uf[uf[a]]
            a = uf[a]
        return a

    def join(a, b):
        ra, rb = find(a), find(b)
        if ra == rb:
            return
        ma, mb = members.get(ra, ()), members.get(rb, ())
        if any(find(o) == rb for m in ma for o in apart[m]) or \
           any(find(o) == ra for m in mb for o in apart[m]):
            return
        uf[rb] = ra
        if mb:
            members.setdefault(ra, set()).update(mb)
            members.pop(rb, None)

    for cell in apart:
        members[cell] = {cell}
    edges = []
    for (x, y), k in c.kind.items():
        if k not in (TOP, GROUND, UNKNOWN):
            continue
        find((x, y))
        for n in ((x + 1, y), (x, y + 1)):
            nk = c.kind.get(n)
            if k == TOP:
                if nk != TOP or (n[1] == y + 1 and n in c.rim):
                    continue
                if c.on_top((x, y)) != c.on_top(n):
                    continue
            elif nk not in (GROUND, UNKNOWN):
                continue
            elif n[1] == y + 1 and n in c.walked_tops and n in c.rim:
                continue
            ma, mb = c.metatile((x, y)), c.metatile(n)
            wa, wb = c.water((x, y)), c.water(n)
            if (x, y) in c.falls and n not in c.falls and n[1] == y + 1:
                continue
            if (wa and wb) or (k == GROUND and nk == GROUND and c.walked((x, y)) and c.walked(n)):
                rank = 0
            elif ma < 0x200 and mb < 0x200:
                rank = 1
            else:
                rank = 2
            if ((x, y) in c.walked_tops) != (n in c.walked_tops):
                rank = 2
            if wa != wb:
                rank += 3
            edges.append((rank, (x, y), n))
    for _, a, b in sorted(edges):
        join(a, b)
    return {cell: find(cell) for cell in uf if c.kind[cell] != UNKNOWN}


def steps(c, cells, direction):
    """The levels down a run: one a cell, but an upper face end over a lower
    one is one diagonal wall."""
    out, n = [], 0
    for i, cell in enumerate(cells):
        if direction == "S" and i > 0 and c.role_id(cells[i - 1]) in UPPER_END \
                and c.role_id(cell) in LOWER_END and out[-1] == n - 1:
            out.append(out[-1])
            continue
        out.append(n)
        n += 1
    return out, n


def solve_levels(c, comp, runs, reference=None, meets=None, blocks_out=None):
    """{terrace: level}, the votes that lost (voxel_terraces.solve_levels)."""
    runs = [r for r in runs if r[1] in comp and r[3] in comp and comp[r[1]] != comp[r[3]]]
    vote = collections.Counter()
    hidden = collections.Counter()
    for d, hi, cells, lo in runs:
        head = d != "S" and any(cell in c.rim for cell in cells)
        key = (comp[hi], comp[lo], steps(c, cells, d)[1])
        vote[key] += 1 if head else 2
        hidden[key] += d == "S" and ((c.role(lo) == "wall" and c.metatile(lo) >= 0x200)
                                     or c.kind.get((lo[0], lo[1] + 1)) == UNKNOWN)
    lip = collections.Counter()
    for cell in c.rim:
        n = (cell[0], cell[1] - 1)
        if cell in comp and n in comp and comp[cell] != comp[n] and c.src[n][0] == c.src[cell][0]:
            lip[(comp[cell], comp[n], 1)] += 1
    off = Offsets()
    dropped = []
    size = collections.Counter(comp.values())
    cells_of = collections.defaultdict(list)
    for cell, t in comp.items():
        cells_of[t].append(cell)
    kind_of = {t: c.kind[cells[0]] for t, cells in cells_of.items()}
    if reference is not None:
        for t, cells in sorted(cells_of.items()):
            if kind_of[t] != GROUND or len(cells) < ANCHOR_MIN:
                continue
            edge_ = [cell for cell in cells if c.at_edge(cell) and cell in reference
                     and (meets is None or meets.get(cell, (None, False))[1])]
            if len(edge_) < 2:
                continue
            got = collections.Counter(LEVEL * round(reference[cell] / LEVEL) for cell in cells
                                      if cell in reference and cell not in c.keep)
            if got:
                off.join(WORLD, t, -got.most_common(1)[0][0])

    def across(a, b):
        return c.src[a][0] != c.src[b][0]

    def weight(key, n):
        w = n * (0.5 if across(key[0], key[1]) else 1.0)
        if hidden[key] * 2 >= n:
            w *= 0.25
        return w

    for (a, b, k), n in sorted(vote.items(), key=lambda kv: (-weight(kv[0], kv[1]), kv[0][2],
                                                             kv[0][0], kv[0][1])):
        if not off.join(a, b, k * LEVEL):
            dropped.append(((a, b, k), n))
    for (a, b, k), n in sorted(lip.items(), key=lambda kv: (-kv[1], kv[0])):
        off.join(a, b, k * LEVEL)
    roots = collections.defaultdict(list)
    for t in set(comp.values()):
        roots[off.find(t)[0]].append(t)
    level = {}
    world_root = off.find(WORLD)[0]
    for r, members in roots.items():
        if blocks_out is not None:
            blocks_out.update((t, r) for t in members)
        rel = {t: off.find(t)[1] for t in members}
        grounds = [t for t in members if kind_of[t] == GROUND]
        lift = None
        if r == world_root:
            lift = -off.find(WORLD)[1]
        elif reference is not None:
            diffs = collections.Counter()
            for t in (grounds or members):
                for cell in cells_of[t]:
                    if cell in reference and cell not in c.keep:
                        diffs[LEVEL * round((reference[cell] - rel[t]) / LEVEL)] += 1
            if diffs:
                lift = max(diffs.items(), key=lambda kv: (kv[1], -abs(kv[0])))[0]
        if lift is None:
            ref = max(grounds or members, key=lambda t: (size[t], t))
            lift = -rel[ref]
        for t in members:
            level[t] = rel[t] + lift
    return level, dropped


# -- 3. the level each rock cell hangs from -----------------------------------

def upper_levels(c, comp, level, runs):
    U = {}
    for side, hi, cells, lo in runs:
        if hi not in comp or lo not in comp:
            continue
        top, bottom = level[comp[hi]], level[comp[lo]]
        if top <= bottom:
            continue
        idx, _ = steps(c, cells, side)
        for i, cell in zip(idx, cells):
            u = max(top - LEVEL * i, bottom + LEVEL)
            if cell not in U or u > U[cell]:
                U[cell] = u
    crests = set()
    for y in c.ys:
        for x in c.xs:
            if (x, y) not in comp or (x + 1, y) not in c.band:
                continue
            if c.band[(x + 1, y)] != "W":
                continue
            k = 1
            while c.band.get((x + 1 + k, y)) == "W":
                k += 1
            if c.band.get((x + 1 + k, y)) != "E":
                continue
            j = 1
            while c.band.get((x + 1 + k + j, y)) == "E":
                j += 1
            end = (x + 1 + k + j, y)
            if end not in comp:
                continue
            lo_w, lo_e = level[comp[(x, y)]], level[comp[end]]
            crest = max(lo_w + LEVEL * k, lo_e + LEVEL * j)
            for i in range(k):
                U.setdefault((x + 1 + i, y), crest - LEVEL * (k - 1 - i))
                crests.add((x + 1 + i, y))
            for i in range(j):
                U.setdefault((x + 1 + k + i, y), crest - LEVEL * i)
                crests.add((x + 1 + k + i, y))
    for y in c.ys:
        for x in c.xs:
            if (x, y) not in comp:
                continue
            for side, stp in (("W", 1), ("E", -1)):
                k, run = 1, []
                while c.band.get((x + stp * k, y)) == side:
                    run.append((x + stp * k, y))
                    k += 1
                if run and (x + stp * k, y) not in c.src:
                    for i, cell in enumerate(run):
                        if cell not in U:
                            U[cell] = level[comp[(x, y)]] + LEVEL * (i + 1)
                            crests.add(cell)
    changed = True
    while changed:
        changed = False
        for (x, y), side in c.band.items():
            if (x, y) in U:
                continue
            for n in ((x, y - 1), (x, y + 1)):
                if c.band.get(n) == side and n in U:
                    U[(x, y)] = U[n]
                    changed = True
                    break
    todo = [cell for cell, k in c.kind.items() if k == ROCK and cell not in U]
    for _ in range(16):
        left = []
        for (x, y) in todo:
            side = c.band.get((x, y))
            high = (x - 1, y) if side == "E" else (x + 1, y) if side == "W" else (x, y - 1)
            under = 0 if side or (x, y - 1) in c.band else -LEVEL
            tiers = [[(high, 0, under)],
                     [((x - 1, y), 0, 0), ((x + 1, y), 0, 0)] + (
                         [((x, y - 1), 0, 0), ((x, y + 1), 0, 0)] if side else []),
                     [((x, y + 1), LEVEL, LEVEL)]]
            got = None
            for tier in tiers:
                cand = []
                for n, node, rock in tier:
                    if n in comp:
                        cand.append(level[comp[n]] + node)
                    elif n in U:
                        cand.append(U[n] + rock)
                if cand:
                    got = max(cand)
                    break
            if got is None:
                left.append((x, y))
            else:
                U[(x, y)] = got
        if len(left) == len(todo):
            break
        todo = left
    for cell in todo:
        U[cell] = LEVEL
    counted = {cell for _, hi, cells, lo in runs for cell in cells} | crests
    for (x, y) in [cell for cell, k in c.kind.items() if k == ROCK and cell not in counted]:
        near = [level[comp[n]] for n in ((x + dx, y + dy) for dx in (-2, -1, 0, 1, 2)
                                         for dy in (-2, -1, 0, 1, 2)) if n in comp]
        if near:
            U[(x, y)] = max(min(near), min(max(near), U[(x, y)]))
    return U


def unknown_levels(c, comp, level, U):
    """Trees, boulders, props: a patch of them stands at the lowest ground
    it can stand on (voxel_terraces.unknown_levels)."""
    out = {}
    seen = set()
    for start, k in sorted(c.kind.items()):
        if k != UNKNOWN or start in seen:
            continue
        patch, todo = [], [start]
        seen.add(start)
        while todo:
            x, y = todo.pop()
            patch.append((x, y))
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if c.kind.get(n) == UNKNOWN and n not in seen and c.prop_of.get(n) == c.prop_of.get((x, y)):
                    seen.add(n)
                    todo.append(n)
        cand, wet, feet, behind = [], [], [], []
        for (x, y) in patch:
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if n in comp:
                    (wet if c.water(n) else cand).append(level[comp[n]])
                    if n != (x, y + 1) and not c.water(n):
                        behind.append(level[comp[n]])
            if (x, y - 1) in U:
                feet.append(U[(x, y - 1)] - LEVEL)
        modelled = all(cell in c.props for cell in patch)
        if cand and modelled:
            feet = []
            if behind:
                cand = behind
        use_wet = len(wet) > len(cand) + len(feet)
        if use_wet and not modelled:
            tops = set()
            for (x, y) in patch:
                run = []
                while c.kind.get((x, y + 1 + len(run))) == ROCK and (x, y + 1 + len(run)) not in c.band:
                    run.append((x, y + 1 + len(run)))
                foot = (x, y + 1 + len(run))
                if run and foot in comp and c.kind.get(foot) in (TOP, GROUND):
                    tops.add(level[comp[foot]] + LEVEL * steps(c, run, "S")[1])
            if len(tops) == 1:
                top = tops.pop()
                for cell in patch:
                    out[cell] = top
                continue
        ground = wet if use_wet else cand
        floor = min(ground) if ground else None
        if ground and not use_wet and max(ground) - min(ground) < 0.5 and all(
                c.metatile(cell) in TREE_CARDS - SMALL_TRUNKS for cell in patch):
            for cell in patch:
                out[cell] = ground[0]
            continue
        feet = [f if floor is None else max(f, floor) for f in feet]
        cand = wet if use_wet else (cand + feet or wet)
        v = min(cand) if cand else 0
        own, spread = {}, {}
        for (x, y) in patch:
            mine = []
            in_face = (c.kind.get((x - 1, y)) == ROCK and c.kind.get((x + 1, y)) == ROCK
                       and c.kind.get((x, y + 1)) == UNKNOWN)
            top = (c.metatile((x, y)) not in TREE_CARDS and (x, y + 1) in c.src
                   and c.metatile((x, y + 1)) in SMALL_TRUNKS)
            behind_ = []
            for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if in_face and n == (x, y - 1):
                    continue
                if n in comp and c.water(n) == use_wet:
                    if top and n == (x, y - 1):
                        behind_.append(level[comp[n]])
                    else:
                        mine.append(level[comp[n]])
            if (x, y - 1) in U and (x, y - 1) not in c.band and not (modelled and mine):
                f = U[(x, y - 1)] - LEVEL
                mine.append(f if floor is None else max(f, floor))
            if mine:
                own[(x, y)] = min(mine)
            if mine or behind_:
                spread[(x, y)] = min(mine + behind_)
        if not spread or max(spread.values()) - min(spread.values()) <= LEVEL + 0.5:
            for cell in patch:
                out[cell] = v
            continue
        dist = {cell: 0 for cell in own}
        front = list(own)
        res = dict(own)
        while front:
            nxt = []
            for (x, y) in front:
                for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if c.kind.get(n) != UNKNOWN or n not in seen:
                        continue
                    d = dist[(x, y)] + 1
                    if n not in dist:
                        dist[n] = d
                        res[n] = res[(x, y)]
                        nxt.append(n)
                    elif dist[n] == d:
                        res[n] = min(res[n], res[(x, y)])
            front = nxt
        for (x, y) in sorted(patch, key=lambda cl: -cl[1]):
            if (c.metatile((x, y)) not in TREE_CARDS and (x, y + 1) in res
                    and c.metatile((x, y + 1)) in SMALL_TRUNKS):
                res[(x, y)] = res[(x, y + 1)]
        for cell in patch:
            out[cell] = res.get(cell, v)
    return out


def settle(c, U, flat, fixed):
    """Each rock cell takes the level (of its own, one up, one down) that
    leaves the most of its corners shared (voxel_terraces.settle)."""
    def options(cell):
        if cell in flat:
            return {flat[cell]}
        return {U[cell], U[cell] - LEVEL}

    def score(x, y):
        n = 0
        for gx, gy in ((x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)):
            common = None
            for cell in ((gx - 1, gy - 1), (gx, gy - 1), (gx - 1, gy), (gx, gy)):
                if cell in c.kind:
                    o = options(cell)
                    common = set(o) if common is None else common & o
            n += bool(common)
        return n

    rock = sorted(cell for cell, k in c.kind.items() if k == ROCK and cell not in c.band)
    for _ in range(8):
        moved = 0
        for cell in rock:
            here = U[cell]
            best, best_score = here, score(*cell)
            x, y = cell
            for u in (here + LEVEL, here - LEVEL):
                U[cell] = u
                sc = score(*cell)
                need = 2 if cell in fixed else 1
                held = u > here and cell not in fixed and any(
                    U.get(n) == u or flat.get(n) == u for n in ((x, y - 1), (x - 1, y), (x + 1, y)))
                if sc >= best_score + need or (sc == best_score and held):
                    best, best_score = u, sc
            U[cell] = best
            moved += best != here
        if not moved:
            break
    return U


# -- 5. pieces ------------------------------------------------------------------

FIN = 3.0
STEEP = 0.4
FACE_SHARE = 0.4
CORNERS = ("cSE", "cSW", "vSE", "vSW")
CORNER_KINDS = list(CORNERS)
CORNER = 0.3


def edge(grid, side):
    """The five heights along one edge of a cell, west to east / north to south."""
    if side == "N":
        return grid[0]
    if side == "S":
        return grid[N]
    return [grid[j][0 if side == "W" else N] for j in range(N + 1)]


def is_face(c, cell):
    if cell in c.band:
        return False
    if c.kind.get(cell) == ROCK and (c.is_stair(cell) or c.muddy(cell)):
        return True
    cls = pixel_classes(c.art(cell), c.metatile(cell))
    f = sum(row.count("F") for row in cls)
    return f >= FACE_SHARE * 256


def blocks(c, U, flat, kept=None):
    """{cell: (kind, top level)}: one piece a cell, settled together
    (voxel_terraces.blocks)."""
    out = {}
    pref = {}
    for cell in c.kind:
        if cell in flat:
            out[cell] = ("F", flat[cell])
            x, y = cell
            if c.metatile(cell) in BOULDER_HEAD:
                for n, side in (((x + 1, y), "W"), ((x - 1, y), "E")):
                    if c.kind.get(n) == TOP and flat.get(n) == flat[cell] + LEVEL:
                        out[cell] = (side, flat[n])
        elif cell in c.band:
            x, y = cell
            side = c.band[cell]
            hi, lo = ((x + 1, y), (x - 1, y)) if side == "W" else ((x - 1, y), (x + 1, y))
            if hi in flat and lo in flat and flat[hi] <= flat[lo]:
                out[cell] = ("F", flat[hi])
                continue
            pref[cell] = c.band[cell]
            out[cell] = (c.band[cell], U[cell])
        else:
            pref[cell] = "S" if is_face(c, cell) else "F"
            out[cell] = (pref[cell], U[cell])
    grid = {cell: piece_grid(*p) for cell, p in out.items()}
    kept = kept or {}
    grid.update(kept)
    trees = {cell for cell, k in c.kind.items() if k == UNKNOWN and c.role(cell) == "tree"}
    free = sorted(cell for cell in out if cell not in flat and cell not in c.keep
                  and c.kind[cell] in (ROCK, TOP))

    def step(p, q, back):
        d = abs(p - q)
        if d < 0.5:
            return 0.0
        k = 1.0 + 0.5 * (d / LEVEL - 1.0)
        if back is None:
            return 0.5 * k
        return k * (back if q > p else 1.0)

    def kind_at(n, piece):
        return piece[0] if n is None else (out[n][0] if n in out and n not in kept else "F")

    def cost(cell, g, piece):
        x, y = cell
        total = 0.0
        for n, mine, theirs, ns in (((x - 1, y), "W", "E", False), ((x + 1, y), "E", "W", False),
                                    ((x, y - 1), "N", "S", True), ((x, y + 1), "S", "N", True)):
            if n not in grid or n in trees:
                continue
            a, b = edge(g, mine), edge(grid[n], theirs)
            if n in kept and any(q - p > 0.5 for p, q in zip(a, b)):
                total += 10.0
            if mine in ("W", "N"):
                a, b = b, a
            back = None
            if not ns:
                west, east = (n, cell) if mine == "W" else (cell, n)
                kw = kind_at(west, piece) if west != cell else piece[0]
                ke = kind_at(east, piece) if east != cell else piece[0]
                kw, ke = kw[0], ke[0]
                fin = (kw == "W" and max(p - q for p, q in zip(a, b)) > 0.5) or \
                      (ke == "E" and max(q - p for p, q in zip(a, b)) > 0.5)
                if fin:
                    total += FIN
            if ns:
                north = kind_at(n, piece) if mine == "N" else piece[0]
                south = piece[0] if mine == "N" else kind_at(n, piece)
                back = 0.3 if north == "F" or (north != "S" and south == "F") else pit[0]
            total += sum(step(p, q, back) for p, q in zip(a, b)) / (N + 1)
        total += 0.25 * abs(piece[1] - U[cell]) / LEVEL
        if piece[0] in CORNERS:
            total += CORNER
        elif cell in pref and piece[0][0] != pref[cell]:
            total += 0.6
        elif piece[0] in ("W2", "E2"):
            total += STEEP
        return total

    pit = [0.3]
    for pit[0], sweeps in ((0.3, 10), (1.0, 10), (3.0, 10), (10.0, 30)):
        for _ in range(sweeps):
            moved = 0
            for cell in free:
                kind, top = out[cell]
                if cell in c.band and kind == "F":
                    continue
                kinds = [c.band[cell], c.band[cell] + "2"] if cell in c.band else ["F", "S"] + CORNER_KINDS
                tops = {U[cell] + LEVEL * k for k in (-2, -1, 0, 1, 2)} | {top}
                best, best_cost = out[cell], cost(cell, grid[cell], out[cell])
                for k2 in kinds:
                    for t in sorted(tops):
                        piece = (k2, t)
                        if piece == out[cell]:
                            continue
                        cc = cost(cell, piece_grid(*piece), piece)
                        if cc < best_cost - 1e-6:
                            best, best_cost = piece, cc
                if best != out[cell]:
                    out[cell] = best
                    grid[cell] = piece_grid(*best)
                    moved += 1
            if not moved:
                break
    for cell in sorted(out, key=lambda cl: -cl[1]):
        x, y = cell
        s = (x, y + 1)
        if c.metatile(cell) in BOULDER_HEAD and cell in flat and s in c.band and out[s][0][0] in "WE":
            out[cell] = out[s]
    return out


def split_kind(kind):
    if ":" in kind:
        k, d = kind.split(":")
        return k, float(d)
    return kind, None


def piece_grid(kind, top):
    """5 x 5 heights of a piece (voxel_terraces.piece_grid)."""
    kind, drop = split_kind(kind)
    if drop is not None:
        if kind in CORNERS:
            east = kind[2] == "E"
            pick = max if kind[0] == "c" else min
            return [[top - drop / N * pick(i if east else N - i, j) for i in range(N + 1)]
                    for j in range(N + 1)]
        if kind == "S":
            return [[top - drop * j / N] * (N + 1) for j in range(N + 1)]
        if kind == "W":
            return [[top - drop + drop * i / N for i in range(N + 1)] for _ in range(N + 1)]
        if kind == "E":
            return [[top - drop * i / N for i in range(N + 1)] for _ in range(N + 1)]
    if kind in CORNERS:
        east = kind[2] == "E"
        pick = max if kind[0] == "c" else min
        return [[top - LEVEL / N * pick(i if east else N - i, j) for i in range(N + 1)] for j in range(N + 1)]
    if kind == "S":
        return [[top - LEVEL * j / N] * (N + 1) for j in range(N + 1)]
    if kind in ("W", "W2"):
        drop = LEVEL * (2 if kind == "W2" else 1)
        return [[top - drop + drop * i / N for i in range(N + 1)] for _ in range(N + 1)]
    if kind in ("E", "E2"):
        drop = LEVEL * (2 if kind == "E2" else 1)
        return [[top - drop * i / N for i in range(N + 1)] for _ in range(N + 1)]
    return [[top] * (N + 1) for _ in range(N + 1)]


BAND_HEAD = {"E": {0x074}, "W": {0x089}}
BAND_FOOT = {"E": {0x07a, 0x07d, 0x092}, "W": {0x07b, 0x078, 0x090}}


def segments(c):
    """[(side, head or None, [band cells], foot or None)]."""
    out = []
    for (x, y), side in sorted(c.band.items()):
        if c.band.get((x, y - 1)) == side:
            continue
        cells = [(x, y)]
        while c.band.get((x, cells[-1][1] + 1)) == side:
            cells.append((x, cells[-1][1] + 1))
        head, foot = (x, y - 1), (x, cells[-1][1] + 1)
        head = head if head in c.src and c.kind.get(head) == ROCK and head not in c.band \
            and c.role_id(head) in BAND_HEAD[side] else None
        foot = foot if foot in c.src and c.kind.get(foot) == ROCK and foot not in c.band \
            and c.role_id(foot) in BAND_FOOT[side] else None
        out.append((side, head, cells, foot))
    for (x, y), k in sorted(c.kind.items()):
        if k != ROCK or (x, y) in c.band or (x, y + 1) not in c.src:
            continue
        for side in ("E", "W"):
            foot = (x, y + 1)
            low = 1 if side == "E" else -1
            if c.role_id((x, y)) in BAND_HEAD[side] and c.kind.get(foot) == ROCK \
                    and foot not in c.band and c.role_id(foot) in BAND_FOOT[side] \
                    and all(n in c.src and c.kind.get(n) != ROCK for n in ((x + low, y), (x + low, y + 1))):
                out.append((side, (x, y), [], foot))
    return out


def facing_ns(c, pieces, flat, kept, n, mine):
    if n in kept:
        return None
    if n in flat and c.kind.get(n) != ROCK:
        return [flat[n]] * (N + 1)
    p = pieces.get(n)
    return None if p is None else edge(piece_grid(*p), "S" if mine == "N" else "N")


def staircases(c, pieces, flat, kept):
    """A diagonal edge drawn as a staircase of band columns: one band a
    column (voxel_terraces.staircases)."""
    def dry(s):
        out = 1 if s[0] == "E" else -1
        return not any(c.water((cell[0] + out, cell[1])) for cell in [s[1], s[3]] + list(s[2]) if cell)
    segs = [s for s in segments(c) if dry(s) and all(cell not in c.keep and pieces.get(cell, ("",))[0] == s[0]
                                                     for cell in s[2])]

    def north_edge(n):
        if n in kept:
            return None
        if n in flat and c.kind.get(n) != ROCK:
            return [flat[n]] * (N + 1)
        p = pieces.get(n)
        return None if p is None else edge(piece_grid(*p), "S")

    def high_edge(n, side):
        if n in kept:
            return None
        if n in flat and c.kind.get(n) != ROCK:
            return [flat[n]] * (N + 1)
        p = pieces.get(n)
        if p is None:
            return None
        return edge(piece_grid(*p), "E" if side == "E" else "W")

    def facing_we(n, side):
        if n in kept:
            return None
        if n in flat and c.kind.get(n) != ROCK:
            return [flat[n]] * (N + 1)
        p = pieces.get(n)
        return None if p is None else edge(piece_grid(*p), "E" if side == "W" else "W")
    for cell, p in sorted(pieces.items()):
        if c.kind.get(cell) != ROCK or cell in c.keep or cell in kept:
            continue
        x, y = cell
        if any(c.water(n) for n in ((x - 1, y), (x + 1, y), (x, y - 1))):
            continue
        sides = [facing_we((x - 1, y), "W"), facing_we((x + 1, y), "E"),
                 facing_ns(c, pieces, flat, kept, (x, y - 1), "N")]
        if any(e is None or max(e) - min(e) > 0.5 for e in sides):
            continue
        level = sides[0][0]
        if any(abs(e[0] - level) > 0.5 for e in sides):
            continue
        if max(max(r) for r in piece_grid(*p)) > level + 0.5:
            pieces[cell] = ("F", level)
    for _ in range(4):
        moved = 0
        for side, head, cells, foot in segs:
            stp = -1 if side == "E" else 1
            votes = collections.Counter()
            ask = cells or [head]
            for cell in ask:
                n = (cell[0] + stp, cell[1])
                e = high_edge(n, side)
                if e is None or max(e) - min(e) > 0.5:
                    continue
                votes[e[0]] += 1 if c.kind.get(n) == UNKNOWN else 2
            if not cells:
                n = (head[0], head[1] - 1)
                e = north_edge(n)
                if e is not None and max(e) - min(e) <= 0.5:
                    votes[e[0]] += 1 if c.kind.get(n) == UNKNOWN else 2
            if not votes:
                continue
            top = max(votes.items(), key=lambda kv: (kv[1], kv[0]))[0]
            if cells:
                ends = []
                if head is not None:
                    e = north_edge((head[0], head[1] - 1))
                    n = (head[0], head[1] - 1)
                    if e is not None and max(e) - min(e) <= 0.5 and c.kind.get(n) != UNKNOWN:
                        ends.append(e[0] - top)
                if foot is not None:
                    n = (foot[0], foot[1] + 1)
                    if n in flat and n not in kept and c.kind.get(n) in (TOP, GROUND):
                        ends.append(flat[n] + LEVEL - top)
                if any(abs(d) > 0.5 for d in ends):
                    continue
            want = [(cell, (side, top)) for cell in cells]
            if head is not None:
                want.append((head, ("vS" + side, top)))
            if foot is not None:
                want.append((foot, ("cS" + side, top)))
            for cell, piece in want:
                if cell in kept or cell in c.keep:
                    continue
                if pieces.get(cell) != piece:
                    pieces[cell] = piece
                    moved += 1
        if not moved:
            break


def level_bands(c, pieces, flat, kept, measured=frozenset()):
    """A band (or a face) with nothing to fall lies flat; a fall shared out
    between more bands than levels (voxel_terraces.level_bands)."""
    def facing(n, side):
        if n in kept:
            return None
        if n in flat and c.kind.get(n) != ROCK:
            return [flat[n]] * (N + 1)
        p = pieces.get(n)
        return None if p is None else edge(piece_grid(*p), "E" if side == "W" else "W")

    segs = segments(c)

    def plain(cell):
        return c.kind.get(cell) == ROCK and cell not in c.band and cell not in c.keep \
            and cell not in kept and pieces.get(cell, ("",))[0] in ("S",) + tuple(CORNERS)
    for (x, y) in sorted(pieces):
        if not plain((x, y)) or (c.kind.get((x, y - 1)) == ROCK and pieces.get((x, y - 1), ("",))[0]
                                 not in CORNERS):
            continue
        if plain((x, y - 1)) and pieces[(x, y - 1)][0] not in CORNERS:
            continue
        run = [(x, y)]
        while plain((x, run[-1][1] + 1)):
            run.append((x, run[-1][1] + 1))
        below = (x, run[-1][1] + 1)
        if c.kind.get(below) == ROCK:
            continue
        if c.water((x, y - 1)) or c.water(below):
            continue
        north = facing_ns(c, pieces, flat, kept, (x, y - 1), "N")
        if c.kind.get(below) == UNKNOWN and (north is None or abs(max(
                max(r) for r in piece_grid(*pieces[run[0]])) - max(north)) <= 0.5):
            continue
        south = facing_ns(c, pieces, flat, kept, below, "S")
        if north is None or south is None or max(north) - min(north) > 0.5 \
                or max(south) - min(south) > 0.5:
            continue
        fall = (north[0] - south[0]) / LEVEL
        if abs(fall - round(fall)) > 0.01 or not 0 <= round(fall) <= len(run):
            continue
        fall = int(round(fall))
        if fall and any(pieces[cell][0] != "S" for cell in run):
            continue
        if not fall:
            if ((x, y - 1), below) in measured:
                continue
            for cell in run:
                pieces[cell] = ("F", north[0])
            continue
        for i, cell in enumerate(run):
            pieces[cell] = ("S", north[0] - LEVEL * i) if i < fall else ("F", north[0] - LEVEL * fall)

    def chains():
        moved = 0
        wants = {}
        for (x, y), side in sorted(c.band.items()):
            up = 1 if side == "W" else -1
            if c.band.get((x + up, y)) == side:
                continue
            chain = [(x, y)]
            while c.band.get((chain[-1][0] - up, y)) == side:
                chain.append((chain[-1][0] - up, y))
            if any(pieces.get(cell, ("",))[0] not in (side, "F") and split_kind(
                    pieces.get(cell, ("",))[0])[0] != side or cell in c.keep for cell in chain):
                continue
            hi_n, lo_n = (x + up, y), (chain[-1][0] - up, y)
            hi = facing(hi_n, "E" if side == "W" else "W")
            lo = facing(lo_n, "W" if side == "W" else "E")
            if hi is None or lo is None or max(hi) - min(hi) > 0.5 or max(lo) - min(lo) > 0.5:
                continue
            fall = hi[0] - lo[0]
            if fall >= LEVEL * len(chain) - 0.5:
                continue
            if fall <= 0.5:
                want = [("F", hi[0])] * len(chain)
            elif abs(fall / LEVEL - round(fall / LEVEL)) > 0.01:
                share = fall / float(len(chain))
                want = [("%s:%g" % (side, share), hi[0] - share * i) for i in range(len(chain))]
            else:
                full = int(round(fall / LEVEL))
                want = [(side, hi[0] - LEVEL * i) if i < full else ("F", hi[0] - LEVEL * full)
                        for i in range(len(chain))]
            wants[tuple(chain)] = (side, want)
        flat_at = {cell for chain, (side, want) in wants.items()
                   for cell, piece in zip(chain, want) if piece[0] == "F"}
        for chain, (side, want) in wants.items():
            if any(piece[0] == "F" and any(
                    c.band.get(n) == side and n not in flat_at and n not in c.keep
                    and split_kind(pieces.get(n, ("",))[0])[0] == side
                    for n in ((cell[0], cell[1] - 1), (cell[0], cell[1] + 1)))
                   for cell, piece in zip(chain, want)):
                continue
            for cell, piece in zip(chain, want):
                if pieces.get(cell) != piece:
                    pieces[cell] = piece
                    moved += 1
        return moved

    def ends():
        moved = 0
        for side, head, cells, foot in segs:
            if not cells:
                continue
            tops = {pieces[cell] for cell in cells if cell in pieces}
            if len(tops) == 1 and next(iter(tops))[0] == "F":
                level = next(iter(tops))[1]
                for end, beyond, mine in ((head, 0, "N"), (foot, 1, "S")):
                    if end is None or end in c.keep or end in kept:
                        continue
                    n = (end[0], end[1] - 1 if beyond == 0 else end[1] + 1)
                    e = facing_ns(c, pieces, flat, kept, n, mine)
                    if e is not None and all(abs(v - level) < 0.5 for v in e) \
                            and pieces.get(end) != ("F", level):
                        pieces[end] = ("F", level)
                        moved += 1
                continue
            for end, band, corner in ((head, cells[0], "vS"), (foot, cells[-1], "cS")):
                if end is None or end in c.keep or end in kept or band not in pieces:
                    continue
                k, share = split_kind(pieces[band][0])
                if share is None or k != side:
                    continue
                piece = ("%s%s:%g" % (corner, side, share), pieces[band][1])
                if pieces.get(end) != piece:
                    pieces[end] = piece
                    moved += 1
        return moved

    for _ in range(6):
        if not chains() + ends():
            break


def unstand(c, pieces, flat, kept):
    """A face's top edge never stands over the ground behind it
    (voxel_terraces.unstand)."""
    def nb(n, its):
        if n in kept:
            return None
        if n in flat and c.kind.get(n) != ROCK:
            return [flat[n]] * (N + 1)
        q = pieces.get(n)
        return None if q is None else edge(piece_grid(*q), its)

    def round_it(cell):
        x, y = cell
        return (((x, y - 1), "N", "S"), ((x, y + 1), "S", "N"), ((x - 1, y), "W", "E"), ((x + 1, y), "E", "W"))

    def misfit(cell, piece):
        g = piece_grid(*piece)
        total = 0.0
        for n, mine, its in round_it(cell):
            e = nb(n, its)
            if e is not None:
                total += sum(abs(a - b) for a, b in zip(edge(g, mine), e))
        return total

    for _ in range(2):
        moved = 0
        for cell, p in sorted(pieces.items()):
            if c.kind.get(cell) != ROCK or cell in c.keep or cell in kept or p[0] == "F":
                continue
            x, y = cell
            g = piece_grid(*p)
            behind_ = set()
            for back, hi, lo, its in (((x, y - 1), "N", "S", "S"), ((x + 1, y), "E", "W", "W"),
                                      ((x - 1, y), "W", "E", "E")):
                e = nb(back, its)
                if e is None:
                    continue
                top, foot = edge(g, hi), edge(g, lo)
                if sum(1 for t, f, b in zip(top, foot, e) if t - f > 0.5 and t - b > 0.5) >= 2:
                    behind_ |= {max(e), min(e)}
            if not behind_:
                continue
            kind = p[0]
            cands = [(k, lv) for lv in sorted(behind_) for k in (kind, "F")]
            best = min(cands, key=lambda q: misfit(cell, q))
            if misfit(cell, best) < misfit(cell, p) - 0.5:
                pieces[cell] = best
                moved += 1
        if not moved:
            break


def behind_trees(c, flat, grids, pieces=None):
    """A wood at a cliff's foot hides the cliff: the tree's cell lies flat on
    its ground, the face over it goes straight down (voxel_terraces)."""
    for cell in sorted(grids, key=lambda cl: (cl[1], cl[0])):
        if c.kind.get(cell) != UNKNOWN or c.role(cell) != "tree" or cell in c.keep:
            continue
        if pieces is not None and pieces.get(cell, ("F",))[0] != "F":
            continue
        x, y = cell
        north = grids.get((x, y - 1))
        if north is None or (x, y - 1) in c.keep:
            continue
        low = flat.get(cell, min(min(r) for r in grids[cell]))
        top = north[N]
        if max(top) <= low + 0.5:
            continue
        trunk = (x, y + 1)

        def face_beside(n):
            p = pieces.get(n) if pieces is not None else None
            return p is not None and (p[0] == "S" or p[0] in CORNERS) and abs(p[1] - top[0]) < 0.5
        if (pieces is not None and c.metatile(cell) not in TREE_CARDS and trunk in c.src
                and c.metatile(trunk) in SMALL_TRUNKS and max(top) - min(top) < 0.5
                and abs(top[0] - LEVEL - flat.get(trunk, low)) < 0.5
                and (face_beside((x - 1, y)) or face_beside((x + 1, y)))):
            pieces[cell] = ("S", top[0])
            grids[cell] = piece_grid("S", top[0])
            continue
        grids[cell] = [[low] * (N + 1) for _ in range(N + 1)]


def solve(layout):
    """voxel_terraces.solve for one map, no world reference."""
    c = Cells(layout)
    runs = runs_of(c)
    comp = terraces(c, runs)
    level, dropped = solve_levels(c, comp, runs, None, None)
    counted = {cell for _, hi, cells, lo in runs for cell in (hi, lo)}
    members = collections.defaultdict(list)
    for cell, t in comp.items():
        members[t].append(cell)
    for t, cells in members.items():
        if len(cells) > 4 or any(cell in counted or c.kind.get(cell) != GROUND or c.water(cell)
                                 for cell in cells):
            continue
        round_it = collections.Counter(
            level[comp[n]] for (x, y) in cells for n in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
            if n in comp and comp[n] != t and not c.water(n))
        if round_it:
            best, k = round_it.most_common(1)[0]
            if best != level[t] and 2 * k > sum(round_it.values()):
                level[t] = best
    U = upper_levels(c, comp, level, runs)
    fixed = {cell for d, hi, cells, lo in runs if hi in comp and lo in comp
             and level[comp[hi]] - level[comp[lo]] == LEVEL * steps(c, cells, d)[1] for cell in cells}
    flat = {cell: level[t] for cell, t in comp.items()}
    flat.update(unknown_levels(c, comp, level, U))
    U = settle(c, U, flat, fixed)
    for cell in sorted(c.band):
        side = c.band[cell]
        x, y = cell
        up = 1 if side == "W" else -1
        hi = (x + up, y)
        if c.band.get(hi) == side:
            continue
        chain = [cell]
        while c.band.get((chain[-1][0] - up, y)) == side:
            chain.append((chain[-1][0] - up, y))
        lo = (chain[-1][0] - up, y)
        if hi not in flat or lo not in flat or c.kind.get(hi) == ROCK or c.kind.get(lo) == ROCK:
            continue
        if abs(flat[hi] - flat[lo] - LEVEL * len(chain)) > 0.5:
            continue
        for i, b in enumerate(chain):
            U[b] = flat[hi] - LEVEL * i
    kept = {}
    pieces = blocks(c, U, flat, kept)

    def gap_cell(n, h):
        q = pieces.get(n)
        if q is None or q[0] != "F" or n in c.keep or n in c.bridges:
            return False
        k = c.kind.get(n)
        if not (k == GROUND or (k == UNKNOWN and (c.role(n) != "tree" or c.metatile(n) >= 0x200))):
            return False
        if q[1] >= h - 0.5:
            return k == GROUND
        north = pieces.get((n[0], n[1] - 1))
        return abs(q[1] - (h - LEVEL)) < 0.5 and north is not None and north[1] >= h - 0.5 \
            and c.kind.get((n[0], n[1] - 1)) != ROCK
    for (x, y), p in sorted(pieces.items(), key=lambda kv: (-kv[0][1], kv[0][0])):
        p = pieces[(x, y)]
        left = pieces.get((x - 1, y))
        if left is None or left[0] != "S":
            continue
        h = left[1]
        if not gap_cell((x, y), h):
            continue
        run = [(x, y)]
        while True:
            n = (run[-1][0] + 1, y)
            q = pieces.get(n)
            if q is None or len(run) > 6:
                run = None
                break
            if q[0] == "S" and abs(q[1] - h) < 0.5:
                break
            if not gap_cell(n, h):
                run = None
                break
            run.append(n)
        if not run:
            continue
        if all((cx, y + 1) in pieces and pieces[(cx, y + 1)][1] < h - 0.5 for cx, _ in run):
            for cell in run:
                pieces[cell] = ("S", h)
            c.cheeks.update({(x - 1, y), (run[-1][0] + 1, y)})
    for cell in sorted(c.falls):
        x, y = cell
        if (x, y - 1) in c.falls:
            continue
        run = [cell]
        while (x, run[-1][1] + 1) in c.falls:
            run.append((x, run[-1][1] + 1))
        above, below = (x, y - 1), (x, run[-1][1] + 1)
        if above not in flat or below not in flat:
            continue
        top, foot = flat[above], flat[below]
        if abs(top - foot - len(run) * LEVEL) > 0.5:
            continue
        for k, f in enumerate(run):
            pieces[f] = ("S", top - k * LEVEL)
        for side in (-1, 1):
            beside = [(f[0] + side, f[1]) for f in run]
            if all(b in pieces and c.kind.get(b) == ROCK and b not in c.keep and b not in c.band
                   for b in beside):
                for k, b in enumerate(beside):
                    pieces[b] = ("S", top - k * LEVEL)
    for _ in range(2):
        for cell, p in list(pieces.items()):
            if c.kind.get(cell) != ROCK or p[0] not in ("F", "T") or cell in c.keep:
                continue
            x, y = cell
            south = pieces.get((x, y + 1))
            for n in ((x - 1, y), (x + 1, y)):
                q = pieces.get(n)
                if q is None or q[0] not in ("F", "T") or q[1] <= p[1]:
                    continue
                if c.kind.get(n) not in (TOP, ROCK) or south is None or south[1] < q[1]:
                    continue
                pieces[cell] = ("W" if n[0] > x else "E", q[1])
                break
    for cell, p in list(pieces.items()):
        if c.kind.get(cell) != ROCK or cell in c.keep or cell in c.band:
            continue
        x, y = cell
        for inner, outer, kind in (((x + 1, y), (x - 1, y), "W"), ((x - 1, y), (x + 1, y), "E")):
            q = pieces.get(inner)
            if q is None or c.kind.get(inner) != ROCK or q[0] not in ("S", "W", "E") + tuple(CORNERS) \
                    or q[1] <= p[1]:
                continue
            if outer not in flat or c.kind.get(outer) == ROCK:
                continue
            drop = q[1] - flat[outer]
            if abs(drop - LEVEL) < 0.5:
                pieces[cell] = (kind, q[1])
            elif abs(drop - 2 * LEVEL) < 0.5:
                pieces[cell] = (kind + "2", q[1])
            break
    measured = {(hi, lo) for d, hi, cells, lo in runs if d == "S"}
    for _ in range(3):
        before = dict(pieces)
        staircases(c, pieces, flat, kept)
        level_bands(c, pieces, flat, kept, measured)
        if pieces == before:
            break
    unstand(c, pieces, flat, kept)
    grids = {cell: piece_grid(*p) for cell, p in pieces.items()}
    grids.update(kept)
    behind_trees(c, flat, grids, pieces)
    berms = ledge_berms(c, grids)
    return {"cells": c, "comp": comp, "level": level, "U": U, "flat": flat,
            "pieces": pieces, "grids": grids, "dropped": dropped, "runs": runs, "berms": berms}


# -- ledge berms (gen_voxel_relief.py ledge_berms) ------------------------------

def ledge_berms(c, grids):
    """Raise every ledge's lip off the drawing: the lip's top edge LIP px
    up, its foot on the jump side at the ground, the ground behind rising to
    it over LIP_BACK px - a low berm, not a step. Added to each ledge cell's
    own lattice (3DS adds it to one map-wide lattice)."""
    layout = c.layout
    cells = c.ledge_dirs
    if not cells:
        return 0
    lip = {}
    for (x, y), dirs in cells.items():
        ground = set()
        for ring in ([(-dx, -dy) for dx, dy in dirs] + list(dirs),
                     [(dx, dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]):
            for dx, dy in ring:
                nx, ny = x + dx, y + dy
                if (nx, ny) in cells or layout.off_map(nx, ny) or layout.blocked(nx, ny):
                    continue
                img = layout.art.colours5(layout.metatile(nx, ny))
                ground.update(v for row in img for v in row)
            if ground:
                break
        if not ground:
            continue
        img = layout.art.colours5(layout.metatile(x, y))
        for j in range(16):
            for i in range(16):
                if img[j][i] not in ground:
                    lip[(x * 16 + i, y * 16 + j)] = True

    def run(px, py, dx, dy, limit=64):
        n = 0
        while n < limit and lip.get((px + n * dx, py + n * dy)):
            n += 1
        return n

    def first(px, py, dx, dy, limit):
        for k in range(limit):
            if lip.get((px + k * dx, py + k * dy)):
                return k
        return None

    def lip_height(f):
        return LIP * min(f, LIP_WIDTH) / float(LIP_WIDTH)

    raised = {}
    for (x, y), dirs in cells.items():
        for j in range(PER_CELL + 1):
            for i in range(PER_CELL + 1):
                px, py = x * 16 + i * STEP, y * 16 + j * STEP
                reads = []
                for dx, dy in dirs:
                    if dx == 0:
                        sx = min(max(px, x * 16), x * 16 + 15)
                        sy = py - (dy < 0)
                    else:
                        sx = px - (dx < 0)
                        sy = min(max(py, y * 16), y * 16 + 15)
                    reads.append((sx, sy, dx, dy, run(sx, sy, dx, dy),
                                  run(sx - dx, sy - dy, -dx, -dy)))
                if all(f for (_, _, _, _, f, _) in reads):
                    best = min(lip_height(f) for (_, _, _, _, f, _) in reads)
                elif any(b and not f for (_, _, _, _, f, b) in reads):
                    best = 0.0
                else:
                    best = 0.0
                    for (sx, sy, dx, dy, f, b) in reads:
                        k = first(sx, sy, dx, dy, LIP_BACK)
                        if k is not None:
                            top = lip_height(run(sx + k * dx, sy + k * dy, dx, dy))
                            best = max(best, top * (1.0 - k / float(LIP_BACK)))
                key = (x * PER_CELL + i, y * PER_CELL + j)
                raised[key] = max(raised.get(key, 0.0), best)
    for (gx, gy), v in raised.items():
        touching = [(cx, cy) for cx in {(gx - 1) // PER_CELL, gx // PER_CELL}
                    for cy in {(gy - 1) // PER_CELL, gy // PER_CELL}
                    if 0 <= cx < layout.w and 0 <= cy < layout.h]
        if not all(cc in cells for cc in touching):
            raised[(gx, gy)] = 0.0
    fall = LIP * STEP / float(LIP_WIDTH)
    for (gx, gy) in sorted(raised, key=lambda k: -k[1]):
        south = raised.get((gx, gy + 1))
        if south is not None and raised[(gx, gy)] > south + fall:
            raised[(gx, gy)] = south + fall
    for (x, y) in cells:
        g = grids.get((x, y))
        if g is None:
            continue
        g = [row[:] for row in g]
        for j in range(N + 1):
            for i in range(N + 1):
                g[j][i] += raised.get((x * N + i, y * N + j), 0.0)
        grids[(x, y)] = g
    return len(cells)


# -- output -------------------------------------------------------------------

def face_tile(c):
    """The wall texture: the first of FACES the map draws, as its own id."""
    art = c.art((0, 0))
    drawn = {c.metatile(cell) for cell in c.kind}
    f = next((f for f in FACES if f in drawn), FACES[0])
    back = getattr(art, "back", {})
    return back.get(f, f)


def to_json(layout, sol):
    c = sol["cells"]
    W, H = layout.w, layout.h
    grids, pieces = sol["grids"], sol["pieces"]
    out = {
        "map": layout.id, "em": layout.em, "pair": layout.pair, "w": W, "h": H,
        "level": LEVEL, "n": N,
        "source": "Emerald 3DS terrace counting (voxel_terraces.py, MIT), ported: tools/relief",
        "face_tile": face_tile(c),
        "grids": [[[round(v, 3) for row in grids[(x, y)] for v in row] for x in range(W)] for y in range(H)],
        "pieces": [[list(pieces[(x, y)]) for x in range(W)] for y in range(H)],
        "kind": ["".join(c.kind[(x, y)] for x in range(W)) for y in range(H)],
        "band": ["".join(c.band.get((x, y), ".") for x in range(W)) for y in range(H)],
        "rim": ["".join("r" if (x, y) in c.rim else "." for x in range(W)) for y in range(H)],
        "role": [[layout.role_at(x, y) for x in range(W)] for y in range(H)],
        "metatile": [[layout.metatile(x, y) for x in range(W)] for y in range(H)],
        "read_as": [[c.metatile((x, y)) for x in range(W)] for y in range(H)],
        "ledges": sorted([list(k) for k in c.ledges]),
        "bridges": sorted([list(k) for k in c.bridges]),
        "votes_dropped": len(sol["dropped"]),
        "runs": len(sol["runs"]),
    }
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("maps", nargs="+")
    ap.add_argument("--out", default=os.path.join(HERE, "out"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for name in a.maps:
        layout = E.Layout(name)
        sol = solve(layout)
        js = to_json(layout, sol)
        path = os.path.join(a.out, layout.id + ".json")
        with open(path, "w") as f:
            json.dump(js, f, separators=(",", ":"))
        kinds = collections.Counter("".join(js["kind"]))
        levels = sorted(set(sol["level"].values()))
        pk = collections.Counter(p[0] for row in js["pieces"] for p in row)
        print("%-14s kinds %s  levels %s  pieces %s  runs %d dropped %d  berms %d -> %s"
              % (layout.id, dict(kinds), levels[:12], dict(pk.most_common(8)), len(sol["runs"]),
                 len(sol["dropped"]), sol["berms"], path))


if __name__ == "__main__":
    main()
