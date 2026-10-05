#!/usr/bin/env python3
"""Full-frame montage of an audit capture dir: mont.py OUTDIR  -> OUTDIR/mont_NN.png (2x2 per image)"""
import sys, json
from PIL import Image, ImageDraw
d = sys.argv[1]
m = json.load(open(d + '/manifest.json'))
for k in range(0, len(m), 4):
    out = Image.new('RGB', (1280, 720))
    for j, e in enumerate(m[k:k + 4]):
        try:
            im = Image.open('%s/b%03d.png' % (d, k + j + 1)).convert('RGB').resize((640, 360))
        except Exception:
            continue
        ImageDraw.Draw(im).text((6, 6), '%s %03X' % (e['map'][3:], e['mid']), fill=(255, 255, 0))
        out.paste(im, ((j % 2) * 640, (j // 2) * 360))
    out.save('%s/mont_%02d.png' % (d, k // 4 + 1))
print((len(m) + 3) // 4)
