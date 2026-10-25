#!/usr/bin/env python3
# abmaps.py <new label under .autoloop/runs> <outdir> [spots file]  per map: rows = spots; cols = OLD L4 | NEW L4 | OLD L7 | NEW L7 (old = docs/rock-gates/general-rollout/allrocks1)
import sys, os, glob, collections
from PIL import Image, ImageDraw
R = os.path.expanduser('~/Documents/Emerald')
new, out = sys.argv[1], sys.argv[2]
spots = [l.strip() for l in open(sys.argv[3] if len(sys.argv) > 3 else R + '/tools/searock/spotsB.txt') if l.strip()]
os.makedirs(out, exist_ok=True)
by = collections.defaultdict(list)
for s in spots: by[s.split(',')[0]].append(s)
CW, CH = 400, 225
for m, ss in by.items():
    im = Image.new('RGB', (4 * CW, len(ss) * CH), 'black')
    for i, s in enumerate(ss):
        mm, x, y = s.split(',')
        for j, (kind, lv) in enumerate([('old', 4), ('new', 4), ('old', 7), ('new', 7)]):
            d = '%s/docs/rock-gates/general-rollout/allrocks1/old_%s_%s_%s' % (R, mm, x, y) if kind == 'old' else '%s/.autoloop/runs/%s/%s_%s_%s' % (R, new, mm, x, y)
            fs = glob.glob('%s/*_%d.png' % (d, lv))
            if not fs: continue
            t = Image.open(fs[0]).convert('RGB').resize((CW, CH)); im.paste(t, (j * CW, i * CH))
            dr = ImageDraw.Draw(im); dr.rectangle((j * CW, i * CH, j * CW + 170, i * CH + 12), fill=(0, 0, 0)); dr.text((j * CW + 2, i * CH + 1), '%s %s,%s L%d' % (kind.upper(), x, y, lv), fill=(255, 255, 0))
    im.save('%s/%s.png' % (out, m))
print(len(by))
