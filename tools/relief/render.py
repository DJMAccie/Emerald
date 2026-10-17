#!/usr/bin/env python3
"""Offline render of the relief prototype at the game's camera.

Reads terraces.py's JSON (per-cell 5x5 lattice heights) and the map's own
drawing, and builds the scene the way Emerald 3DS's voxel_mesh_builder.c
does (EmitRelief, EmitCliffWalls; see NOTICE.md):

- every texel of a cell's own tile is laid on the cell's lattice, a point
  (u, v) at height h placed at world (u, h, v + h): at 45 degrees the result
  is the drawing; each 4 px lattice square is split along its crease;
- where a cell's west, east or south edge stands over its neighbour's, a
  wall closes the step: the map's face tile, a level of it per level of wall
  (ours: repeated, never stretched; 3DS stretches a taller wall);
- the north edge (a terrace's back) is never walled.

Painter's algorithm per texel triangle, as tools/voxel_proto/voxproto.py
renders (sort by depth, PIL polygons), with the game's perspective camera:

  level 4  40 deg below horizontal, looking north, vertical FOV 53.1 deg,
           eye 1.18 x the visible world height from the player's cell
  level 7  a low third-person camera: eye 48 px over the ground, 75 px
           behind the player, looking north 4.5 deg down, FOV 62 deg

Variants: "theirs" (the counted pieces as 3DS builds them) and "soft"
(ours: theirs with the shoulders rounded 3 px and rock tops rolling up to
4 px, the way our Gen3Rock SOFT / Gen3Hills tops read). Any height keeps the
45-degree drawing, so the soft variant is still the drawing from above.

Ours, for readability only: trees stand as cards (their top layer) on their
trunk's south edge - 3DS draws trees as separate models; houses and props
stay flat drawings.

    python3 render.py RELIEF.json X Y LEVEL OUT.png [--variant theirs|soft]
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import emdata as E  # noqa: E402

N = 4
WIDTH, HEIGHT = 1280, 720
SHADE_SOUTH, SHADE_SIDE = 0.86, 0.74
SOFT = 3.0          # shoulder rounding, px (our Gen3Rock.SOFT_ROUND)
ROLL = 4.0          # most a rock top rolls up, px


def load(path):
    J = json.load(open(path))
    layout = E.Layout(J["map"])
    W, H = J["w"], J["h"]
    grids = {}
    for y in range(H):
        for x in range(W):
            g = J["grids"][y][x]
            grids[(x, y)] = np.array(g, float).reshape(N + 1, N + 1)
    return J, layout, grids


# -- variants -------------------------------------------------------------------

def soften(J, grids):
    """Ours: round the shoulders of rock (kind T or R) by SOFT px and let
    rock tops that nobody walks roll up to ROLL px from their edges. Points
    shared by several cells at one height move together (no cracks)."""
    W, H = J["w"], J["h"]
    kind = J["kind"]
    role = J["role"]
    rock = {(x, y) for y in range(H) for x in range(W) if kind[y][x] in "TR"}
    # every lattice point: (cell, j, i, h)
    at = {}
    for (x, y), g in grids.items():
        for j in range(N + 1):
            for i in range(N + 1):
                at.setdefault((x * N + i, y * N + j), []).append(((x, y), j, i, g[j, i]))
    lower = {}
    for (x, y) in rock:
        g = grids[(x, y)]
        for j in range(N + 1):
            for i in range(N + 1):
                h = g[j, i]
                # a shoulder: the high end of a fall in this cell's own lattice
                drop = 0.0
                for dj, di in ((1, 0), (0, 1), (0, -1), (-1, 0)):
                    jj, ii = j + dj, i + di
                    if 0 <= jj <= N and 0 <= ii <= N:
                        drop = max(drop, h - g[jj, ii])
                if drop >= 3.0:
                    key = (x * N + i, y * N + j, round(h, 2))
                    lower[key] = max(lower.get(key, 0.0), SOFT)
    # one step behind a shoulder, on the flat: 1 px
    behind = {}
    for (gx, gy, h), v in lower.items():
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k = (gx + dx, gy + dy, h)
            if k not in lower:
                behind[k] = max(behind.get(k, 0.0), 1.0)
    # rolling tops: distance (in lattice steps) from the nearest shoulder,
    # over unwalked rock tops
    tops = {(x, y) for (x, y) in rock if kind[y][x] == "T" and role[y][x] not in ("floor", "stair")
            and np.ptp(grids[(x, y)]) < 0.5}
    dist = {}
    front = [(gx, gy) for (gx, gy, h) in lower]
    for p in front:
        dist[p] = 0
    while front:
        nxt = []
        for (gx, gy) in front:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (gx + dx, gy + dy)
                if q in dist:
                    continue
                cells = {e[0] for e in at.get(q, ())}
                if not cells or not cells <= tops:
                    continue
                dist[q] = dist[(gx, gy)] + 1
                nxt.append(q)
        front = nxt
    out = {}
    for cell, g in grids.items():
        g2 = g.copy()
        x, y = cell
        for j in range(N + 1):
            for i in range(N + 1):
                gx, gy = x * N + i, y * N + j
                k = (gx, gy, round(g[j, i], 2))
                if k in lower:
                    g2[j, i] -= lower[k]
                elif k in behind:
                    g2[j, i] -= behind[k]
                elif cell in tops and dist.get((gx, gy), 0) > 1:
                    g2[j, i] += min(ROLL, 0.75 * (dist[(gx, gy)] - 1))
        out[cell] = g2
    return out


# -- geometry -------------------------------------------------------------------

_FX = np.arange(17) / 4.0


def texel_heights(g):
    """17 x 17 heights at the texel corners of a cell: each 4 px lattice
    square two planes meeting on its crease (EmitRelief's split)."""
    out = np.zeros((17, 17))
    diag = np.zeros((4, 4), bool)       # True: crease NE-SW (p1-p3)
    for b in range(N):
        for a in range(N):
            g00, g10, g01, g11 = g[b, a], g[b, a + 1], g[b + 1, a], g[b + 1, a + 1]
            anti = g00 == g11 and g10 != g01
            diag[b, a] = anti
            for jj in range(5):
                for ii in range(5):
                    fx, fy = ii / 4.0, jj / 4.0
                    if anti:
                        if fx + fy <= 1:
                            h = g00 + (g10 - g00) * fx + (g01 - g00) * fy
                        else:
                            h = g11 + (g01 - g11) * (1 - fx) + (g10 - g11) * (1 - fy)
                    else:
                        if fx >= fy:
                            h = g00 + (g10 - g00) * fx + (g11 - g10) * fy
                        else:
                            h = g00 + (g01 - g00) * fy + (g11 - g01) * fx
                    out[b * 4 + jj, a * 4 + ii] = h
    return out, diag


class Scene:
    def __init__(self):
        self.tris = []      # (3, 3) world points
        self.cols = []

    def tri(self, a, b, c, col):
        self.tris.append((a, b, c))
        self.cols.append(col)

    def quad(self, a, b, c, d, col):
        self.tri(a, b, c, col)
        self.tri(a, c, d, col)


def cell_surface(sc, x, y, g, img, mask=None, lift=None):
    """The cell's own drawing laid on its lattice, a texel a quad."""
    Hc, diag = texel_heights(g)
    X0, Z0 = x * 16, y * 16
    for j in range(16):
        for i in range(16):
            if mask is not None and not mask[j, i]:
                continue
            col = tuple(int(v) for v in img[j, i])
            p = []
            for di, dj in ((0, 0), (1, 0), (1, 1), (0, 1)):
                h = Hc[j + dj, i + di]
                p.append((X0 + i + di, h, Z0 + j + dj + h))
            if diag[j // 4, i // 4]:
                sc.tri(p[1], p[2], p[3], col)
                sc.tri(p[1], p[3], p[0], col)
            else:
                sc.tri(p[0], p[1], p[2], col)
                sc.tri(p[0], p[2], p[3], col)


def edge(g, side):
    if side == "N":
        return g[0, :]
    if side == "S":
        return g[N, :]
    return g[:, 0] if side == "W" else g[:, N]


def cliff_walls(sc, x, y, g, grids, face):
    """EmitCliffWalls: west, east and south edges standing over the
    neighbour's; the face tile down them (a level of it a level of wall)."""
    for d, (nx, ny), mine, theirs in ((0, (x - 1, y), "W", "E"), (1, (x + 1, y), "E", "W"),
                                      (2, (x, y + 1), "S", "N")):
        o = grids.get((nx, ny))
        if o is None:
            continue
        a, b = edge(g, mine), edge(o, theirs)
        for k in range(N):
            ta, tb = a[k], a[k + 1]
            oa, ob = b[k], b[k + 1]
            if ta - oa <= 0.01 and tb - ob <= 0.01:
                continue
            ba, bb = min(ta, oa), min(tb, ob)
            # texel strips along the edge (4 px), rows of a pixel down it
            for s in range(4):
                f0, f1 = s / 4.0, (s + 1) / 4.0
                t0, t1 = ta + (tb - ta) * f0, ta + (tb - ta) * f1
                b0, b1 = ba + (bb - ba) * f0, ba + (bb - ba) * f1
                c0, c1 = oa + (ob - oa) * f0, oa + (ob - oa) * f1      # their depth
                rows = int(math.ceil(max(t0 - b0, t1 - b1) - 1e-6))
                if rows <= 0:
                    continue
                along = k * 4 + s
                for r in range(rows):
                    q0, q1 = r / float(rows), (r + 1) / float(rows)

                    def pt(f, q):
                        t = t0 + (t1 - t0) * f
                        bt = b0 + (b1 - b0) * f
                        cz = c0 + (c1 - c0) * f
                        h = t + (bt - t) * q
                        dz = t + (cz - t) * q          # depth: ours at the top, theirs at the foot
                        if d == 2:
                            return (x * 16 + along + f, h, (y + 1) * 16 + dz)
                        xe = x * 16 if d == 0 else (x + 1) * 16
                        return (xe, h, y * 16 + along + f + dz)
                    # the face tile, repeated a tile a level (never stretched)
                    vrow = int(r * (max(t0 - b0, t1 - b1) / rows)) % 16
                    if d == 2:
                        col = face[vrow, along]
                        sh = SHADE_SOUTH
                    else:
                        col = face[vrow, along]
                        sh = SHADE_SIDE
                    col = tuple(int(v * sh) for v in col)
                    sc.quad(pt(0, q0), pt(1, q0), pt(1, q1), pt(0, q1), col)


FACE_IDS = (0x07c, 0x0a9, 0x079, 0x091)
_WALL = {}


def wall_tile(J, layout, x, y, default):
    """The face a cell's walls wear: 3DS takes the first face the map draws
    (one per map); ours takes the nearest face drawn round the cell, so a
    map with two kinds of rock (Route 114's brown terrace and beige
    mountain) walls each in its own."""
    key = (J["map"], x, y)
    if key not in _WALL:
        best = None
        for r in range(0, 5):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < J["w"] and 0 <= yy < J["h"] and J["read_as"][yy][xx] in FACE_IDS:
                        best = J["metatile"][yy][xx]
                        break
                if best is not None:
                    break
            if best is not None:
                break
        _WALL[key] = default if best is None else layout.art.image(best)
    return _WALL[key]


def back_fill(sc, x, y, g, grids, imgs):
    """Ours, standing in for 3DS's "fill" records (the ground behind a
    terrace's back runs on under it): where a cell's north edge stands over
    the cell behind it, (u, h, v + h) opens a sliver between the two; it is
    closed with the ground behind's own last row."""
    o = grids.get((x, y - 1))
    if o is None:
        return
    a, b = g[0, :], o[N, :]
    img = imgs.get((x, y - 1))
    for k in range(N):
        ta, tb, oa, ob = a[k], a[k + 1], b[k], b[k + 1]
        if ta - oa <= 0.01 and tb - ob <= 0.01:
            continue
        for s in range(4):
            f0, f1 = s / 4.0, (s + 1) / 4.0
            t0, t1 = ta + (tb - ta) * f0, ta + (tb - ta) * f1
            c0, c1 = oa + (ob - oa) * f0, oa + (ob - oa) * f1
            along = k * 4 + s
            col = tuple(int(v * 0.92) for v in (img[15, along] if img is not None else (90, 90, 90)))
            z = y * 16
            sc.quad((x * 16 + along, c0, z + c0), (x * 16 + along + 1, c1, z + c1),
                    (x * 16 + along + 1, t1, z + t1), (x * 16 + along, t0, z + t0), col)


def tree_cards(J, layout, grids, cells):
    """Ours: each tree cell's top layer stands up as a card 16 px tall on
    the cell's own south edge, its lower layer left flat on the ground."""
    role = J["role"]
    return {(x, y): y for (x, y) in cells if role[y][x] == "tree"}


# -- camera -----------------------------------------------------------------------

class Camera:
    def __init__(self, eye, target=None, fov=53.13, forward=None):
        self.eye = np.array(eye, float)
        if forward is None:
            forward = np.array(target, float) - self.eye
        f = np.array(forward, float)
        f /= np.linalg.norm(f)
        up = np.array([0.0, 1.0, 0.0])
        r = np.cross(f, up)
        r /= np.linalg.norm(r)
        u = np.cross(r, f)
        self.f, self.r, self.u = f, r, u
        self.k = (HEIGHT / 2.0) / math.tan(math.radians(fov) / 2.0)

    def project(self, P):
        d = P - self.eye
        zc = d @ self.f
        xc = d @ self.r
        yc = d @ self.u
        zc_safe = np.where(zc > 1e-3, zc, 1e-3)
        sx = WIDTH / 2.0 + xc / zc_safe * self.k
        sy = HEIGHT / 2.0 - yc / zc_safe * self.k
        return sx, sy, zc


def game_camera(level, fx, fy, fz, vh=360.0):
    """fx, fz: the focus (player's cell centre), fy its ground height."""
    if level == 7:
        eye = (fx, fy + 48.0, fz + 75.0)
        a = math.radians(4.5)
        return Camera(eye, forward=(0.0, -math.sin(a), -math.cos(a)), fov=62.0)
    a = math.radians(50.0)          # from vertical
    dist = 1.18 * vh
    eye = (fx, fy + dist * math.cos(a), fz + dist * math.sin(a))
    return Camera(eye, target=(fx, fy, fz), fov=2 * math.degrees(math.atan(0.5)))


# -- the scene ----------------------------------------------------------------------

def build(J, layout, grids, cx, cy, span_x, span_y0, span_y1, variant):
    W, H = J["w"], J["h"]
    face_id = J["face_tile"]
    face = layout.art.image(face_id)
    sc = Scene()
    cells = [(x, y) for y in range(cy - span_y0, cy + span_y1 + 1)
             for x in range(cx - span_x, cx + span_x + 1)]
    inside = [(x, y) for (x, y) in cells if 0 <= x < W and 0 <= y < H]
    cards = tree_cards(J, layout, grids, inside)
    # outside the map: a plain grey table under the map, so what is drawn
    # is only the map (our game fills past the edge with its own ground; 3DS
    # lays one belt). Edge cells are walled down to it.
    grids = dict(grids)
    outside = [(x, y) for (x, y) in cells if (x, y) not in grids]
    for (x, y) in outside:
        nx, ny = min(max(x, 0), W - 1), min(max(y, 0), H - 1)
        grids[(x, y)] = np.full((N + 1, N + 1), float(np.min(grids[(nx, ny)])) - 8.0)
    grey = np.zeros((16, 16, 3), np.uint8) + np.array([118, 122, 120], np.uint8)
    grey[::4, :] = (108, 112, 110)
    grey[:, ::4] = (108, 112, 110)
    for (x, y) in outside:
        cell_surface(sc, x, y, grids[(x, y)], grey)
        cliff_walls(sc, x, y, grids[(x, y)], grids, grey)
        back_fill(sc, x, y, grids[(x, y)], grids, {(x, y - 1): grey})
    imgs = {}
    for (x, y) in inside:
        m = layout.metatile(x, y)
        img = layout.art.image(m)
        if (x, y) in cards:
            lo = layout.art.lower(m)
            img = np.where(lo[..., 3:4] > 0, lo[..., :3], img)
        imgs[(x, y)] = img
    for (x, y) in outside:
        imgs[(x, y)] = grey
    for (x, y) in inside:
        g = grids[(x, y)]
        cell_surface(sc, x, y, g, imgs[(x, y)])
        cliff_walls(sc, x, y, g, grids, wall_tile(J, layout, x, y, face))
        back_fill(sc, x, y, g, grids, imgs)
    for (x, y), yb in cards.items():
        # the card: a vertical plane at the trunk's south edge, a level a cell
        base = float(np.min(grids[(x, yb)]))
        for cy_ in range(y, yb + 1):
            m = layout.metatile(x, cy_)
            up = layout.art.upper(m)
            mask = up[..., 3] > 0
            if not mask.any():
                continue
            rows_above = yb - cy_       # cells above the trunk row
            # a vertical plane: h = base + 16*(rows_above+1) - (v - cy_*16)
            top = base + 16.0 * (rows_above + 1)
            gcard = np.array([[top - 16.0 * j / N] * (N + 1) for j in range(N + 1)])
            # (u, h, v + h): with h falling a pixel a pixel down the cell the
            # card is vertical at z = (yb + 1) * 16 + base
            cell_surface(sc, x, cy_, gcard, up[..., :3], mask=mask)
    return sc


def _border(layout):
    p = os.path.join(E.GBA, 'map_tree', 'maps', layout.slot, 'border.bin')
    if not os.path.exists(p):
        return None
    b = open(p, 'rb').read()
    import struct
    v = struct.unpack('<%dH' % (len(b) // 2), b)
    return [t & 0x3FF for t in v][:4]


def sky(img):
    d = ImageDraw.Draw(img)
    for yy in range(HEIGHT):
        t = yy / float(HEIGHT)
        d.line([(0, yy), (WIDTH, yy)], fill=(int(150 + 60 * t), int(190 + 40 * t), int(235 + 10 * t)))


def draw(sc, cam):
    T = np.array(sc.tris, float)            # (n, 3, 3)
    C = np.array(sc.cols, np.uint8)
    sx, sy, zc = cam.project(T.reshape(-1, 3))
    sx, sy, zc = sx.reshape(-1, 3), sy.reshape(-1, 3), zc.reshape(-1, 3)
    ok = (zc > 2.0).all(1)
    ok &= (sx.max(1) >= 0) & (sx.min(1) < WIDTH) & (sy.max(1) >= 0) & (sy.min(1) < HEIGHT)
    depth = zc.mean(1)
    idx = np.nonzero(ok)[0]
    idx = idx[np.argsort(-depth[idx], kind="stable")]
    img = Image.new("RGB", (WIDTH, HEIGHT))
    sky(img)
    d = ImageDraw.Draw(img)
    for t in idx:
        c = tuple(int(v) for v in C[t])
        d.polygon([(sx[t, 0], sy[t, 0]), (sx[t, 1], sy[t, 1]), (sx[t, 2], sy[t, 2])], fill=c, outline=c)
    return img


def belt_height(J, grids):
    """One belt height for the map's border: the commonest floor of its
    walkable edge cells (else of all its edge cells)."""
    import collections
    W, H = J["w"], J["h"]
    edge_cells = [(x, y) for y in range(H) for x in range(W) if x in (0, W - 1) or y in (0, H - 1)]
    walk = [c for c in edge_cells if J["role"][c[1]][c[0]] in ("floor", "water")]
    pool = walk or edge_cells
    cnt = collections.Counter(round(float(np.min(grids[c])) / 16.0) * 16 for c in pool)
    return float(cnt.most_common(1)[0][0])


def render(json_path, x, y, level, out, variant="theirs", vh=360.0):
    J, layout, grids = load(json_path)
    if variant == "tall":
        # ours, a mock-up: the counted relief 1.5x taller (24 px a level)
        # with soft, more rolling tops. The faces stretch here; a real build
        # would repeat their rows instead.
        global ROLL
        grids = {c: g * 1.5 for c, g in grids.items()}
        ROLL = 6.0
        grids = soften(J, grids)
    elif variant == "soft":
        grids = soften(J, grids)
    g = grids[(x, y)]
    fy = float(g[N // 2, N // 2])
    fx, fz = x * 16 + 8.0, y * 16 + 8.0
    if level == 7:
        sc = build(J, layout, grids, x, y, 26, 26, 6, variant)
    else:
        sc = build(J, layout, grids, x, y, 26, 20, 16, variant)
    cam = game_camera(level, fx, fy, fz + fy, vh)
    img = draw(sc, cam)
    img.save(out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("json")
    ap.add_argument("x", type=int)
    ap.add_argument("y", type=int)
    ap.add_argument("level", type=int)
    ap.add_argument("out")
    ap.add_argument("--variant", default="theirs", choices=("theirs", "soft", "tall"))
    ap.add_argument("--vh", type=float, default=360.0)
    a = ap.parse_args()
    render(a.json, a.x, a.y, a.level, a.out, a.variant, a.vh)
    print(a.out)


if __name__ == "__main__":
    main()
