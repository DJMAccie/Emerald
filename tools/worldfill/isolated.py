#!/usr/bin/env python3
"""Find maps the connections do not reach (Battle Frontier, Southern Island, ...) in the filled reference, by exact tiles."""
import os, json, numpy as np
from collections import defaultdict
from PIL import Image
import world as Wd, ref as R
Image.MAX_IMAGE_PIXELS = None
reg = json.load(open('ref/register.json'))
refimg = np.asarray(Image.open('ref/filled.png').convert('RGB'))
CH, CW = refimg.shape[0] // 16, refimg.shape[1] // 16
blocks = refimg[:CH * 16, :CW * 16].reshape(CH, 16, CW, 16, 3).transpose(0, 2, 1, 3, 4)
where = defaultdict(list)
keys = np.empty((CH, CW), object)
for y in range(CH):
    for x in range(CW):
        k = blocks[y, x].tobytes(); keys[y, x] = k; where[k].append((x, y))
def q8(a): return ((a.astype(np.int32) * 31 + 127) // 255) * 8
w = Wd.load_world()
inworld = {e['pretId'] for e in w.values()}
hs = Wd.headers()
WORLDJ = {m['id']: m for m in json.load(open(R.WORLD))['maps']}
found = {}
for pid, h in hs.items():
    if pid in inworld or not h.get('emId') or h['emId'] not in WORLDJ: continue
    if h['width'] * h['height'] < 64 or h.get('mapType') not in (1, 2, 3, 5, 6, 9): continue
    try: m = R.load_map(h['emId'], slot=h['slot'])
    except SystemExit: continue
    img = q8(m['img'][..., :3]).astype(np.uint8)
    H, W = h['height'], h['width']
    mk = img.reshape(H, 16, W, 16, 3).transpose(0, 2, 1, 3, 4)
    cand = sorted(((len(where.get(mk[y, x].tobytes(), ())), x, y) for y in range(0, H, 3) for x in range(0, W, 3)))
    best = (0, None)
    for n, x, y in cand[:6]:
        if n == 0 or n > 400: continue
        for (rx, ry) in where[mk[y, x].tobytes()]:
            ox, oy = rx - x, ry - y
            if ox < 0 or oy < 0 or ox + W > CW or oy + H > CH: continue
            hit = sum(keys[oy + j, ox + i] == mk[j, i].tobytes() for j in range(0, H, 2) for i in range(0, W, 2))
            tot = len(range(0, H, 2)) * len(range(0, W, 2))
            if hit / tot > best[0]: best = (hit / tot, (ox, oy))
    if best[0] > .5:
        ox, oy = best[1]
        found[h['emId']] = {'ox': ox - reg['px'] // 16 + reg['world_x0'], 'oy': oy - reg['py'] // 16 + reg['world_y0'],
                            'W': W, 'H': H, 'match': round(best[0], 3), 'mapType': h.get('mapType')}
        print(h['emId'], found[h['emId']])
json.dump(found, open('ref/isolated.json', 'w'), indent=1)
