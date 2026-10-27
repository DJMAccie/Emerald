#!/usr/bin/env python3
# cards.py  card sheet of what the review pass left: per card = 2D crop | NOW L4 | NOW L7, with a title and one line
import os
from PIL import Image, ImageDraw
R = os.path.expanduser('~/Documents/Emerald/docs/rock-gates/')
O = R + 'review1/sheets/AB_%s.png'
def outdoor(n):
    a = Image.open(O % n); return a.crop((0, 0, 640, 360)), a.crop((1280, 0, 1920, 360)), a.crop((1280, 720, 1920, 1080))
def cave(sheet, row):
    a = Image.open(R + 'review_caves1/' + sheet); h = a.height // 2
    c = a.crop((0, row * h, 360, row * h + h)); f = lambda x: a.crop((x, row * h, x + 560, row * h + h)).resize((640, 360))
    return c.resize((int(c.width * 360 / c.height), 360)), f(360), f(360 + 560 * 2)
CARDS = [
 ('1 Route 124 sea islands (50,16) (72,44)', 'Class B: low flat striped plates; the 2D has tall rounded domes. A steeper rise (probe) overshoots into spikes elsewhere.', lambda: outdoor('EM_ROUTE124_50_16')),
 ('2 Route 126 pink sea mass (12,14)', 'Class A: ring of low terraced plates; the 2D is one tall hatched mass with a rounded back.', lambda: outdoor('EM_ROUTE126_12_14')),
 ('3 Long sea ridges: Routes 127/128/134 (53,54) (55,3) (62,16)', 'Class B: thin low flat bands; the 2D ridges are 3-4 cells wide, tall, hatched. Needs a ridge-profile rule in Gen3Hills.', lambda: outdoor('EM_ROUTE127_53_54')),
 ('4 Routes 129/130 sea masses (57,11) (68,13)', 'Class A: low planks with water slots; the 2D is one solid tall rounded body.', lambda: outdoor('EM_ROUTE129_57_11')),
 ('5 Route 105 sea ridge (33,24)', 'Old builder: boxy pillars with gaps; class A tried before = thin ribbons. 2D is one rounded 3-cell ridge.', lambda: outdoor('EM_ROUTE105_33_24')),
 ('6 Battle Frontier East (63,53)', 'Two tall spires on a thin ridge strip; tried two ways before, both worse.', lambda: outdoor('EM_BATTLE_FRONTIER_OUTSIDE_EAST_63_53')),
 ('7 Lilycove NE rock (66,3)', 'Stepped blocks where the 2D is one rounded mass; class A on Lilycove came out flat.', lambda: outdoor('EM_LILYCOVE_CITY_66_3')),
 ('8 Navel Rock summit (12,13)', 'Tall stepped pyramid with a hollow ridge lattice; the 2D is a small rounded peak in the sky.', lambda: cave('sheets_b/S_020.png', 1)),
 ('9 Magma Hideout streaked faces (2F, 12,33)', 'Terraces right, but tall vertical streaks on the faces (Gen3Rock face builder); the 2D is thin dark ridges. Needs your eye.', lambda: cave('sheets_a/S_017.png', 1)),
]
W, H = 640 * 3 // 2, 360 // 2 + 56
sheet = Image.new('RGB', (W * 2 + 20, (H + 10) * 5), (20, 20, 20))
for i, (t, d, f) in enumerate(CARDS):
    a, b, c = f(); card = Image.new('RGB', (W, H), (0, 0, 0))
    for j, im in enumerate((a, b, c)):
        im = im.copy(); im.thumbnail((W // 3, 180)); card.paste(im, (j * (W // 3), 56))
    dr = ImageDraw.Draw(card); dr.text((4, 4), t, fill=(255, 255, 0)); dr.text((4, 22), d[:150], fill=(255, 255, 255)); dr.text((4, 36), d[150:300], fill=(255, 255, 255))
    sheet.paste(card, ((i % 2) * (W + 20), (i // 2) * (H + 10)))
sheet.save(R + 'review1/CARDS_left.png'); print(sheet.size)
