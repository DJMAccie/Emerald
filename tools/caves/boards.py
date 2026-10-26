#!/usr/bin/env python3
# boards.py <batch> <variant> <outdir> <spots file>   review boards: 4 spots per image, row = [2D crop | L4 | L6 | L7]
import sys, os, glob, subprocess
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
_man = emdata.manifest(); _norm = {k[3:].replace('_', ''): k for k in _man}
_orig = emdata.em_name
emdata.em_name = lambda i: _norm.get(i.replace('_', '').upper()) or _orig(i)
from PIL import Image, ImageDraw
B, V, OUT, SPOTS = sys.argv[1:5]
BD = os.path.expanduser('~/Documents/Emerald/docs/rock-gates/caves/') + B
os.makedirs(OUT, exist_ok=True)
specs = [l.strip() for l in open(SPOTS) if l.strip()]
CW, CH = 400, 225
def shot(m, x, y, lv):
    fs = glob.glob('%s/%s_%s_%d_%d/%s_%d*.png' % (BD, V, m, x, y, m, lv))
    return Image.open(sorted(fs)[0]).convert('RGB').resize((CW, CH)) if fs else Image.new('RGB', (CW, CH), 'black')
n = 0
for i in range(0, len(specs), 4):
    img = Image.new('RGB', (CW * 3 + 300, CH * 4), 'black')
    for j, s in enumerate(specs[i:i + 4]):
        m, x, y = s.split(','); x = int(x); y = int(y)
        L = emdata.Layout(m)
        crop = '/tmp/claude-501/crop_%s_%d_%d.png' % (m, x, y)
        subprocess.run(['python3', '/Users/user/Documents/Emerald/skills/emerald-terrain/scripts/crop2d.py', L.slot, L.pair,
                        str(max(0, x - 9)), str(max(0, y - 13)), str(min(L.w - 1, x + 9)), str(min(L.h - 1, y + 3)), crop, '1'], check=True)
        c = Image.open(crop).convert('RGB'); c.thumbnail((300, CH)); img.paste(c, (0, j * CH))
        for k, lv in enumerate((4, 6, 7)): img.paste(shot(m, x, y, lv), (300 + k * CW, j * CH))
        d = ImageDraw.Draw(img); d.rectangle((300, j * CH, 300 + 300, j * CH + 12), fill=(0, 0, 0)); d.text((302, j * CH + 1), '%s %d,%d' % (m[3:], x, y), fill=(255, 255, 0))
    img.save('%s/board_%s_%02d.png' % (OUT, B, n)); n += 1
print(n, 'boards')
