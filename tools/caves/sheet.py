#!/usr/bin/env python3
# sheet.py <batch> <outdir> <variants comma list, default old> MAP,x,y ...   one sheet per spot: col 0 = 2D original, then per variant rows = level 4/6/7
import sys, os, subprocess, glob
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
_man = emdata.manifest(); _norm = {k[3:].replace('_', ''): k for k in _man}
_orig = emdata.em_name
emdata.em_name = lambda i: _norm.get(i.replace('_', '').upper()) or _orig(i)
from PIL import Image, ImageDraw
B, OUT, VARS = sys.argv[1], sys.argv[2], sys.argv[3].split(',')
BD = os.path.expanduser('~/Documents/Emerald/docs/rock-gates/caves/') + B
os.makedirs(OUT, exist_ok=True)
W, H = 640, 360
def find(d, m, lv):
    fs = sorted(glob.glob('%s/%s_%d*.png' % (d, m, lv)))
    return Image.open(fs[0]).convert('RGB') if fs else None
for spec in sys.argv[4:]:
    m, x, y = spec.split(','); x = int(x); y = int(y)
    L = emdata.Layout(m)
    crop = '%s/crop_%s_%d_%d.png' % (OUT, m, x, y)
    subprocess.run(['python3', '/Users/user/Documents/Emerald/skills/emerald-terrain/scripts/crop2d.py', L.slot, L.pair,
                    str(max(0, x - 9)), str(max(0, y - 13)), str(min(L.w - 1, x + 9)), str(min(L.h - 1, y + 3)), crop, '2'], check=True)
    c = Image.open(crop).convert('RGB')
    sh = Image.new('RGB', ((1 + len(VARS)) * W, 3 * H), 'black')
    cs = c.copy(); cs.thumbnail((W, 3 * H)); sh.paste(cs, (0, 0))
    for i, lv in enumerate((4, 6, 7)):
        for j, v in enumerate(VARS):
            im = find('%s/%s_%s_%d_%d' % (BD, v, m, x, y), m, lv)
            if im is None: continue
            im = im.resize((W, H))
            d = ImageDraw.Draw(im); d.rectangle((0, 0, 280, 16), fill=(0, 0, 0))
            d.text((3, 2), '%s %s %d,%d L%d' % (v.upper(), m[3:], x, y, lv), fill=(255, 255, 0))
            sh.paste(im, ((j + 1) * W, i * H))
    sh.save('%s/S_%s_%d_%d.png' % (OUT, m, x, y)); print('S_%s_%d_%d.png' % (m, x, y))
