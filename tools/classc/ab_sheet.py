#!/usr/bin/env python3
# ab_sheet.py OUT.png OLD_LABEL NEW_LABEL MAP x,y [x,y ...]   rows = spots, cols = old L4/L6/L7 | new L4/L6/L7 (.autoloop/runs/<label>/<MAP>_<x>_<y>/<MAP>_<lv>.png)
import sys, os
from PIL import Image, ImageDraw
out, old, new, mp = sys.argv[1:5]
spots = sys.argv[5:]
R = os.path.expanduser('~/Documents/Emerald/.autoloop/runs')
CW = 480
rows = []
for s in spots:
    x, y = s.split(',')
    ims = []
    for lab in (old, new):
        for lv in (4, 6, 7):
            p = '%s/%s/%s_%s_%s/%s_%d.png' % (R, lab, mp, x, y, mp, lv)
            if os.path.exists(p):
                im = Image.open(p).convert('RGB'); im = im.resize((CW, int(im.height * CW / im.width)))
            else:
                im = Image.new('RGB', (CW, 270), (40, 0, 0))
            ims.append(im)
    rows.append((s, ims))
H = max(i.height for _, ims in rows for i in ims)
sheet = Image.new('RGB', (CW * 6, (H + 14) * len(rows)), (0, 0, 0))
d = ImageDraw.Draw(sheet)
for r, (s, ims) in enumerate(rows):
    y0 = r * (H + 14)
    d.text((2, y0 + 1), '%s %s,%s   OLD L4 L6 L7 | NEW L4 L6 L7' % (mp, *s.split(',')), fill=(255, 255, 0))
    for c, im in enumerate(ims):
        sheet.paste(im, (c * CW, y0 + 14))
sheet.save(out)
print(out, sheet.size)
