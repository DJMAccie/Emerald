#!/usr/bin/env python3
# mapsheets.py  one image per map: rows = spots, cols = 2D original | 3D level 4 | level 6 | level 7 (from ab_sheet AB_*.png)
import csv, os, collections
from PIL import Image, ImageDraw
S = os.path.expanduser('~/Documents/Emerald/docs/rock-gates/ALL-ROCKS/sheets')
OUT = os.path.expanduser('~/Documents/Emerald/docs/rock-gates/ALL-ROCKS/maps')
os.makedirs(OUT, exist_ok=True)
W, H = 1280 // 4, 720 // 4 * 1   # unused; cell size below
CW, CH = 400, 225
by = collections.defaultdict(list)
for r in csv.DictReader(open('spots.csv')): by[r['map']].append(r)
for m, rs in by.items():
    img = Image.new('RGB', (4 * CW, len(rs) * CH), 'black')
    for i, r in enumerate(rs):
        f = '%s/AB_%s_%s_%s.png' % (S, m, r['sx'], r['sy'])
        if not os.path.exists(f): continue
        a = Image.open(f)
        # ab_sheet: 4 columns of 640x360, 3 rows; col0 = 2D crop (tall), cols 1: old at rows level 4/6/7
        c0 = a.crop((0, 0, 640, 1080)); c0.thumbnail((CW, CH)); img.paste(c0, (0, i * CH))
        for j in range(3):
            c = a.crop((640, j * 360, 1280, (j + 1) * 360)).resize((CW, CH)); img.paste(c, ((j + 1) * CW, i * CH))
        d = ImageDraw.Draw(img); d.rectangle((0, i * CH, 330, i * CH + 12), fill=(0, 0, 0))
        d.text((2, i * CH + 1), '%s %s,%s %s n=%s bad=%s' % (m[3:], r['sx'], r['sy'], r['builder'], r['n'], r['bad']), fill=(255, 255, 0))
    img.save('%s/%s.png' % (OUT, m))
print(len(by))
