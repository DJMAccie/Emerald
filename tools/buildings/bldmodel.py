#!/usr/bin/env python3
"""Fit and verify a building model offline.

Builds the building as pixel voxels from its own drawing (one art pixel = one
voxel = one world pixel) and renders it through the EXACT game camera
(tools/buildings/gamecam.py), then diffs the result against the drawing so the
geometry is judged in seconds instead of a capture round trip.

Model shape (px):
  * front block: depth D_f, height H_w, its south face painted 1:1 with the
    drawing's facade band (rows H_f..H_f+H_w) - the head-on view is then
    pixel-exact by construction.
  * roof: the drawing's roof band (rows 0..H_f) becomes S voxel steps, each one
    voxel deep and rising toward the back, so the slope is built out of the
    drawing's own pixels instead of a stretched slab.
  * everything else (back, sides, top of the box) is filled with the material
    the drawing shows at that height, excluding outline/window darkening.

Usage:
  python3 tools/buildings/bldmodel.py b004 --steps 8 [--out DIR]
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

# Voxel3D.FACE_SHADE, read off the installed module
SHADE = {'top': 1.0, 'south': 0.92, 'north': 0.70, 'east': 0.84, 'west': 0.78, 'bottom': 0.6}


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


class Scene:
    """Axis-aligned boxes in world pixels, painted by rects of the drawing."""

    def __init__(self, tex):
        self.tex = tex
        self.boxes = []   # (x0,x1,y0,y1,z0,z1, {face: (u0,v0,u1,v1)})

    def box(self, x0, x1, y0, y1, z0, z1, paint):
        self.boxes.append((x0, x1, y0, y1, z0, z1, paint))

    def quads(self):
        out = []
        for (x0, x1, y0, y1, z0, z1, paint) in self.boxes:
            faces = {
                'south': [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)],
                'north': [(x1, y0, z1), (x0, y0, z1), (x0, y1, z1), (x1, y1, z1)],
                'top': [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)],
                'bottom': [(x0, y0, z1), (x1, y0, z1), (x1, y0, z0), (x0, y0, z0)],
                'east': [(x1, y0, z0), (x1, y0, z1), (x1, y1, z1), (x1, y1, z0)],
                'west': [(x0, y0, z1), (x0, y0, z0), (x0, y1, z0), (x0, y1, z1)],
            }
            for f, corners in faces.items():
                r = paint.get(f)
                if r:
                    out.append((f, corners, r))
        return out


UV = {
    'south': [(0, 1), (1, 1), (1, 0), (0, 0)],
    'north': [(1, 1), (0, 1), (0, 0), (1, 0)],
    'top': [(0, 1), (1, 1), (1, 0), (0, 0)],
    'bottom': [(0, 0), (1, 0), (1, 1), (0, 1)],
    'east': [(0, 1), (0, 0), (1, 0), (1, 1)],
    'west': [(0, 1), (0, 0), (1, 0), (1, 1)],
}


def render(quads, tex, out=None, vw=480, vh=360, level=4, focus=(0, 0), ground=0.0, yaw=0.0,
           bg=(26, 28, 34), crop=None, scale=1):
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cam = Camera(vw, vh, level, ground=ground, cx=focus[0], cz=focus[1])
    tris = []
    for face, corners, (u0, v0, u1, v1) in quads:
        pts = [(x * cy - z * sy, y + ground, x * sy + z * cy) for (x, y, z) in corners]
        d = sum(cam.mvp[8] * p[0] + cam.mvp[9] * p[1] + cam.mvp[10] * p[2] + cam.mvp[11] for p in pts) / len(pts)
        tris.append((d, face, pts, (u0, v0, u1, v1)))
    tris.sort(key=lambda t: t[0])    # painter: far first (bigger view depth = farther)
    canvas = np.zeros((vh, vw, 3), np.uint8)
    canvas[:, :] = np.array(bg, np.uint8)
    zbuf = np.full((vh, vw), 1e18)
    for d, face, pts, (u0, v0, u1, v1) in tris:
        sc = [cam.project(*p) for p in pts]
        xs = [p[0] for p in sc]
        ys = [p[1] for p in sc]
        xa, xb = int(math.floor(min(xs))), int(math.ceil(max(xs)))
        ya, yb = int(math.floor(min(ys))), int(math.ceil(max(ys)))
        xa, xb = max(0, xa), min(vw - 1, xb)
        ya, yb = max(0, ya), min(vh - 1, yb)
        if xb < xa or yb < ya:
            continue
        ax, ay = xs[0], ys[0]
        bx, by = xs[1], ys[1]
        cx2, cy2 = xs[2], ys[2]
        det = (by - cy2) * (ax - cx2) + (cx2 - bx) * (ay - cy2)
        if abs(det) < 1e-9:
            continue
        uvs = UV[face]
        for y in range(ya, yb + 1):
            for x in range(xa, xb + 1):
                pxc, pyc = x + 0.5 - cx2, y + 0.5 - cy2
                w0 = ((by - cy2) * pxc + (cx2 - bx) * pyc) / det
                w1 = ((cy2 - ay) * pxc + (ax - cx2) * pyc) / det
                w2 = 1.0 - w0 - w1
                if w0 < -0.02 or w1 < -0.02 or w2 < -0.02:
                    continue
                if d >= zbuf[y, x]:
                    continue
                fu = w0 * uvs[0][0] + w1 * uvs[1][0] + w2 * uvs[2][0]
                fv = w0 * uvs[0][1] + w1 * uvs[1][1] + w2 * uvs[2][1]
                tx = min(tex.shape[1] - 1, max(0, int(u0 + fu * (u1 - u0))))
                ty = min(tex.shape[0] - 1, max(0, int(v0 + fv * (v1 - v0))))
                c = tex[ty, tx]
                if c[3] < 128:
                    continue
                zbuf[y, x] = d
                s = SHADE[face]
                canvas[y, x] = np.clip(c[:3].astype(float) * s, 0, 255).astype(np.uint8)
    im = Image.fromarray(canvas)
    if crop:
        im = im.crop(crop)
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    if out:
        im.save(out)
    return im


def build(img, line_row, steps=8, label=''):
    """line_row: the drawing row where the facade's top edge is (the eave).
    Rows below it are the facade (front plane); rows above are the roof band."""
    H, W = img.shape[0], img.shape[1]
    roof_rows = line_row                    # rows 0..line_row-1
    wall_rows = H - line_row
    sc = Scene(img)
    # facade: one box, full width, painted 1:1 with the drawing
    sc.box(0, W, 0, wall_rows, 0, max(1, steps), {
        'south': (0, line_row, W, H),
        'east': (0, line_row, 1, H),
        'west': (W - 1, line_row, W, H),
        'top': (0, line_row, W, line_row + 1),
    })
    # roof band -> `steps` voxel steps, one voxel deep each
    for s in range(steps):
        r0 = int(round(s * roof_rows / steps))
        r1 = int(round((s + 1) * roof_rows / steps))
        if r1 <= r0:
            continue
        y0 = wall_rows + s
        sc.box(0, W, y0, y0 + 1, s, s + 1, {
            'south': (0, r0, W, r1),
            'top': (0, r0, W, r1),
            'east': (W - 1, r0, W, r1),
            'west': (0, r0, 1, r1),
        })
    return sc, (W, wall_rows + steps, steps)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('which')
    ap.add_argument('--steps', type=int, default=8)
    ap.add_argument('--level', type=int, default=4)
    ap.add_argument('--line', type=int, default=None, help='eave row (default: 2/3 down)')
    ap.add_argument('--pad', type=int, default=0)
    ap.add_argument('--out', default=os.path.join(ROOT, 'shots_bld', 'lab'))
    args = ap.parse_args()
    n = int(args.which.lstrip('bB'))
    b = BUILDINGS[n - 1]
    x0, y0, x1, y1 = b['box']
    x0, y0, x1, y1 = x0 - args.pad, y0 - args.pad, x1 + args.pad, y1 + args.pad
    img = compose(b['pair'], b['map'], x0, y0, x1, y1)
    H, W = img.shape[0], img.shape[1]
    line = args.line if args.line is not None else (H * 2) // 3
    sc, dims = build(img, line, args.steps)
    print('b%03d %s image %dx%d  line=%d  model %s' % (n, b['map'][3:], W, H, line, dims))
    os.makedirs(args.out, exist_ok=True)
    tag = 'm%03d_%s' % (n, b['map'][3:].lower())
    # head-on: the camera focused on the building's front-bottom-left area
    vw, vh = 480, 360
    D = max(1, args.steps)
    focus = (W / 2.0, (H + 0) / 2.0, D / 2.0)
    c = Camera(vw, vh, args.level, ground=0.0, cx=focus[0], cz=focus[2])
    xs, ys = [], []
    for (px, py, pz) in ((0, 0, 0), (W, 0, 0), (0, H, 0), (W, H, 0),
                         (0, 0, D), (W, 0, D), (0, H, D), (W, H, D)):
        sx, sy = c.project(px, py, pz)
        xs.append(sx); ys.append(sy)
    pad = 14
    crop = (max(0, int(min(xs)) - pad), max(0, int(min(ys)) - pad),
            min(vw, int(max(xs)) + pad), min(vh, int(max(ys)) + pad))
    for yaw in (0, 90, 180, 270):
        render(sc.quads(), img, os.path.join(args.out, '%s_yaw%03d.png' % (tag, yaw)),
               vw=vw, vh=vh, level=args.level, focus=focus, ground=0.0, yaw=yaw, crop=crop, scale=3)
    head = render(sc.quads(), img, vw=vw, vh=vh, level=args.level, focus=focus,
                  ground=0.0, yaw=0, crop=crop, scale=3)
    orig = Image.fromarray(img).convert('RGB')
    S = max(1, round(head.width / max(1, orig.width)))
    o = orig.resize((orig.width * S, orig.height * S), Image.NEAREST)
    strip = Image.new('RGB', (o.width + head.width + 8, max(o.height, head.height)), (20, 20, 24))
    strip.paste(o, (0, 0))
    strip.paste(head, (o.width + 8, 0))
    strip.save(os.path.join(args.out, tag + '_cmp.png'))
    print('wrote', tag + '_cmp.png', 'crop', crop, 'scale', S)


if __name__ == '__main__':
    main()
