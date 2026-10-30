#!/usr/bin/env python3
"""Find where the connected world sits in the filled reference (tools/worldfill/ref/filled.png): cell offset + pixel phase."""
import sys, json, numpy as np
from PIL import Image
import world as Wd
Image.MAX_IMAGE_PIXELS = None
ref = np.asarray(Image.open('ref/filled.png').convert('RGB')).astype(np.float32)
RH, RW = ref.shape[:2]
w = Wd.load_world()
img, cov, (x0, y0) = Wd.cell_means(w)
H, W = cov.shape
best = None
for py in (0,):
    for px in (0,):
        r = ref[py:py + (RH - py) // 16 * 16, px:px + (RW - px) // 16 * 16]
        rm = r.reshape(r.shape[0] // 16, 16, r.shape[1] // 16, 16, 3).mean(axis=(1, 3))
        for dy in range(0, rm.shape[0] - H + 1):
            for dx in range(0, rm.shape[1] - W + 1):
                d = np.abs(rm[dy:dy + H, dx:dx + W] - img)[cov].mean()
                if best is None or d < best[0]:
                    best = (d, dx, dy)
print('coarse', best)
d, dx, dy = best
# pixel phase: compare full-res Littleroot
import ref as R
m = R.load_map('EM_LITTLEROOT_TOWN', slot=w['EM_LITTLEROOT_TOWN']['slot'])
a = m['img'][..., :3].astype(np.float32)
lx, ly = (0 - x0 + dx) * 16, (0 - y0 + dy) * 16
res = []
for oy in range(-24, 25):
    for ox in range(-24, 25):
        sub = ref[ly + oy:ly + oy + a.shape[0], lx + ox:lx + ox + a.shape[1]]
        if sub.shape != a.shape: continue
        res.append((np.abs(sub - a).mean(), ox, oy, (np.abs(sub - a).sum(axis=2) == 0).mean()))
res.sort()
print('pixel', res[:3])
e, ox, oy, exact = res[0]
json.dump({'world_x0': x0, 'world_y0': y0, 'px': lx + ox - (0 - x0) * 16, 'py': ly + oy - (0 - y0) * 16},
          open('ref/register.json', 'w'))
print(open('ref/register.json').read())
