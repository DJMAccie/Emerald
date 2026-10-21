#!/usr/bin/env python3
"""tile_sheet.py <MAP> <out.png> <hexmid> ...   per metatile: under | middle | over layer (alpha on grey) | composite, x4, labelled."""
import sys
sys.path.insert(0, '/Users/user/Documents/Emerald/tools/relief')
import emdata, numpy as np
from PIL import Image, ImageDraw
L = emdata.Layout(sys.argv[1]); art = L.art
mids = [int(a, 16) for a in sys.argv[3:]]
Z = 4; cw = 16 * Z + 4
sheet = Image.new('RGB', (4 * cw + 60, len(mids) * (16 * Z + 6)), (60, 60, 60))
d = ImageDraw.Draw(sheet)
for r, m in enumerate(mids):
    y = r * (16 * Z + 6)
    d.text((2, y + 28), '%03X' % m, fill=(255, 255, 0))
    for c, t in enumerate('umo'):
        x = art.layer(t, m)
        img = Image.new('RGB', (16, 16), (110, 110, 110))
        if x is not None:
            img.paste(Image.fromarray(x.astype('uint8'), 'RGBA'), (0, 0), Image.fromarray(x.astype('uint8'), 'RGBA'))
        sheet.paste(img.resize((16 * Z, 16 * Z), Image.NEAREST), (40 + c * cw, y))
    sheet.paste(Image.fromarray(art.image(m)).resize((16 * Z, 16 * Z), Image.NEAREST), (40 + 3 * cw, y))
sheet.save(sys.argv[2])
