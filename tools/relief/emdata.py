"""Map data for the relief prototype, read from the QA cache the way
tools/voxel_proto/voxproto.py and tools/analysis/layers.py read it.

What the port (terraces.py) asks of a map, in the shape Emerald 3DS's
voxel_cells.Layout / vb.LayoutArt answer it (see NOTICE.md):

  Layout   w, h, metatile(x, y), blocked, elevation, behaviour, off_map,
           warps, signs, role_at (water / ledge / stair / floor / signpost /
           wall / tree / fence / cliff / shelf)
  Art      metatile(x, y), image(m) (16x16 RGB, all layers), lower(m) and
           upper(m) (the metatile's bottom and top layers)
  AliasArt a Fallarbor- or Lavaridge-tileset map read as the General rock it
           redraws (gen_voxel_relief.alias_of): own tiles drawn like a General
           mountain tile take that tile's id and colours.

Colours are compared in GBA 5-bit space: the cache stores c<<3|c>>2, 3DS's
tables a rounded c*255/31, and both come back to the same 5-bit value.
"""
import os
import re
import sys
import json
import struct
import collections

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
import layers  # noqa: E402

NATIVE = layers.G
GBA = NATIVE.rstrip('/').rsplit('/native', 1)[0]
NUM_PRIMARY = 0x200

# secondary tilesets (census ids)
TS_FALLARBOR = 'ts_083df7ac'
TS_LAVARIDGE = 'ts_083df794'
ALIAS_TILESETS = {TS_FALLARBOR, TS_LAVARIDGE}

# raw Emerald metatile behaviours (gen1recomp constants/emerald/metatile_behaviors.lua)
MB = dict(POND_WATER=0x10, INTERIOR_DEEP_WATER=0x11, DEEP_WATER=0x12, WATERFALL=0x13,
          SOOTOPOLIS_DEEP_WATER=0x14, OCEAN_WATER=0x15, PUDDLE=0x16, SHALLOW_WATER=0x17,
          NO_SURFACING=0x19, SEAWEED=0x22, SEAWEED_NO_SURFACING=0x2A, HOT_SPRINGS=0x28,
          REFLECTION_UNDER_BRIDGE=0x2B, EASTWARD_CURRENT=0x50, WESTWARD_CURRENT=0x51,
          NORTHWARD_CURRENT=0x52, SOUTHWARD_CURRENT=0x53,
          NON_ANIMATED_DOOR=0x60, ANIMATED_DOOR=0x69, PETALBURG_GYM_DOOR=0x8D,
          BRIDGE_OVER_OCEAN=0x70, BRIDGE_OVER_POND_LOW=0x71, BRIDGE_OVER_POND_MED=0x72,
          BRIDGE_OVER_POND_HIGH=0x73, BRIDGE_OVER_POND_MED_EDGE_1=0x7A,
          BRIDGE_OVER_POND_MED_EDGE_2=0x7B, BRIDGE_OVER_POND_HIGH_EDGE_1=0x7C,
          BRIDGE_OVER_POND_HIGH_EDGE_2=0x7D, FORTREE_BRIDGE=0x78,
          BERRY_TREE_SOIL=0xA0, MUDDY_SLOPE=0xD0)
# voxel_cells.WATER: what the console draws as water
WATER = {MB[k] for k in ('POND_WATER', 'INTERIOR_DEEP_WATER', 'DEEP_WATER', 'WATERFALL',
                         'SOOTOPOLIS_DEEP_WATER', 'OCEAN_WATER', 'PUDDLE', 'SHALLOW_WATER',
                         'NO_SURFACING', 'SEAWEED', 'SEAWEED_NO_SURFACING', 'HOT_SPRINGS',
                         'REFLECTION_UNDER_BRIDGE', 'EASTWARD_CURRENT', 'WESTWARD_CURRENT',
                         'NORTHWARD_CURRENT', 'SOUTHWARD_CURRENT')}
BRIDGES = {MB[k] for k in MB if k.startswith('BRIDGE_OVER')}
HOUSE_DOORS = {MB['ANIMATED_DOOR'], MB['PETALBURG_GYM_DOOR']}
# gen_voxel_relief.JUMPS: each ledge behaviour's jump directions
JUMPS = {0x38: ((1, 0),), 0x39: ((-1, 0),), 0x3A: ((0, -1),), 0x3B: ((0, 1),),
         0x3C: ((1, 0), (0, -1)), 0x3D: ((-1, 0), (0, -1)),
         0x3E: ((1, 0), (0, 1)), 0x3F: ((-1, 0), (0, 1))}

FOLIAGE = 0.5               # voxel_cells: share of leaves that makes a tree
HOUSE_HALF_WIDTH, HOUSE_HEIGHT = 5, 7
TREAD_ACROSS, TREAD_DOWN = 4.0, 15.0
COVER_SLACK = 2
NEIGHBOURS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def c5(rgb):
    """A cache colour (c<<3|c>>2) as its GBA 5-bit triple."""
    return (int(rgb[0]) >> 3, int(rgb[1]) >> 3, int(rgb[2]) >> 3)


def t5(rgb):
    """A 3DS table colour (rounded c*255/31) as its GBA 5-bit triple."""
    return tuple(int(round(v * 31 / 255.0)) for v in rgb)


def _raw(path):
    return layers._raw(path)


_CENSUS = None
_MANIFEST = None


def census():
    global _CENSUS
    if _CENSUS is None:
        _CENSUS = json.load(open(os.path.join(GBA, 'map_tree', 'census.json')))
    return _CENSUS


def manifest():
    """{EM_LAYOUT: pair} from native/manifest.lua."""
    global _MANIFEST
    if _MANIFEST is None:
        text = open(os.path.join(NATIVE, 'manifest.lua')).read()
        _MANIFEST = dict(re.findall(r'\["(EM_[A-Z0-9_]+)"\]\s*=\s*\{\s*pair\s*=\s*"([^"]+)"', text))
    return _MANIFEST


def em_name(map_id):
    """'MtChimney' -> 'EM_MT_CHIMNEY'."""
    # ('MtPyre_Exterior' -> 'EM_MT_PYRE_EXTERIOR': an id that already has an underscore must not get two)
    return 'EM_' + re.sub(r'(?<!^)(?<!_)(?=[A-Z])', '_', map_id).upper()


def find_map(name):
    """A census entry by its id ('Route114') or layout key ('EM_ROUTE114')."""
    key = name[3:] if name.startswith('EM_') else name
    key = key.replace('_', '').lower()
    for m in census()['maps']:
        if m['id'].replace('_', '').lower() == key:
            return m
    raise KeyError(name)


def _attrs(ts):
    b = _raw(os.path.join(GBA, 'map_tree', 'tilesets', ts, 'attributes.bin'))
    return struct.unpack('<%dH' % (len(b) // 2), b)


class Art:
    """A tileset pair's metatile drawings (all three atlas layers)."""

    def __init__(self, pair, attr_primary, attr_secondary):
        self.pair = pair
        self.L = layers.load(pair)
        self.attr = (attr_primary, attr_secondary)
        self._img, self._lo, self._hi = {}, {}, {}

    def attributes(self, m):
        which = 0 if m < NUM_PRIMARY else 1
        t = self.attr[which]
        i = m - which * NUM_PRIMARY
        return t[i] if 0 <= i < len(t) else 0

    def layer(self, t, m):
        if t not in self.L:
            return None
        return layers.tile(self.L, t, m)

    def image(self, m):
        """16x16x3 uint8: the metatile as drawn (under, middle, over)."""
        if m not in self._img:
            out = np.zeros((16, 16, 3), float)
            for t in 'umo':
                x = self.layer(t, m)
                if x is not None:
                    k = x[..., 3:4].astype(float) / 255.0
                    out = x[..., :3] * k + out * (1 - k)
            self._img[m] = np.round(out).astype(np.uint8)
        return self._img[m]

    def _layers_of(self, m):
        """(bottom atlas, top atlas) by the metatile's layer type (GBA:
        normal = bg2/bg1, covered = bg3/bg2, split = bg3/bg1)."""
        kind = (self.attributes(m) >> 12) & 0xF
        return {0: ('m', 'o'), 1: ('u', 'm'), 2: ('u', 'o')}.get(kind, ('m', 'o'))

    def lower(self, m):
        """16x16x4 of the metatile's bottom layer."""
        if m not in self._lo:
            x = self.layer(self._layers_of(m)[0], m)
            self._lo[m] = np.zeros((16, 16, 4), np.uint8) if x is None else x
        return self._lo[m]

    def upper(self, m):
        """16x16x4 of the metatile's top layer (alpha 0 where it draws nothing)."""
        if m not in self._hi:
            x = self.layer(self._layers_of(m)[1], m)
            self._hi[m] = np.zeros((16, 16, 4), np.uint8) if x is None else x
        return self._hi[m]

    def colours5(self, m):
        """16x16 of 5-bit colour triples (as tuples), cached."""
        key = ('c5', m)
        if key not in self._img:
            img = self.image(m)
            self._img[key] = [[c5(img[y, x]) for x in range(16)] for y in range(16)]
        return self._img[key]


class Layout:
    """One map: its cells, collision, behaviours and events."""

    def __init__(self, name):
        e = find_map(name)
        self.entry = e
        self.id = e['id']
        self.em = em_name(e['id'])
        self.slot = e['slot']
        d = os.path.join(GBA, 'map_tree', 'maps', self.slot)
        hdr = json.load(open(os.path.join(d, 'header.json')))
        self.header = hdr
        self.w, self.h = hdr['width'], hdr['height']
        self.blocks = struct.unpack('<%dH' % (self.w * self.h), open(os.path.join(d, 'grid.bin'), 'rb').read())
        ev = json.load(open(os.path.join(d, 'events.json')))
        self.warps = {(w['x'], w['y']) for w in ev.get('warps', [])}
        self.signs = {(b['x'], b['y']) for b in ev.get('bgEvents', []) if b.get('type') == 'sign'}
        self.primary, self.secondary = e['primaryTileset'], e['secondaryTileset']
        self.pair = manifest()[self.em]
        self.art = Art(self.pair, _attrs(self.primary), _attrs(self.secondary))
        self.outdoor = hdr.get('mapType') in (1, 2, 3, 6)   # town, city, route, ocean route
        self._memo, self._foliage, self._treads, self._covers = {}, {}, {}, {}
        self._houses = None

    # -- the grid --
    def off_map(self, x, y):
        return x < 0 or y < 0 or x >= self.w or y >= self.h

    def metatile(self, x, y):
        return None if self.off_map(x, y) else self.blocks[y * self.w + x] & 0x3FF

    def blocked(self, x, y):
        return False if self.off_map(x, y) else ((self.blocks[y * self.w + x] >> 10) & 3) != 0

    def elevation(self, x, y):
        return 0 if self.off_map(x, y) else (self.blocks[y * self.w + x] >> 12) & 0xF

    def behaviour(self, x, y):
        m = self.metatile(x, y)
        return 0 if m is None else self.art.attributes(m) & 0xFF

    def touches_walkable(self, x, y):
        return any(not self.off_map(x + dx, y + dy) and not self.blocked(x + dx, y + dy)
                   for dx, dy in NEIGHBOURS)

    # -- what the drawing is asked (voxel_cells.Layout) --
    def _drawn(self, m):
        lo, hi = self.art.lower(m), self.art.upper(m)
        img = self.art.image(m)
        mask = (lo[..., 3] > 0) | (hi[..., 3] > 0)
        return img[mask]

    def foliage(self, m):
        if m not in self._foliage:
            px = self._drawn(m).astype(int)
            if len(px) == 0:
                self._foliage[m] = 0.0
            else:
                r, g, b = px[:, 0], px[:, 1], px[:, 2]
                green = ((g > 64) & (g > r + 16) & (g > b + 16)).sum()
                self._foliage[m] = green / float(len(px))
        return self._foliage[m]

    def covers(self, m):
        if m not in self._covers:
            rows = (self.art.upper(m)[..., 3] > 0).sum(1)
            self._covers[m] = int((rows >= 8).sum()) >= 16 - COVER_SLACK
        return self._covers[m]

    def treads(self, m):
        if m not in self._treads:
            lo, hi = self.art.lower(m), self.art.upper(m)
            mask = (lo[..., 3] > 0) | (hi[..., 3] > 0)
            ok = int(mask.sum()) >= 240
            if ok:
                img = self.art.image(m).astype(float)
                lum = 0.3 * img[..., 0] + 0.59 * img[..., 1] + 0.11 * img[..., 2]
                lum[~mask] = 0
                across = np.abs(np.diff(lum, axis=1)).sum() / 240.0
                down = np.abs(np.diff(lum, axis=0)).sum() / 240.0
                ok = across <= TREAD_ACROSS and down >= TREAD_DOWN
            self._treads[m] = bool(ok)
        return self._treads[m]

    def houses(self):
        if self._houses is None:
            cells = set()
            for dx, dy in self.warps:
                if self.behaviour(dx, dy) not in HOUSE_DOORS:
                    continue
                seed = (dx, dy - 1)
                if self.off_map(*seed) or not self.blocked(*seed):
                    continue
                stack, seen = [seed], {seed}
                while stack:
                    x, y = stack.pop()
                    cells.add((x, y))
                    for ox, oy in NEIGHBOURS:
                        nx, ny = x + ox, y + oy
                        if ((nx, ny) in seen or self.off_map(nx, ny) or not self.blocked(nx, ny)
                                or abs(nx - dx) > HOUSE_HALF_WIDTH or ny > dy or ny < dy - HOUSE_HEIGHT
                                or self.foliage(self.metatile(nx, ny)) >= FOLIAGE):
                            continue
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            self._houses = cells
        return self._houses

    def open_post(self, x, y):
        return (self.outdoor and self.blocked(x, y)
                and not any(self.blocked(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1))))

    def is_signpost(self, x, y):
        # (simplified: a sign event standing open on three sides, or a post
        # that is not a cover, foliage or a house; 3DS also reads lamps and
        # sign drawings shared across maps)
        if not self.open_post(x, y):
            return False
        if (x, y) in self.signs:
            return True
        m = self.metatile(x, y)
        if m < NUM_PRIMARY and 0x064 <= m < 0x0C0:
            return False
        if self.covers(m) or self.foliage(m) >= FOLIAGE or (x, y) in self.houses():
            return False
        return not self.blocked(x, y - 1) or self.metatile(x, y - 1) != m

    def is_ledge_junction(self, x, y):
        if not self.blocked(x, y):
            return False
        horizontal = any(self.behaviour(x + dx, y) in JUMPS for dx in (-1, 1))
        vertical = any(self.behaviour(x, y + dy) in JUMPS for dy in (-1, 1))
        return horizontal and vertical

    def role_at(self, x, y):
        hit = self._memo.get((x, y))
        if hit is not None:
            return hit
        b = self.behaviour(x, y)
        if b in WATER:
            role = 'water'
        elif b in JUMPS:
            role = 'ledge'
        elif not self.blocked(x, y):
            role = 'stair' if self.treads(self.metatile(x, y)) else 'floor'
        elif self.is_signpost(x, y):
            role = 'signpost'
        elif (x, y) in self.houses():
            role = 'wall'
        elif self.foliage(self.metatile(x, y)) >= FOLIAGE:
            role = 'tree'
        elif ((not self.blocked(x, y - 1) and not self.blocked(x, y + 1)
               and not self.off_map(x, y - 1) and not self.off_map(x, y + 1))
              or (not self.blocked(x - 1, y) and not self.blocked(x + 1, y)
                  and not self.off_map(x - 1, y) and not self.off_map(x + 1, y))):
            role = 'fence'
        elif self.touches_walkable(x, y):
            role = 'cliff'
        else:
            role = 'shelf'
        self._memo[(x, y)] = role
        return role


def ledge_cells(layout, junctions=True):
    """gen_voxel_relief.ledge_cells: {(x, y): jump directions}, with the
    blocked junction pieces where a ledge turns a corner."""
    out = {}
    for y in range(layout.h):
        for x in range(layout.w):
            d = JUMPS.get(layout.behaviour(x, y))
            if d:
                out[(x, y)] = d
    if not junctions:
        return out
    joins = {}
    for (x, y) in out:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) in out or layout.off_map(nx, ny) or not layout.blocked(nx, ny):
                continue
            if not layout.is_ledge_junction(nx, ny):
                continue
            dirs = joins.setdefault((nx, ny), [])
            dirs.extend(d for d in out[(x, y)] if d not in dirs)
    out.update((c, tuple(d)) for c, d in joins.items())
    return out


# -- the drawing as the analysis reads it --------------------------------------

class LayoutArt:
    """A layout's drawing (vb.LayoutArt): metatile(x, y) and its images."""

    def __init__(self, layout):
        self.layout = layout
        self.w, self.h = layout.w, layout.h
        self.primary, self.secondary = layout.primary, layout.secondary
        self.id = layout.id

    def metatile(self, x, y):
        return self.layout.metatile(x, y)

    def image(self, m):
        return self.layout.art.image(m)

    def lower(self, m):
        return self.layout.art.lower(m)

    def colours5(self, m):
        return self.layout.art.colours5(m)


def _drawing(img):
    """A tile's drawing without its palette: colours numbered as they come."""
    lab = {}
    return tuple(lab.setdefault(c5(p), len(lab)) for p in img.reshape(-1, 3))


class AliasArt(LayoutArt):
    """gen_voxel_relief.AliasArt: own tiles read as the General tiles they
    redraw, in the General's colours."""

    def __init__(self, layout, alias):
        super().__init__(layout)
        self.alias, self.back, self.colour = alias
        self._c5 = {}

    def metatile(self, x, y):
        m = super().metatile(x, y)
        return self.alias.get(m, m)

    def own_metatile(self, x, y):
        return super().metatile(x, y)

    def colours5(self, m):
        if m not in self._c5:
            src = self.layout.art.colours5(m)
            if m >= NUM_PRIMARY:
                src = [[self.colour.get(c, c) for c in row] for row in src]
            self._c5[m] = src
        return self._c5[m]


def alias_of(layout, roles, boulder_heads):
    """({own id: General id}, {General id: own id}, {own 5-bit colour:
    General 5-bit colour}) of a map drawn with a Fallarbor or Lavaridge
    secondary tileset, else None. `roles`: the General ids an own tile may
    stand for (gen_voxel_relief: ROCK_TILES | SIDE_WEST | SIDE_EAST |
    SEA_CAPS | BOULDER)."""
    if layout.secondary not in ALIAS_TILESETS:
        return None
    art = layout.art
    known = {}
    for m in sorted(roles):
        if m < NUM_PRIMARY:
            known.setdefault(_drawing(art.image(m)), m)
    used = collections.Counter(layout.metatile(x, y) for y in range(layout.h) for x in range(layout.w))
    alias, votes = {}, collections.defaultdict(collections.Counter)
    for m, n in used.items():
        if m < NUM_PRIMARY:
            continue
        g = known.get(_drawing(art.image(m)))
        if g is None:
            continue
        alias[m] = g
        for a, b in zip(art.image(m).reshape(-1, 3), art.image(g).reshape(-1, 3)):
            votes[c5(a)][c5(b)] += n
    for m, g in list(alias.items()):
        if g not in boulder_heads:
            continue
        over = sum(1 for y in range(layout.h - 1) for x in range(layout.w)
                   if layout.metatile(x, y) == m and alias.get(layout.metatile(x, y + 1)) == boulder_heads[g])
        if 2 * over < used[m]:
            del alias[m]
    if not alias:
        return None
    colour = {a: c.most_common(1)[0][0] for a, c in votes.items()}
    back = {}
    for m, g in sorted(alias.items(), key=lambda kv: -used[kv[0]]):
        back.setdefault(g, m)
    return alias, back, colour
