#!/usr/bin/env python3
# cmp3.py <out.png> MAP,x,y  NOWdir  VARdir...  : rows L4/L6/L7, cols 2D | NOW | variants
import sys, glob, subprocess
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
from PIL import Image, ImageDraw
out, spec, now, *vs = sys.argv[1:]
m, x, y = spec.split(','); x = int(x); y = int(y)
L = emdata.Layout(m); crop = '/tmp/claude-501/c3_%s_%d_%d.png' % (m, x, y)
subprocess.run(['python3', '/Users/user/Documents/Emerald/skills/emerald-terrain/scripts/crop2d.py', L.slot, L.pair, str(max(0, x - 9)), str(max(0, y - 13)), str(min(L.w - 1, x + 9)), str(min(L.h - 1, y + 3)), crop, '2'], check=True)
W, H = 480, 270; cols = [now] + vs
sh = Image.new('RGB', (W + len(cols) * W, 3 * H), 'black')
c = Image.open(crop).convert('RGB'); c.thumbnail((W, 3 * H)); sh.paste(c, (0, 0))
for j, d in enumerate(cols):
    for i, lv in enumerate((4, 6, 7)):
        f = sorted(glob.glob('%s/game_%s_%d_%d/%s_%d.png' % (d, m, x, y, m, lv)))
        if not f: continue
        im = Image.open(f[0]).convert('RGB').resize((W, H)); dr = ImageDraw.Draw(im); dr.rectangle((0, 0, 200, 12), fill=(0, 0, 0))
        dr.text((2, 1), '%s L%d' % (d.split('/')[-1], lv), fill=(255, 255, 0)); sh.paste(im, (W + j * W, i * H))
sh.save(out)
