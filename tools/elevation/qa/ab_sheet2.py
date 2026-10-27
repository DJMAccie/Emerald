#!/usr/bin/env python3
"""ab_sheet2.py <run dir> <level> <out prefix> <name filter> [width]: like ab_sheet but only spots whose dir name contains any of the filter words (comma list)."""
import sys, os, glob
from PIL import Image, ImageDraw
run, lv, out, flt = sys.argv[1:5]; W = int(sys.argv[5]) if len(sys.argv) > 5 else 560
fl = flt.split(','); rows = []
for d in sorted(glob.glob(os.path.join(run, 'new', '*_y*/'))):
    n = os.path.basename(d.rstrip('/'))
    if not any(f in n for f in fl): continue
    a = glob.glob(os.path.join(run, 'old', n, '*_%s.png' % lv)); b = glob.glob(os.path.join(d, '*_%s.png' % lv))
    if a and b: rows.append((n, Image.open(a[0]).convert('RGB'), Image.open(b[0]).convert('RGB')))
h = int(rows[0][1].height * W / rows[0][1].width)
S = Image.new('RGB', (2 * W + 10, len(rows) * (h + 22)), (30, 30, 30)); dr = ImageDraw.Draw(S)
for i, (n, a, b) in enumerate(rows):
    y = i * (h + 22); dr.text((4, y + 4), n + '    old | new', fill=(255, 255, 255))
    S.paste(a.resize((W, h), Image.LANCZOS), (0, y + 22)); S.paste(b.resize((W, h), Image.LANCZOS), (W + 10, y + 22))
S.save(out); print(out, S.size, len(rows))
