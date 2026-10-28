#!/usr/bin/env python3
# question_crops.py OUT.png MAP:x0,y0,x1,y1:colour:label [...]
# One annotated crop per spot from the user's drawn sheet (docs/elevation/draw/<MAP>.png, 48 px per cell, 40 px header):
# the spot's cells boxed in a DISTINCT colour (the user answers by colour), the pins near it drawn in blue with their
# number, a caption line under each crop. All crops side by side in one sheet, downscaled to 1500 px wide at most.
import sys, os
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
S, H0, PAD = 48, 40, 6   # px per cell, header strip, cells of context around the spot
COL = {'magenta': (255, 0, 200), 'yellow': (255, 210, 0), 'cyan': (0, 200, 230), 'orange': (255, 120, 0),
       'green': (0, 190, 60), 'red': (230, 30, 30), 'white': (255, 255, 255)}
font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 30)
small = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 24)
out = sys.argv[1]; crops = []
for spec in sys.argv[2:]:
    m, box, colour, label = spec.split(':', 3)
    x0, y0, x1, y1 = map(int, box.split(','))
    im = Image.open(os.path.join(ROOT, 'docs', 'elevation', 'draw', m + '.png')).convert('RGB')
    h0 = H0 if im.height % S != 0 else 0
    d = ImageDraw.Draw(im)
    pins = []
    for line in open(os.path.join(ROOT, 'docs', 'elevation', 'pins', m + '.txt')):
        t = line.split('#')[0].split()
        if len(t) >= 3: pins.append((int(t[0]), int(t[1]), t[2]))
    for x, y, h in pins:
        if x0 - PAD <= x <= x1 + PAD and y0 - PAD <= y <= y1 + PAD:
            cx, cy = x * S, h0 + y * S
            d.rectangle([cx + 2, cy + 2, cx + S - 2, cy + S - 2], outline=(0, 90, 255), width=3)
            d.text((cx + 4, cy + 2), h, fill=(0, 90, 255), font=small)
    c = COL[colour]
    d.rectangle([x0 * S, h0 + y0 * S, (x1 + 1) * S, h0 + (y1 + 1) * S], outline=c, width=6)
    cb = (max(0, (x0 - PAD) * S), max(0, h0 + (y0 - PAD) * S), min(im.width, (x1 + 1 + PAD) * S), min(im.height, h0 + (y1 + 1 + PAD) * S))
    crop = im.crop(cb)
    # ruler: cell numbers along the top and left edges of the crop
    r = ImageDraw.Draw(crop)
    for x in range(max(0, x0 - PAD), x1 + 1 + PAD):
        r.text(((x - max(0, x0 - PAD)) * S + 4, 2), str(x), fill=(0, 0, 0), font=small)
    for y in range(max(0, y0 - PAD), y1 + 1 + PAD):
        yy = (y * S + h0) - cb[1]
        if 0 <= yy < crop.height: r.text((2, yy + 14), str(y), fill=(0, 0, 0), font=small)
    crops.append((crop, c, '%s %s' % (colour.upper(), label)))
cw = max(c.width for c, _, _ in crops); ch = max(c.height for c, _, _ in crops)
sheet = Image.new('RGB', (sum(c.width for c, _, _ in crops) + 10 * (len(crops) - 1), ch + 90), (255, 255, 255))
dr = ImageDraw.Draw(sheet); x = 0
for crop, c, label in crops:
    sheet.paste(crop, (x, 0)); dr.rectangle([x, ch + 10, x + 40, ch + 50], fill=c)
    # wrap the label at ~ crop width
    words = label.split(); lines = []; cur = ''
    for w in words:
        if dr.textlength(cur + ' ' + w, font=small) > crop.width - 60: lines.append(cur); cur = w
        else: cur = (cur + ' ' + w).strip()
    lines.append(cur)
    for i, ln in enumerate(lines[:3]): dr.text((x + 50, ch + 8 + 26 * i), ln, fill=(0, 0, 0), font=small)
    x += crop.width + 10
if sheet.width > 1500: sheet = sheet.resize((1500, int(sheet.height * 1500 / sheet.width)), Image.LANCZOS)
sheet.save(out); print(out, sheet.size)
