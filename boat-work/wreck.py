#!/usr/bin/env python3
"""Design the Route 108 wreck as a ship and preview it (no game needed).

Reads the composed wreck drawing (mid+over tile layers, exactly as
BuildingVoxels composes it), builds a hull/deck/bulwark/hold/deckhouse voxel
model painted with the drawing's own pixels, renders it from the game's
cameras, and (with --lua) writes the model's quads for the mod.

    python3 boat-work/wreck.py                 # render /tmp/wreck_preview.png
"""
import math
import os
import struct
import sys
import zlib
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

C = Path.home() / "Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba"
SLOT, PAIR = "0_23", "general__slateport"
X0, Y0, X1, Y1 = 27, 3, 33, 5

# ---------------------------------------------------------------- the drawing
def raw(p):
    b = open(p, "rb").read()
    try:
        return zlib.decompress(b)
    except Exception:
        return b


def compose():
    mdir = C / "map_tree/maps" / SLOT
    hdr = __import__("json").load(open(mdir / "header.json"))
    W, H = hdr["width"], hdr["height"]
    cells = struct.unpack("<%dH" % (W * H), open(mdir / "grid.bin", "rb").read())
    d = C / "native" / PAIR
    b = raw(d / "mids.idx")
    count, cols, rows = struct.unpack_from("<HHH", b, 6)
    mids = struct.unpack_from("<%dH" % count, b, 12)
    m2s = {m: i for i, m in enumerate(mids)}
    base = raw(next(d.glob("atlas_m_*.rgba")))
    f = list(d.glob("atlas_o_*.rgba"))
    over = raw(f[0]) if f else None
    aw = cols * 16
    ow, oh = (X1 - X0 + 1) * 16, (Y1 - Y0 + 1) * 16
    img = Image.new("RGBA", (ow, oh), (0, 0, 0, 0))
    px = img.load()
    for cy in range(Y0, Y1 + 1):
        for cx in range(X0, X1 + 1):
            mid = cells[cy * W + cx] & 0x3FF
            sl = m2s.get(mid)
            if sl is None:
                continue
            sx, sy = (sl % cols) * 16, (sl // cols) * 16
            for y in range(16):
                for x in range(16):
                    o = ((sy + y) * aw + sx + x) * 4
                    r, g, b_, a = base[o], base[o + 1], base[o + 2], base[o + 3]
                    if over is not None and over[o + 3]:
                        k = over[o + 3] / 255
                        r = int(over[o] * k + r * (1 - k))
                        g = int(over[o + 1] * k + g * (1 - k))
                        b_ = int(over[o + 2] * k + b_ * (1 - k))
                        a = max(a, over[o + 3])
                    px[(cx - X0) * 16 + x, (cy - Y0) * 16 + y] = (r, g, b_, a)
    return img


# ---------------------------------------------------------------- the ship
DECK = 10.5           # deck height above the water/ground (the art draws heights foreshortened)
BEAM = 1.0            # the plan is drawn to the art's own rows: never stretch a texture
BULW = 2.6            # bulwark (deck edge rail) above the deck
HOLD_F = 4.6          # the hold's flooded floor
CAB_TOP = 17.4        # the deckhouse roof

# deck plan: north edge (zN) and south edge (zS) per x, art px; z=0 is the
# drawing's deck front row (py 33), negative is north/depth
PLAN = [
    # x,   zN,   zS
    (0, -8.0, -3.0),
    (1, -11.0, -1.5),
    (3, -14.0, -0.5),
    (6, -17.0, 0.0),
    (10, -19.5, 0.0),
    (14, -21.0, 0.0),
    (20, -22.0, 0.0),
    (26, -23.0, 0.0),
    (50, -23.0, 0.0),
    (58, -22.5, 0.0),
    (64, -21.5, 0.0),
    (70, -20.0, 0.0),
    (76, -17.5, 0.0),
    (80, -15.0, -0.3),
    (84, -12.0, -1.0),
    (86, -9.0, -2.0),
    (87, -7.0, -3.5),
]
HOLD = (24, 60, -22, -2)      # x0, x1, zN, zS of the open cargo hold
CABIN = (60, 76, -22, -6)     # the deckhouse / engine casing block
POOP = 74                     # the raised stern deck starts here
FOREDECK = 12                 # the raised bow deck ends here


def lerp_plan(x):
    for (xa, na, sa), (xb, nb, sb) in zip(PLAN, PLAN[1:]):
        if xa <= x <= xb:
            t = (x - xa) / (xb - xa)
            return (na + (nb - na) * t) * BEAM, (sa + (sb - sa) * t) * BEAM
    return PLAN[0][1] * BEAM, PLAN[0][2] * BEAM


ZMIN = math.floor(min(p[1] for p in PLAN) * BEAM) - 1


def inside(x, z):
    """is the deck cell (x, z) inside the ship? the cell spans x..x+1 and z-1..z (z=0 is the front)"""
    if x < PLAN[0][0] or x > PLAN[-1][0]:
        return False
    zn, zs = lerp_plan(x)
    zc = z - 0.5
    return zn <= zc <= zs


def top(x, z):
    """the top height of cell (x, z)"""
    if not inside(x, z):
        return None
    if HOLD[0] <= x < HOLD[1] and HOLD[2] <= z < HOLD[3]:
        return HOLD_F
    if CABIN[0] <= x < CABIN[1] and CABIN[2] <= z < CABIN[3]:
        # the deckhouse: its aft third has fallen in
        if 69 <= x < CABIN[1] and -11 <= z < -6:
            return CAB_TOP - 5.0
        return CAB_TOP
    perf = not (inside(x + 1, z) and inside(x - 1, z) and inside(x, z + 1) and inside(x, z - 1))
    coam = not (HOLD[0] - 1 <= x <= HOLD[1] and HOLD[2] - 1 <= z <= HOLD[3])
    if perf:
        # the rail is broken along the bow's south side
        if x < 9 and z >= -2:
            return DECK + 0.6
        return DECK + BULW + (1.4 if x >= POOP else 0.0) + (0.9 if x < FOREDECK else 0.0)
    if not coam:
        return DECK + 1.3          # the coaming round the open hold
    return DECK


def cells():
    out = []
    for x in range(PLAN[0][0], PLAN[-1][0] + 1):
        for z in range(ZMIN, 1):
            h = top(x, z)
            if h is not None:
                out.append((x, z, h))
    return out


# ---------------------------------------------------------------- mesher
def sample(img, x, y):
    """the drawing's pixel, nudged off transparent and dark-outline pixels (they read as holes)"""
    W, H = img.size
    best = None
    for r in range(0, 6):
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if max(abs(dx), abs(dy)) != r:
                    continue
                xx, yy = x + dx, y + dy
                if not (0 <= xx < W and 0 <= yy < H):
                    continue
                c = img.getpixel((xx, yy))
                if c[3] == 0 or sum(c[:3]) < 150:
                    continue
                d = dx * dx + dy * dy
                if best is None or d < best[0]:
                    best = (d, xx, yy)

    if best:
        return best[1], best[2]
    return max(0, min(W - 1, x)), max(0, min(H - 1, y))


# the drawing's hull-side rows (py) mapped onto heights above the waterline:
# py 33 is the deck edge, 34..36 the porthole strake, 37..38 the plates, 39 the algae
SIDE_BANDS = [(0.0, .25 * DECK, 40), (.25 * DECK, .50 * DECK, 38), (.50 * DECK, .75 * DECK, 35),
              (.75 * DECK, DECK, 34), (DECK, 99.0, 33)]


def deck_py(z):
    return 33 + z


def runs(items):
    """items: (a, key) along one axis, key None = a gap; yields (a0, a1, key)"""
    out, cur = [], None
    for a, key in items:
        if key is None:
            if cur:
                out.append(cur)
                cur = None
            continue
        if cur and cur[1] == a and cur[2] == key:
            cur = (cur[0], a + 1, key)
        else:
            if cur:
                out.append(cur)
            cur = (a, a + 1, key)
    if cur:
        out.append(cur)
    return out


def quads_of(img):
    """emit (face, x0, x1, h0, h1, z0, z1, px, py) quads for the ship

    cell (x,z) covers x..x+1 and z-1..z (z=0 is the front/south edge, negative goes
    north): its top is z-1..z, its south face z, its north face z-1, its west face x
    and its east face x+1.
    """
    q = []
    h_of = {(x, z): h for x, z, h in cells()}
    xs = list(range(PLAN[0][0], PLAN[-1][0] + 1))
    zs = list(range(ZMIN, 1))

    def paint(x, y):
        return img.getpixel(sample(img, x, y))[:3]

    # tops
    for z in zs:
        items = []
        for x in xs:
            h = h_of.get((x, z))
            items.append((x, None if h is None else (h, paint(x, deck_py(z)))))
        for a0, a1, (h, _c) in runs(items):
            p = sample(img, (a0 + a1) // 2, deck_py(z))
            q.append((3, a0, a1, h, h, z - 1, z, p[0], p[1]))

    # hull sides: one height band at a time, so algae / portholes / plates keep their row
    for y0, y1, py in SIDE_BANDS:
        for z in zs:
            for side, face in (("s", 1), ("n", 2)):
                items = []
                for x in xs:
                    h = h_of.get((x, z))
                    if h is None:
                        items.append((x, None))
                        continue
                    nb = h_of.get((x, z + 1)) if side == "s" else h_of.get((x, z - 1))
                    base = 0.0 if nb is None else nb
                    hb, ht = max(base, y0), min(h, y1)
                    if ht - hb < 1e-6:
                        items.append((x, None))
                    else:
                        # an inner wall (the hold's side, a step down) takes the plan's paint,
                        # the hull's own side its strake rows
                        p = sample(img, x, deck_py(z) if base > 1.6 else py)
                        items.append((x, (hb, ht, p, paint(x, deck_py(z) if base > 1.6 else py))))
                zf = z if side == "s" else z - 1
                for a0, a1, (hb, ht, pp, _c) in runs(items):
                    q.append((face, a0, a1, hb, ht, zf, zf, pp[0], pp[1]))

    # the sea floor of the model's box: the claimed cells lose their own ground plane, so the
    # model has to lay the water it stands in (just under it, where an unclaimed cell's own plane
    # still wins). Painted with the drawing's shallow-water texel.
    px, py = sample(img, 2, 3)
    q.append((3, 0, 112, -0.04, -0.04, -48, 0, px, py))

    # bow and stern ends: the same bands, runs along z
    for y0, y1, py in SIDE_BANDS:
        for x in xs:
            for side, face in (("e", 4), ("w", 5)):
                items = []
                for z in zs:
                    h = h_of.get((x, z))
                    if h is None:
                        items.append((z, None))
                        continue
                    nb = h_of.get((x + 1, z)) if side == "e" else h_of.get((x - 1, z))
                    base = 0.0 if nb is None else nb
                    hb, ht = max(base, y0), min(h, y1)
                    if ht - hb < 1e-6:
                        items.append((z, None))
                    else:
                        p = sample(img, x, deck_py(z) if base > 1.6 else py)
                        items.append((z, (hb, ht, p, paint(x, deck_py(z) if base > 1.6 else py))))
                xf = x + 1 if side == "e" else x
                for a0, a1, (hb, ht, pp, _c) in runs(items):
                    q.append((face, xf, xf, hb, ht, a0 - 1, a1 - 1, pp[0], pp[1]))
    return q


# ---------------------------------------------------------------- preview
def render(q, img, pitch, yaw, scale=9.0, pad=24):
    p, a = math.radians(pitch), math.radians(yaw)
    polys = []
    W, H = img.size
    for face, x0, x1, h0, h1, z0, z1, px, py in q:
        if face == 3:
            pts = [(x0, h0, z0), (x1, h0, z0), (x1, h0, z1), (x0, h0, z1)]
        elif face in (1, 2):
            pts = [(x0, h0, z0), (x1, h0, z0), (x1, h1, z0), (x0, h1, z0)]
        else:
            pts = [(x0, h0, z0), (x0, h0, z1), (x0, h1, z1), (x0, h1, z0)]
        col = img.getpixel((px, py))[:3]
        sh = {1: 0.92, 2: 0.70, 3: 1.0, 4: 0.84, 5: 0.74}[face]
        proj, depth = [], 0.0
        for (X, Y, Z) in pts:
            xr = X * math.cos(a) + Z * math.sin(a)
            zr = -X * math.sin(a) + Z * math.cos(a)
            sx = xr
            sy = -Y * math.cos(p) + zr * math.sin(p)
            d = -Y * math.sin(p) - zr * math.cos(p)
            proj.append((sx, sy))
            depth += d / 4
        polys.append((depth, proj, tuple(int(c * sh) for c in col)))
    polys.sort(key=lambda t: -t[0])
    xs = [pt[0] for _, pr, _ in polys for pt in pr]
    ys = [pt[1] for _, pr, _ in polys for pt in pr]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    cw = int((maxx - minx) * scale) + 2 * pad
    ch = int((maxy - miny) * scale) + 2 * pad
    out = Image.new("RGB", (cw, ch), (96, 122, 150))
    d = ImageDraw.Draw(out)
    for _, pr, col in polys:
        pts = [((x - minx) * scale + pad, (y - miny) * scale + pad) for x, y in pr]
        d.polygon(pts, fill=col, outline=None)
    return out


def write_lua(q, path, mod_root):
    """write the authored quads as lib/AbandonedWreck.lua (metadata stays in the generated model)"""
    out = []
    out.append("-- The Route 108 wreck: a ship, not its drawing stood on end.")
    out.append("--")
    out.append("-- The generated model (data/buildings/abandoned_ship_wreck.lua, tools/buildings/hf.py) read the")
    out.append("-- wreck's drawing as a height field: every art row became depth, so the hulk rose 26 px as a")
    out.append("-- terraced slab and read as a green building in the sea (the user: \"fix the abandoned ship in")
    out.append("-- the same way, make it more realistic\"). The drawing is a 3/4 view of a ship, not a height")
    out.append("-- map, so the wreck is modelled here: one hull with a pointed bow, a raised foredeck, a poop")
    out.append("-- deck, a bulwark, an open cargo hold with its coaming, a deckhouse whose aft third has fallen")
    out.append("-- in, and a broken rail by the bow. Every face is painted with the drawing's own pixel (the")
    out.append("-- hull's strake rows for the topsides, the plan for the decks), so nothing is stretched.")
    out.append("-- The hull's heights are the art's, lifted 1.4x: a drawing seen at the map's 3/4 angle")
    out.append("-- foreshortens height, and the user's taste is more depth than the flat original.")
    out.append("--")
    out.append("-- Generated by tools/buildings/wreck.py (the designer); BuildingVoxels swaps these quads in")
    out.append("-- for this one model and keeps the generated anchor and tiles.")
    out.append("local M = {}")
    out.append("M.QUADS = {")
    for f in q:
        face, x0, x1, h0, h1, z0, z1, px, py = f
        # ten numbers a quad: the last is the face's own shade in percent (0 = the face's default)
        out.append(" %d,%g,%g,%g,%g,%g,%g,%d,%d,0," % (face, x0, x1, h0, h1, z0, z1, px, py))
    out.append("}")
    out.append("return M")
    open(path, "w").write("\n".join(out) + "\n")
    print("wrote", path, len(q), "quads")


def main():
    img = compose()
    q = quads_of(img)
    print("quads", len(q))
    tiles = [render(q, img, p, y, scale=s) for p, y, s in ((50, 0, 8), (75, 0, 8), (50, 30, 8), (18, 0, 8))]
    w = sum(t.width for t in tiles) + 10 * (len(tiles) - 1)
    h = max(t.height for t in tiles)
    sheet = Image.new("RGB", (w, h), (24, 26, 34))
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0))
        x += t.width + 10
    sheet.save("/tmp/wreck_preview.png")
    print("wrote /tmp/wreck_preview.png", sheet.size)
    if "--lua" in sys.argv:
        write_lua(q, os.environ.get("OUT_LUA", str(Path.home() / "Documents/battle-art-notquiteog/lib/AbandonedWreck.lua")), None)


if __name__ == "__main__":
    main()
