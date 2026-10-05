#!/usr/bin/env python3
"""Offline building-model lab: build a building as pixel voxels from its own
drawing and render it through the EXACT game camera (tools/buildings/gamecam.py
ports Mat4 + Voxel3D.viewProjection), so the head-on view can be diffed against
the drawing without a game run.

Rule (docs/VOXEL-BUILDINGS.md): one art pixel = one voxel unit = one world
pixel. Nothing is stretched: every visible face shows one pixel of the drawing.

A building is a yaw-aligned solid described by SLABS: {z0,z1,y0,y1, src, paint}
  * z is depth from the building's front face, 0 at the front, +z = away.
  * y is height above the building's base.
  * paint = 'row:y' paints the +z (south) face with drawing row y;
            'top:y' paints the +y face with drawing row y;
            'flat:y,x' paints every other face with that one pixel.
"""
import argparse, json, math, os, sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
import layers
import voxproto
from gamecam import Camera

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
BUILDINGS = json.load(open(os.path.expanduser('~/Documents/gen1recomp-modwork/buildings.json')))


def compose(pair, map_id, x0, y0, x1, y1):
    L = layers.load(pair)
    W, H, cells = voxproto.map_cells(map_id)
    w, h = x1 - x0 + 1, y1 - y0 + 1
    img = np.zeros((h * 16, w * 16, 4), np.uint8)
    for yy in range(h):
        for xx in range(w):
            mid = cells[(y0 + yy) * W + x0 + xx] & 0x3FF
            u = layers.tile(L, 'u', mid)
            if u is None:
                continue
            t = u.astype(float)
            o = layers.tile(L, 'o', mid) if 'o' in L else None
            if o is not None:
                k = o[..., 3:4] / 255.0
                t[..., :3] = o[..., :3] * k + t[..., :3] * (1 - k)
                t[..., 3:4] = np.maximum(t[..., 3:4], o[..., 3:4])
            img[yy * 16:(yy + 1) * 16, xx * 16:(xx + 1) * 16] = t.astype(np.uint8)
    return img


FACE_SHADE = {'top': 1.0, 'south': 0.92, 'north': 0.70, 'east': 0.84, 'west': 0.78, 'bottom': 0.6}


def slab_quads(sl, w):
    """The six faces of one slab, as (face, corners, paint)."""
    x0, x1 = 0, w
    y0, y1 = sl['y0'], sl['y1']
    z0, z1 = sl['z0'], sl['z1']
    p = sl.get('paint', {})
    out = []
    # south (+z, toward the camera): at depth z0
    out.append(('south', [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], p.get('south')))
    out.append(('north', [(x1, y0, z1), (x0, y0, z1), (x0, y1, z1), (x1, y1, z1)], p.get('north')))
    out.append(('top', [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], p.get('top')))
    out.append(('bottom', [(x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0)], p.get('bottom')))
    out.append(('east', [(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)], p.get('east')))
    out.append(('west', [(x0, y0, z1), (x0, y0, z0), (x0, y1, z0), (x0, y1, z1)], p.get('west')))
    return out


def shade(name, base=1.0):
    return FACE_SHADE[name] * base


def render_mesh(quads, tex, out, vw, vh, level, focus_x, focus_z, ground=0.0,
                yaw=0.0, zoom=1.0, bg=(24, 26, 34)):
    """Rasterise slabs through the game camera + a yaw about the building."""
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    tris = []
    for face, corners, paint in quads:
        if paint is None:
            continue
        # yaw the model about its own centre in world pixels
        pts = []
        for (x, y, z) in corners:
            rx = x * cy - z * sy
            rz = x * sy + z * cy
            pts.append((rx, y + ground, rz))
        tris.append((face, pts, paint))
    cam = Camera(vw, vh, level, ground=ground, cx=focus_x, cz=focus_z)
    S = zoom
    px = np.array(bg, np.uint8)
    canvas = np.zeros((vh, vw, 3), np.uint8)
    canvas[:, :] = px
    # painter's algorithm: sort by mean view depth (far first) using the camera
    def depth(pts):
        return sum(cam.mvp[8] * p[0] + cam.mvp[9] * p[1] + cam.mvp[10] * p[2] + cam.mvp[11] for p in pts) / len(pts)
    tris.sort(key=lambda t: depth(t[1]))
    zbuf = np.full((vh, vw), 1e18)
    for face, pts, paint in tris:
        sc = [cam.project(*p) for p in pts]
        xs = [(p[0] - vw / 2) * S + vw / 2 for p in sc]
        ys = [(p[1] - vh / 2) * S + vh / 2 for p in sc]
        x0, x1 = int(math.floor(min(xs))), int(math.ceil(max(xs)))
        y0, y1 = int(math.floor(min(ys))), int(math.ceil(max(ys)))
        x0, x1 = max(0, x0), min(vw - 1, x1)
        y0, y1 = max(0, y0), min(vh - 1, y1)
        if x1 < x0 or y1 < y0:
            continue
        ax, ay = xs[0], ys[0]
        bx, by = xs[1], ys[1]
        cx2, cy2 = xs[2], ys[2]
        det = (by - cy2) * (ax - cx2) + (cx2 - bx) * (ay - cy2)
        if abs(det) < 1e-9:
            continue
        # the paint rect in source pixels: (u0,v0) top-left of the art rect
        u0, v0, uw, vh_ = paint
        # uv per corner, 0..1 across the rect, in the drawing's orientation
        uvs = paint_uvs(face, uw, vh_)
        d0 = depth(pts)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                pxc, pyc = x + 0.5 - cx2, y + 0.5 - cy2
                w0 = ((by - cy2) * pxc + (cx2 - bx) * pyc) / det
                w1 = ((cy2 - ay) * pxc + (ax - cx2) * pyc) / det
                w2 = 1.0 - w0 - w1
                if w0 < -0.02 or w1 < -0.02 or w2 < -0.02:
                    continue
                if d0 >= zbuf[y, x]:
                    continue
                u = w0 * uvs[0][0] + w1 * uvs[1][0] + w2 * uvs[2][0]
                v = w0 * uvs[0][1] + w1 * uvs[1][1] + w2 * uvs[2][1]
                tx = min(tex.shape[1] - 1, max(0, int(u0 + u * uw)))
                ty = min(tex.shape[0] - 1, max(0, int(v0 + v * vh_)))
                c = tex[ty, tx]
                if c[3] < 128:
                    continue
                zbuf[y, x] = d0
                s = shade(face)
                canvas[y, x] = np.clip(c[:3].astype(float) * s, 0, 255).astype(np.uint8)
    Image.fromarray(canvas).save(out)
    return canvas


def paint_uvs(face, uw, vh_):
    """Corner order for slab_quads, u across the drawing, v down it."""
    if face == 'south':
        return [(0, 1), (1, 1), (1, 0), (0, 0)]     # x0y0 x1y0 x1y1 x0y1
    if face == 'north':
        return [(1, 1), (0, 1), (0, 0), (1, 0)]
    if face == 'top':
        return [(0, 1), (1, 1), (1, 0), (0, 0)]
    if face == 'bottom':
        return [(0, 0), (1, 0), (1, 1), (0, 1)]
    if face == 'east':
        return [(0, 1), (0, 0), (1, 0), (1, 1)]
    return [(0, 1), (0, 0), (1, 0), (1, 1)]


def build_center(img, line, wall_rows):
    """Placeholder recipe used while the generic algorithm is fitted."""
    raise NotImplementedError


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('which')
    ap.add_argument('--level', type=int, default=4)
    ap.add_argument('--out', default=os.path.join(ROOT, 'shots_bld', 'lab'))
    args = ap.parse_args()
    n = int(args.which.lstrip('bB'))
    b = BUILDINGS[n - 1]
    x0, y0, x1, y1 = b['box']
    img = compose(b['pair'], b['map'], x0, y0, x1, y1)
    print('image', img.shape)
    print('slab lab: see bld3d.py for structures')


if __name__ == '__main__':
    main()
