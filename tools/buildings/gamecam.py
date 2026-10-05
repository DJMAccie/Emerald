#!/usr/bin/env python3
"""Exact replica of the mod's diorama camera, for offline model fitting.

Ports Mat4.lookAt/perspective and Voxel3D.viewProjection's orbit branch, so a
world (x,y,z) can be projected to the engine's own screen coordinates without
launching the game. Used to read a building drawing's oblique projection back
into model coordinates (tools/buildings/fitcam.py --table).
"""
import math


def mat_mul(a, b):
    o = [0.0] * 16
    for r in range(4):
        a0, a1, a2, a3 = a[r * 4:r * 4 + 4]
        for c in range(4):
            o[r * 4 + c] = a0 * b[c] + a1 * b[4 + c] + a2 * b[8 + c] + a3 * b[12 + c]
    return o


def perspective(fovy, aspect, near, far):
    f = 1 / math.tan(fovy / 2)
    d = near - far
    return [f / aspect, 0, 0, 0,
            0, f, 0, 0,
            0, 0, (far + near) / d, (2 * far * near) / d,
            0, 0, -1, 0]


def look_at(eye, target, up):
    def sub(a, b): return [a[i] - b[i] for i in range(3)]
    def norm(v):
        l = math.sqrt(sum(c * c for c in v))
        return [0.0, 0.0, 0.0] if l == 0 else [c / l for c in v]
    def cross(a, b): return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
    def dot(a, b): return sum(a[i] * b[i] for i in range(3))
    f = norm(sub(target, eye))
    s = norm(cross(f, up))
    u = cross(s, f)
    return [s[0], s[1], s[2], -dot(s, eye),
            u[0], u[1], u[2], -dot(u, eye),
            -f[0], -f[1], -f[2], dot(f, eye),
            0, 0, 0, 1]


def scale(x, y, z):
    return [x, 0, 0, 0, 0, y, 0, 0, 0, 0, z, 0, 0, 0, 0, 1]


class Camera:
    """Voxel3D.viewProjection's orbit branch for a centred focus."""

    FOCAL = 1.0
    ANGLES_DEG = [0, 35, 15, 35, 50, 75, 75, 75]

    def __init__(self, vw, vh, level=4, ground=0.0, cx=0.0, cz=0.0):
        self.vh = vh
        self.vw = vw
        self.ground = ground
        self.cx = cx
        self.cz = cz
        self.a = math.radians(self.ANGLES_DEG[level])
        dist = self.FOCAL * vh
        fov = 2 * math.atan(1 / (2 * self.FOCAL))
        self.dist = dist
        self.focus = [cx, ground, cz]
        self.eye = [cx, ground + dist * math.cos(self.a), cz + dist * math.sin(self.a)]
        self.up = [0, math.sin(self.a), -math.cos(self.a)]
        proj = perspective(fov, vw / vh, max(1, dist * 0.05), dist * 4 + 4096)
        proj = mat_mul(scale(1, -1, 1), proj)
        self.mvp = mat_mul(proj, look_at(self.eye, self.focus, self.up))
        self.fov = fov

    def project(self, x, y, z):
        """World pixel -> canvas pixel (y down), origin top-left of the canvas."""
        m = self.mvp
        cx = m[0] * x + m[1] * y + m[2] * z + m[3]
        cy = m[4] * x + m[5] * y + m[6] * z + m[7]
        cw = m[12] * x + m[13] * y + m[14] * z + m[15]
        ndc_x, ndc_y = cx / cw, cy / cw
        return ((ndc_x + 1) * 0.5 * self.vw, (ndc_y + 1) * 0.5 * self.vh)

    def screen_delta(self, dx=0.0, dy=0.0, dz=0.0):
        """Screen offset (px, py) of a small world delta, from the origin."""
        x0, y0 = self.project(self.cx, self.ground, self.cz)
        x1, y1 = self.project(self.cx + dx, self.ground + dy, self.cz + dz)
        return x1 - x0, y1 - y0


if __name__ == '__main__':
    vw, vh = 240 * 3, 160 * 3
    for level in (4, 7):
        cam = Camera(vw, vh, level)
        print('level', level, 'angle', Camera.ANGLES_DEG[level], 'dist', cam.dist)
        for name, d in (('+x16', (16, 0, 0)), ('+y16', (0, 16, 0)), ('-y16', (0, -16, 0)),
                        ('+z16', (0, 0, 16)), ('-z16', (0, 0, -16)), ('+z64', (0, 0, 64)),
                        ('y16 z16', (0, 16, 16)), ('y16 z-16', (0, 16, -16))):
            print('   %-8s -> %s' % (name, tuple(round(v, 3) for v in cam.screen_delta(*d))))
