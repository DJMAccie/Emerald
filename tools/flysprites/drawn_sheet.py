#!/usr/bin/env python3
"""Compact approval sheet of the 13 drawn flyers: per species the back (up), front (down) and side (left) rows,
4 wing-beat frames each, from the BAKED sheets in the mod's assets/flyers (what the game will draw).
python3 drawn_sheet.py -> docs/faults/fly/flyers/SHEET_drawn13.png"""
import json, os
from PIL import Image, ImageDraw
HOME = os.path.expanduser('~')
OUT = HOME + '/Documents/battle-art-notquiteog/assets/flyers/'
DEST = HOME + '/Documents/Emerald/docs/faults/fly/flyers/SHEET_drawn13.png'
HERE = os.path.dirname(os.path.abspath(__file__))
NAMES = {16: 'Pidgey', 21: 'Spearow', 83: "Farfetch'd", 84: 'Doduo', 85: 'Dodrio', 149: 'Dragonite', 163: 'Hoothoot',
         176: 'Togetic', 178: 'Xatu', 225: 'Delibird', 276: 'Taillow', 357: 'Tropius', 373: 'Salamence'}
S = 3
import re
man = {}
for line in open(OUT + 'manifest.lua'):
    m = re.match(r'\s*\[(\d+)\]=\{fw=(\d+),fh=(\d+),frames=(\d+)', line)
    if m:
        man[int(m.group(1))] = tuple(int(x) for x in m.groups()[1:])
table = json.load(open(HERE + '/flyers.json'))
drawn = sorted(int(k) for k, v in table.items() if not k.startswith('_') and v == 'drawn')
ROWS = ((3, 'back'), (0, 'front'), (1, 'side'))
cw = max(man[n][0] for n in drawn) * S
ch = max(man[n][1] for n in drawn) * S
cell_w = 4 * (cw + 4) + 20
cell_h = 3 * (ch + 4) + 26
cols = 2
rows = (len(drawn) + cols - 1) // cols
sheet = Image.new('RGBA', (cols * cell_w, rows * cell_h), (110, 160, 210, 255))
d = ImageDraw.Draw(sheet)
for i, nat in enumerate(drawn):
    fw, fh, nf = man[nat]
    im = Image.open(OUT + '%03d-normal.png' % nat).convert('RGBA')
    ox, oy = (i % cols) * cell_w, (i // cols) * cell_h
    d.text((ox + 6, oy + 4), '%d %s' % (nat, NAMES.get(nat, '')), fill=(0, 0, 0, 255))
    for ri, (row, label) in enumerate(ROWS):
        for c in range(nf):
            f = im.crop((c * fw, row * fh, (c + 1) * fw, (row + 1) * fh)).resize((fw * S, fh * S), Image.NEAREST)
            sheet.paste(f, (ox + 6 + c * (cw + 4) + (cw - fw * S) // 2, oy + 20 + ri * (ch + 4) + (ch - fh * S)), f)
sheet.save(DEST)
print(DEST, sheet.size)

# ---- one animated GIF: every drawn flyer, back and front, beating its wings (what the chase camera sees, and the front)
G = 3
gcols = 3
gw = 2 * cw + 12
gh = ch + 18
grows = (len(drawn) + gcols - 1) // gcols
frames = []
for beat in range(4):
    img = Image.new('RGBA', (gcols * gw, grows * gh), (110, 160, 210, 255))
    dd = ImageDraw.Draw(img)
    for i, nat in enumerate(drawn):
        fw, fh, nf = man[nat]
        im = Image.open(OUT + '%03d-normal.png' % nat).convert('RGBA')
        ox, oy = (i % gcols) * gw, (i // gcols) * gh
        dd.text((ox + 4, oy + 2), '%d %s' % (nat, NAMES.get(nat, '')), fill=(0, 0, 0, 255))
        for k, row in enumerate((3, 0)):
            f = im.crop((beat * fw, row * fh, (beat + 1) * fw, (row + 1) * fh)).resize((fw * S, fh * S), Image.NEAREST)
            img.paste(f, (ox + 4 + k * (cw + 4) + (cw - fw * S) // 2, oy + 16 + (ch - fh * S) // 2), f)
    frames.append(img.convert('P', palette=Image.ADAPTIVE))
gif = DEST.replace('.png', '.gif')
frames[0].save(gif, save_all=True, append_images=frames[1:], duration=130, loop=0)
print(gif, frames[0].size)
