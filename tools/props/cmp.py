#!/usr/bin/env python3
"""cmp.py OLD_DIR NEW_DIR [N]  -- rank captures by pixel difference, write OUT/cmp_NN.png (before | after), 3 per image.
Both dirs must hold the same manifest (same case order)."""
import sys, json
from PIL import Image, ImageChops, ImageStat, ImageDraw
a, b = sys.argv[1], sys.argv[2]
top = int(sys.argv[3]) if len(sys.argv) > 3 else 12
m = json.load(open(b + '/manifest.json'))
res = []
for i, e in enumerate(m):
    try:
        x = Image.open('%s/b%03d.png' % (a, i + 1)).convert('RGB'); y = Image.open('%s/b%03d.png' % (b, i + 1)).convert('RGB')
    except Exception:
        continue
    res.append((sum(ImageStat.Stat(ImageChops.difference(x, y)).mean), i, e))
res.sort(key=lambda r: -r[0])
print('changed (>1):', sum(1 for r in res if r[0] > 1), 'of', len(res))
sel = res[:top]
for k in range(0, len(sel), 3):
    out = Image.new('RGB', (1280, 3 * 270))
    for j, (d, i, e) in enumerate(sel[k:k + 3]):
        x = Image.open('%s/b%03d.png' % (a, i + 1)).convert('RGB').crop((320, 150, 960, 420))
        y = Image.open('%s/b%03d.png' % (b, i + 1)).convert('RGB').crop((320, 150, 960, 420))
        out.paste(x, (0, j * 270)); out.paste(y, (640, j * 270))
        ImageDraw.Draw(out).text((6, j * 270 + 4), '%s %03X %s  diff %.1f' % (e['pair'][9:], e['mid'], e['map'][3:], d), fill=(255, 255, 0))
    out.save('%s/cmp_%02d.png' % (b, k // 3 + 1))
