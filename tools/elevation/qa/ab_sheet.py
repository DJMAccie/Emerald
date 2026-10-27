#!/usr/bin/env python3
"""ab_sheet.py <run dir> <level> <out.png> [width]: old | new per spot, one row each, from cap_pins.sh output."""
import sys, os, glob
from PIL import Image, ImageDraw
run, lv, out = sys.argv[1], sys.argv[2], sys.argv[3]; W = int(sys.argv[4]) if len(sys.argv) > 4 else 700
rows = []
for d in sorted(glob.glob(os.path.join(run, 'new', '*_y*/'))):
    n = os.path.basename(d.rstrip('/')); o = os.path.join(run, 'old', n)
    a = glob.glob(os.path.join(o, '*_%s.png' % lv)); b = glob.glob(os.path.join(d, '*_%s.png' % lv))
    if a and b: rows.append((n, Image.open(a[0]).convert('RGB'), Image.open(b[0]).convert('RGB')))
if not rows: sys.exit('no pairs')
h = int(rows[0][1].height * W / rows[0][1].width)
S = Image.new('RGB', (2 * W + 10, len(rows) * (h + 24)), (30, 30, 30)); dr = ImageDraw.Draw(S)
for i, (n, a, b) in enumerate(rows):
    y = i * (h + 24); dr.text((4, y + 4), n + '    old | new', fill=(255, 255, 255))
    S.paste(a.resize((W, h), Image.LANCZOS), (0, y + 24)); S.paste(b.resize((W, h), Image.LANCZOS), (W + 10, y + 24))
S.save(out); print(out, S.size)
