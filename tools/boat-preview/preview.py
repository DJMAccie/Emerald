#!/usr/bin/env python3
"""Offline preview of the M.boat mesh dumped by harness.lua - no game, no capture.

Usage (from the repo root):
    python3 tools/boat-preview/gen_pixels.py 88 > /tmp/pixels.lua
    luajit tools/boat-preview/harness.lua ~/Documents/battle-art-notquiteog /tmp/pixels.lua > /tmp/boat_mesh.txt
    python3 tools/boat-preview/preview.py            # writes boat_preview.png in $PWD

Renders the mesh with a z-buffer from a few camera angles, colouring each vertex with the
sprite texel its uv names (so it matches the in-game colours, not a guess).
"""
import math
import os
import re
from pathlib import Path

import numpy as np
from PIL import Image

MESH = Path(os.environ.get("MESH", "/tmp/boat_mesh.txt"))
PIXELS = Path(os.environ.get("PIXELS", "/tmp/pixels.lua"))
OUT = Path(os.environ.get("OUT", "boat_preview.png"))


def load_mesh():
    verts, idx = [], []
    for line in MESH.read_text().splitlines():
        p = line.split()
        if not p:
            continue
        if p[0] == "V":
            verts.append([float(x) for x in p[1:7]])
        elif p[0] == "I":
            idx.append(int(p[1]))
    return np.array(verts, dtype=float), np.array(idx, dtype=int)


def load_sheet():
    rows = re.findall(r'^"([0-9a-fA-F]+)",$', PIXELS.read_text(), re.M)
    w = len(rows[0]) // 8
    im = Image.new("RGBA", (w, len(rows)))
    px = im.load()
    for y, row in enumerate(rows):
        for x in range(w):
            h = row[x * 8:(x + 1) * 8]
            px[x, y] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4, 6))
    return im


def render(verts, idx, sheet, pitch, yaw, scale=30.0, pad=20):
    W, H = sheet.size
    p, a = math.radians(pitch), math.radians(yaw)
    x = verts[:, 0] * math.cos(a) + verts[:, 2] * math.sin(a)
    z = -verts[:, 0] * math.sin(a) + verts[:, 2] * math.cos(a)
    y = verts[:, 1]
    sx = x
    sy = -y * math.cos(p) + z * math.sin(p)
    depth = -y * math.sin(p) - z * math.cos(p)      # bigger = farther from this camera
    cols = np.zeros((len(verts), 3))
    for i, v in enumerate(verts):
        u = min(W - 1, max(0, int(v[3] * W)))
        w = min(H - 1, max(0, int(v[4] * H)))
        r, g, b, _ = sheet.getpixel((u, w))
        cols[i] = (r * v[5], g * v[5], b * v[5])
    minx, miny = sx.min(), sy.min()
    cw = int((sx.max() - minx) * scale) + 2 * pad
    ch = int((sy.max() - miny) * scale) + 2 * pad
    img = np.zeros((ch, cw, 3), dtype=np.float32)
    zbuf = np.full((ch, cw), np.inf)
    px = (sx - minx) * scale + pad
    py = (sy - miny) * scale + pad
    for t in range(len(idx) // 3):
        t0, t1, t2 = idx[t * 3] - 1, idx[t * 3 + 1] - 1, idx[t * 3 + 2] - 1
        xs, ys = [px[t0], px[t1], px[t2]], [py[t0], py[t1], py[t2]]
        ds = [depth[t0], depth[t1], depth[t2]]
        den = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(den) < 1e-9:
            continue
        for yy in range(max(0, int(min(ys))), min(ch, int(max(ys)) + 1)):
            for xx in range(max(0, int(min(xs))), min(cw, int(max(xs)) + 1)):
                w0 = ((ys[1] - ys[2]) * (xx + .5 - xs[2]) + (xs[2] - xs[1]) * (yy + .5 - ys[2])) / den
                w1 = ((ys[2] - ys[0]) * (xx + .5 - xs[2]) + (xs[0] - xs[2]) * (yy + .5 - ys[2])) / den
                w2 = 1 - w0 - w1
                if w0 < 0 or w1 < 0 or w2 < 0:
                    continue
                d = w0 * ds[0] + w1 * ds[1] + w2 * ds[2]
                if d < zbuf[yy, xx]:
                    zbuf[yy, xx] = d
                    img[yy, xx] = (w0 * cols[t0] + w1 * cols[t1] + w2 * cols[t2]) / 255.0
    return Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))


def main():
    verts, idx = load_mesh()
    sheet = load_sheet()
    # yaw 0 looks from the south (the player camera side), 180 from the bow, 90 from the west
    views = [(44, 0), (44, 180), (50, 90), (75, 0)]
    tiles = [render(verts, idx, sheet, p, y) for p, y in views]
    h = max(t.height for t in tiles)
    w = sum(t.width for t in tiles) + 10 * (len(tiles) - 1)
    out = Image.new("RGB", (w, h), (20, 22, 30))
    x = 0
    for t in tiles:
        out.paste(t, (x, 0))
        x += t.width + 10
    out.save(OUT)
    print("wrote", OUT, out.size)


if __name__ == "__main__":
    main()
