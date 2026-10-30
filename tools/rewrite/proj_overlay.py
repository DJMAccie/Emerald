#!/usr/bin/env python3
"""Overlay a cell grid on a clean-mod L4 capture (verifier tool).

The clean mod's play camera is a fixed diorama (emerald3d lib/Camera3D.lua):
eye (footX, 420, footZ+300), target (footX, 0, footZ-20), fov 35 deg,
canvas 1280x720. `footX/footZ` are the player's feet in world px
(cell*16 + 8, cell*16 + 16). This replicates that projection so a screenshot
can be read cell by cell (which cell is that pale rim?).

usage: proj_overlay.py <shot.png> <playerX> <playerY> [cell step] [out.png]
"""
import sys
import math
import numpy as np
from PIL import Image, ImageDraw

EYE_UP, EYE_BACK, LOOK = 420.0, 300.0, 20.0
FOV = math.radians(35.0)
W = H = None


def look_at(eye, target, up=(0.0, 1.0, 0.0)):
    f = np.array(target) - np.array(eye)
    f = f / np.linalg.norm(f)
    u0 = np.array(up)
    s = np.cross(f, u0)
    s = s / np.linalg.norm(s)
    u = np.cross(s, f)
    m = np.eye(4)
    m[0, :3], m[1, :3], m[2, :3] = s, u, -f
    m[:3, 3] = -m[:3, :3] @ np.array(eye)
    return m


def perspective(fov, aspect, near, far):
    t = 1.0 / math.tan(fov / 2.0)
    m = np.zeros((4, 4))
    m[0, 0] = t / aspect
    m[1, 1] = t
    m[2, 2] = (far + near) / (near - far)
    m[2, 3] = 2 * far * near / (near - far)
    m[3, 2] = -1.0
    return m


def make(px, py, w, h):
    footX, footZ = px * 16 + 8, py * 16 + 16
    eye = (footX, EYE_UP, footZ + EYE_BACK)
    tgt = (footX, 0.0, footZ - LOOK)
    # proj() = scale(1,-1,1) @ perspective, i.e. the flip comes AFTER the projection
    vp = perspective(FOV, w / h, 1.0, 2000.0) @ look_at(eye, tgt)
    return np.diag([1.0, -1.0, 1.0, 1.0]) @ vp


def project(vp, x, y, z, w, h):
    c = vp @ np.array([x, y, z, 1.0])
    if c[3] <= 1e-6:
        return None
    ndc = c[:3] / c[3]
    sy = (ndc[1] * 0.5 + 0.5) * h   # the flip is already in vp (Camera3D.proj)
    return (ndc[0] * 0.5 + 0.5) * w, sy


def main():
    shot, pxx, pyy = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    step = int(sys.argv[4]) if len(sys.argv) > 4 else 1
    out = sys.argv[5] if len(sys.argv) > 5 else shot.replace('.png', '_grid.png')
    im = Image.open(shot).convert('RGB')
    w, h = im.size
    # the mod's proj() negates clip Y, so the canvas y runs down from ndcY
    vp = make(pxx, pyy, w, h)
    d = ImageDraw.Draw(im, 'RGBA')
    gx0, gx1 = pxx - 18, pxx + 18
    gy0, gy1 = pyy - 24, pyy + 14
    for gy in range(gy0, gy1 + 1, step):
        pts = []
        for gx in range(gx0, gx1 + 1):
            p = project(vp, gx * 16, 0, gy * 16, w, h)
            if p:
                pts.append(p)
        if len(pts) > 1:
            d.line(pts, fill=(0, 0, 0, 120), width=1)
        p = project(vp, gx0 * 16 + 2, 0, gy * 16 + 2, w, h)
        if p:
            d.text(p, str(gy), fill=(0, 0, 0, 255))
    for gx in range(gx0, gx1 + 1, step):
        pts = []
        for gy in range(gy0, gy1 + 1):
            p = project(vp, gx * 16, 0, gy * 16, w, h)
            if p:
                pts.append(p)
        if len(pts) > 1:
            d.line(pts, fill=(0, 0, 0, 120), width=1)
        p = project(vp, gx * 16 + 2, 0, gy1 * 16 + 2, w, h)
        if p:
            d.text(p, str(gx), fill=(0, 0, 0, 255))
    im.save(out)
    print(out)


if __name__ == '__main__':
    main()
