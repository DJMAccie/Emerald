#!/usr/bin/env python3
# sheet2.py OUT.png MAP LABEL_A LABEL_B x,y ...   rows = spot x level (4,7); cols = A | B   (.autoloop/runs/<label>/<MAP>_<x>_<y>/*_<lv>.png)
import sys, glob, os
from PIL import Image, ImageDraw
out, mp, A, B = sys.argv[1:5]; R = os.path.expanduser('~/Documents/Emerald/.autoloop/runs/')
W, H = 640, 360; rows = [(s, lv) for s in sys.argv[5:] for lv in (4, 7)]
im = Image.new('RGB', (2 * W, H * len(rows)))
for i, (s, lv) in enumerate(rows):
    for j, lab in enumerate((A, B)):
        fs = glob.glob('%s%s/%s_%s/*_%d.png' % (R, lab, mp, s.replace(',', '_'), lv))
        if fs:
            im.paste(Image.open(fs[0]).convert('RGB').resize((W, H)), (j * W, i * H))
        d = ImageDraw.Draw(im); d.text((j * W + 3, i * H + 2), '%s %s L%d' % (lab, s, lv), fill=(255, 255, 0))
im.save(out)
