#!/usr/bin/env python3
# overlay_pins.py MAP [out.png]: draw docs/elevation/pins/<MAP>.txt onto the drawing sheet (blue), downscaled for sending.
import sys, os
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..', '..')
m = sys.argv[1]; out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'docs', 'elevation', 'pins', m + '_read.png')
im = Image.open(os.path.join(ROOT, 'docs', 'elevation', 'draw', m + '.png')).convert('RGB')
d = ImageDraw.Draw(im)
try: font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 40)
except Exception: font = ImageFont.load_default()
S, H0 = 48, 40
for line in open(os.path.join(ROOT, 'docs', 'elevation', 'pins', m + '.txt')):
    t = line.split('#')[0].split()
    if len(t) < 3: continue
    x, y, h = int(t[0]), int(t[1]), t[2]
    cx, cy = x * S, H0 + y * S
    d.rectangle([cx, cy, cx + S, cy + S], outline=(0, 90, 255), width=4)
    d.text((cx + 6, cy - 44), h + ('' if h.isdigit() else ' ' + ' '.join(t[3:])), fill=(0, 90, 255), font=font)
w = 1500; im = im.resize((w, int(im.height * w / im.width)), Image.LANCZOS); im.save(out); print(out, im.size)
