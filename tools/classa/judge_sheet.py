#!/usr/bin/env python3
# judge_sheet.py OUT OLD NEW [map-prefix...]   rows = class A spots: 2D crop | old L4 | new L4 | old L7 y0 | new L7 y0 | new L7 y90
import sys, os, re
from PIL import Image, ImageDraw
out, old, new = sys.argv[1:4]; want = sys.argv[4:]
R = os.path.expanduser('~/Documents/Emerald'); T = 360
spots = [d for d in sorted(os.listdir('%s/.autoloop/runs/%sy0' % (R, old))) if os.path.isdir('%s/.autoloop/runs/%sy0/%s' % (R, old, d))]
if want: spots = [s for s in spots if any(s.startswith(w) for w in want)]
def img(p):
    try: return Image.open(p).convert('RGB')
    except Exception: return Image.new('RGB', (T, T * 9 // 16), (60, 0, 0))
def fit(im, h=None):
    h = h or T * 9 // 16
    return im.resize((int(im.width * h / im.height), h))
rows = []
for s in spots:
    m = s.rsplit('_', 2)[0]
    cells = [fit(img('%s/docs/rock-gates/ALL-ROCKS/sheets/crop_%s.png' % (R, s))),
             fit(img('%s/.autoloop/runs/%sy0/%s/%s_4.png' % (R, old, s, m))),
             fit(img('%s/.autoloop/runs/%sy0/%s/%s_4.png' % (R, new, s, m))),
             fit(img('%s/.autoloop/runs/%sy0/%s/%s_7.png' % (R, old, s, m))),
             fit(img('%s/.autoloop/runs/%sy0/%s/%s_7.png' % (R, new, s, m))),
             fit(img('%s/.autoloop/runs/%sy90/%s/%s_7.png' % (R, new, s, m)))]
    rows.append((s, cells))
W = sum(c.width for c in rows[0][1]) + 6 * 4; H = len(rows) * (T * 9 // 16 + 14)
sheet = Image.new('RGB', (W + 10, H), (20, 20, 20)); d = ImageDraw.Draw(sheet); y = 0
for s, cells in rows:
    d.text((4, y + 1), s + '   2D | old L4 | new L4 | old L7 | new L7 | new L7 yaw90', fill=(255, 220, 0)); y += 12; x = 0
    for c in cells: sheet.paste(c, (x, y)); x += c.width + 4
    y += cells[0].height + 2
sheet.save(out); print(out, sheet.size)
