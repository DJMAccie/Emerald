#!/usr/bin/env python3
# ab.py <batch> <outdir> <spots file> [variants old,new]   A/B boards, 3 spots per image: row = [2D crop | old L4 | new L4 | old L7 | new L7]; add LV=6 to use level 6 for the second pair
import sys, os, glob, subprocess
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
_man = emdata.manifest(); _norm = {k[3:].replace('_', ''): k for k in _man}
_orig = emdata.em_name
emdata.em_name = lambda i: _norm.get(i.replace('_', '').upper()) or _orig(i)
from PIL import Image, ImageDraw
B, OUT, SPOTS = sys.argv[1:4]
V = (sys.argv[4] if len(sys.argv) > 4 else 'old,new').split(',')
LV2 = int(os.environ.get('LV', '7'))
BD = os.path.expanduser('~/Documents/Emerald/docs/rock-gates/caves/') + B
os.makedirs(OUT, exist_ok=True)
specs = [l.strip() for l in open(SPOTS) if l.strip()]
CW, CH = 400, 225
def shot(v, m, x, y, lv):
    fs = glob.glob('%s/%s_%s_%d_%d/%s_%d*.png' % (BD, v, m, x, y, m, lv))
    return Image.open(sorted(fs)[0]).convert('RGB').resize((CW, CH)) if fs else Image.new('RGB', (CW, CH), 'black')
n = 0
for i in range(0, len(specs), 3):
    img = Image.new('RGB', (300 + CW * 4, CH * 3), 'black')
    for j, s in enumerate(specs[i:i + 3]):
        m, x, y = s.split(','); x = int(x); y = int(y)
        L = emdata.Layout(m)
        crop = '/tmp/claude-501/crop_%s_%d_%d.png' % (m, x, y)
        subprocess.run(['python3', '/Users/user/Documents/Emerald/skills/emerald-terrain/scripts/crop2d.py', L.slot, L.pair,
                        str(max(0, x - 9)), str(max(0, y - 13)), str(min(L.w - 1, x + 9)), str(min(L.h - 1, y + 3)), crop, '1'], check=True)
        c = Image.open(crop).convert('RGB'); c.thumbnail((300, CH)); img.paste(c, (0, j * CH))
        k = 0
        for lv in (4, LV2):
            for v in V:
                img.paste(shot(v, m, x, y, lv), (300 + k * CW, j * CH))
                d = ImageDraw.Draw(img); d.rectangle((300 + k * CW, j * CH, 300 + k * CW + 200, j * CH + 12), fill=(0, 0, 0))
                d.text((302 + k * CW, j * CH + 1), '%s L%d %s %d,%d' % (v.upper(), lv, m[3:30], x, y), fill=(255, 255, 0)); k += 1
    img.save('%s/ab_%s_%02d.png' % (OUT, B, n)); n += 1
print(n, 'boards')
