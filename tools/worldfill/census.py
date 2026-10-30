#!/usr/bin/env python3
"""Classify every reference cell outside the connected maps: open sea, an exact metatile of some outdoor pair, or neither."""
import os, sys, json, glob, numpy as np
from collections import Counter, defaultdict
from PIL import Image
import world as Wd, ref as R
Image.MAX_IMAGE_PIXELS = None
reg = json.load(open('ref/register.json'))
refimg = np.asarray(Image.open('ref/filled.png').convert('RGB'))
RH, RW = refimg.shape[:2]
CH, CW = RH // 16, RW // 16
w = Wd.load_world()
cov = np.zeros((CH, CW), bool)
cx0, cy0 = reg['px'] // 16, reg['py'] // 16
for e in w.values():
    x, y = e['ox'] - reg['world_x0'] + cx0, e['oy'] - reg['world_y0'] + cy0
    cov[y:y + e['H'], x:x + e['W']] = True
def q8(a): return ((a.astype(np.int32) * 31 + 127) // 255) * 8
# every pair any map uses (world.json), quantized composite blocks -> (pair, mid)
WORLD = json.load(open(R.WORLD))
pairs = sorted({m['pair'] for m in WORLD['maps'] if m.get('pair')})
table = {}
for p in pairs:
    d = os.path.join(R.CACHE, 'native', p)
    if not os.path.exists(os.path.join(d, 'mids.idx')): continue
    count, cols, rows, ids = R.read_idx(os.path.join(d, 'mids.idx'))
    layers = []
    for tag in ('u', 'm', 'o'):
        f = glob.glob(os.path.join(d, 'atlas_%s_*.rgba' % tag))
        layers.append(R.read_rgba(f[0], cols * 16, rows * 16) if f else None)
    comp = R.composite(layers)
    rgb = q8(comp[..., :3])
    for s, mid in enumerate(ids):
        sx, sy = (s % cols) * 16, (s // cols) * 16
        key = rgb[sy:sy + 16, sx:sx + 16].astype(np.uint8).tobytes()
        table.setdefault(key, (p, mid))
print(len(pairs), 'pairs,', len(table), 'distinct metatile looks')
SEA = np.array([80, 104, 208], np.uint8)
cls = Counter(); bypair = Counter(); nomatch = []
out = np.zeros((CH, CW), np.int8)  # 0 map, 1 sea, 2 match, 3 none
for cy in range(CH):
    for cx in range(CW):
        if cov[cy, cx]: continue
        b = refimg[cy * 16:cy * 16 + 16, cx * 16:cx * 16 + 16]
        if (b == SEA).all(): out[cy, cx] = 1; cls['sea'] += 1; continue
        hit = table.get(b.tobytes())
        if hit: out[cy, cx] = 2; cls['match'] += 1; bypair[hit] += 1
        else: out[cy, cx] = 3; cls['none'] += 1
print(cls)
print('top matched tiles', bypair.most_common(25))
np.save('ref/census.npy', out)
col = np.array([[0, 0, 0], [80, 104, 208], [60, 200, 60], [255, 0, 255]], np.uint8)
Image.fromarray(col[out]).resize((CW * 2, CH * 2), Image.NEAREST).save('ref/census.png')
