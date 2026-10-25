#!/usr/bin/env python3
# cmp.py <label_a> <label_b> out.png  spot dirs side by side: rows = spots, cols = a L7 | b L7 (and L4)
import sys, os, glob
from PIL import Image, ImageDraw
R = os.path.expanduser('~/Documents/Emerald/.autoloop/runs')
a, b, out = sys.argv[1:4]
spots = sorted(d for d in os.listdir('%s/%s' % (R, b)) if os.path.isdir('%s/%s/%s' % (R, b, d)))
CW, CH = 400, 225
im = Image.new('RGB', (4 * CW, len(spots) * CH), 'black')
for i, s in enumerate(spots):
    for j, (lab, lv) in enumerate([(a, 4), (b, 4), (a, 7), (b, 7)]):
        fs = glob.glob('%s/%s/%s/*_%d.png' % (R, lab, s, lv))
        if not fs: continue
        t = Image.open(fs[0]).convert('RGB').resize((CW, CH)); im.paste(t, (j * CW, i * CH))
        d = ImageDraw.Draw(im); d.rectangle((j * CW, i * CH, j * CW + 200, i * CH + 12), fill=(0, 0, 0)); d.text((j * CW + 2, i * CH + 1), '%s %s L%d' % (lab, s[3:], lv), fill=(255, 255, 0))
im.save(out); print(out, len(spots))
