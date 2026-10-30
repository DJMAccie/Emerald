#!/usr/bin/env python3
"""Overlay a cell grid on a play-camera (L4) capture (verifier tool).

Replicates emerald3d lib/Camera3D.lua's play rig, which is the INSTALLED LOOK's own
(GeometryCore.md s3.5): pitch 50 deg off vertical, distance FOCAL*vh*1.18 with
vh = the canvas height, lens 2*atan(1/(2*FOCAL)) = 53.13 deg, focus on the player's
cell centre AT THE MAP PLANE (y = 0, not the floor), up = (0, sin a, -cos a).
The 1.18 is Voxel3D's depth-style factor and the y=0 focus is what Gen3Scene's
beginScene actually draws with; both were measured with
tools/rewrite/probe/cam_driver.lua on 2026-10-30. The same projection now works on
the installed look's captures AND on ours (fit 1.00/0 between them), so a spot can
be read cell by cell (which cell is that pale rim?).

usage: proj_overlay.py <shot.png> <playerX> <playerY> [cell step] [out.png] [groundY]
"""
import sys
import math
import numpy as np
from PIL import Image, ImageDraw

LADDER_DEG = 50.0
FOCAL = 1.0
DEPTH_STYLE = 1.18
FOV = 2.0 * math.atan(1.0 / (2.0 * FOCAL))
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
    a = math.radians(LADDER_DEG)
    cx, cz = px * 16 + 8, py * 16 + 8          # the player's CELL CENTRE
    dist = FOCAL * h * DEPTH_STYLE              # h = the canvas height = vh
    eye = (cx, dist * math.cos(a), cz + dist * math.sin(a))
    tgt = (cx, 0.0, cz)                         # focus on the map plane, y = 0
    up = (0.0, math.sin(a), -math.cos(a))
    # proj() = scale(1,-1,1) @ perspective, i.e. the flip comes AFTER the projection
    vp = perspective(FOV, w / h, max(1.0, dist * 0.05), dist * 4 + 4096.0) @ look_at(eye, tgt, up)
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
    # the fitted camera sees ~71 cells north and ~7 south of the player, and
    # ±63 cells at its far edge: cover that so a far rim can be read too
    gx0, gx1 = pxx - 40, pxx + 40
    gy0, gy1 = pyy - 46, pyy + 14
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
