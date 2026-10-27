#!/usr/bin/env python3
# cave_sheet.py <batchdir> <outdir> <specfile> [variant=game]  two spots per image, row = [2D crop | L4 | L6 | L7]
import sys, os, glob, subprocess
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata
_man = emdata.manifest(); _norm = {k[3:].replace('_', ''): k for k in _man}
_orig = emdata.em_name
emdata.em_name = lambda i: _norm.get(i.replace('_', '').upper()) or _orig(i)
from PIL import Image, ImageDraw
BD, OUT, SPOTS = sys.argv[1:4]; V = sys.argv[4] if len(sys.argv) > 4 else 'game'
os.makedirs(OUT, exist_ok=True)
specs = [l.strip() for l in open(SPOTS) if l.strip()]
CW, CH, CR = 560, 315, 360
def shot(m, x, y, lv):
    fs = glob.glob('%s/%s_%s_%d_%d/%s_%d*.png' % (BD, V, m, x, y, m, lv))
    return Image.open(sorted(fs)[0]).convert('RGB').resize((CW, CH)) if fs else Image.new('RGB', (CW, CH), 'black')
for i in range(0, len(specs), 2):
    img = Image.new('RGB', (CR + CW * 3, CH * 2), 'black'); names = []
    for j, s in enumerate(specs[i:i + 2]):
        m, x, y = s.split(','); x = int(x); y = int(y); names.append('%s_%d_%d' % (m, x, y))
        L = emdata.Layout(m)
        crop = '/tmp/claude-501/crop_%s_%d_%d.png' % (m, x, y)
        os.makedirs('/tmp/claude-501', exist_ok=True)
        subprocess.run(['python3', '/Users/user/Documents/Emerald/skills/emerald-terrain/scripts/crop2d.py', L.slot, L.pair,
                        str(max(0, x - 9)), str(max(0, y - 13)), str(min(L.w - 1, x + 9)), str(min(L.h - 1, y + 3)), crop, '1'], check=True)
        c = Image.open(crop).convert('RGB'); c.thumbnail((CR, CH)); img.paste(c, (0, j * CH))
        for k, lv in enumerate((4, 6, 7)):
            im = shot(m, x, y, lv); d = ImageDraw.Draw(im); d.rectangle((0, 0, 330, 12), fill=(0, 0, 0))
            d.text((2, 1), '%s %d,%d L%d' % (m[3:], x, y, lv), fill=(255, 255, 0)); img.paste(im, (CR + k * CW, j * CH))
    img.save('%s/S_%03d.png' % (OUT, i // 2)); open('%s/S_%03d.txt' % (OUT, i // 2), 'w').write('\n'.join(names) + '\n')
print(len(specs))
