#!/usr/bin/env python3
"""Height-pin drawing sheets for every cave map: original art at 48 px per cell, grid, x/y numbers.
  python3 cave_sheets.py <cache-with-all-pairs> <outdir>
Identical layouts (same pair and tiles) get one sheet; aliases are listed in <outdir>/_same.txt."""
import sys, os, re, json, glob, hashlib
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import ref
cache, out = sys.argv[1], sys.argv[2]
os.makedirs(out, exist_ok=True)
man = open(os.path.join(cache, 'native', 'manifest.lua')).read()
pairs = dict(re.findall(r'\["(EM_[A-Z0-9_]+)"\] = \{ pair = "([^"]+)"', man))
def em(name): return 'EM_' + re.sub(r'(?<=[a-z])(?=[A-Z])', '_', name).replace('__', '_').upper()
seen, same, skipped = {}, {}, []
for f in sorted(glob.glob(os.path.join(cache, 'map_tree', 'maps', '*', 'header.json'))):
    h = json.load(open(f))
    if h.get('mapType') not in (4, 9): continue
    mid = em(h['id'])
    if mid.startswith(('EM_ABANDONED_SHIP', 'EM_NEW_MAUVILLE')): continue
    if mid not in pairs: skipped.append(mid); continue
    try: m = ref.load_map(mid, cache, os.path.basename(os.path.dirname(f)), pairs[mid])
    except Exception as e: skipped.append(mid + ' ' + str(e)[:40]); continue
    key = hashlib.md5(pairs[mid].encode() + m['mid'].tobytes() + m['coll'].tobytes()).hexdigest()
    if key in seen: same.setdefault(seen[key], []).append(mid); continue
    seen[key] = mid
    W, H = m['W'], m['H']
    im = Image.fromarray(m['img'], 'RGBA')
    bg = Image.new('RGBA', im.size, (0, 0, 0, 255)); bg.alpha_composite(im)
    im = bg.convert('RGB').resize((W * 48, H * 48), Image.NEAREST)
    d = ImageDraw.Draw(im)
    for x in range(W + 1):
        d.line([(x * 48, 0), (x * 48, H * 48)], fill=(255, 255, 255) if x % 5 == 0 else (90, 90, 90))
        if x % 5 == 0: d.text((x * 48 + 2, 2), str(x), fill=(255, 255, 0))
    for y in range(H + 1):
        d.line([(0, y * 48), (W * 48, y * 48)], fill=(255, 255, 255) if y % 5 == 0 else (90, 90, 90))
        if y % 5 == 0: d.text((2, y * 48 + 2), str(y), fill=(255, 255, 0))
    im.save(os.path.join(out, mid + '.png'))
open(os.path.join(out, '_same.txt'), 'w').write(''.join('%s = %s\n' % (k, ', '.join(v)) for k, v in same.items()))
print(len(seen), 'sheets;', sum(len(v) for v in same.values()), 'same as another;', 'skipped', skipped)
