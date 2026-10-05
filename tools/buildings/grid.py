#!/usr/bin/env python3
"""Map art with a cell grid: python3 grid.py out.png MAP PAIR x0 y0 x1 y1 [MAP PAIR x0 y0 x1 y1 ...]"""
import sys
import bldmodel as M
from PIL import Image, ImageDraw
args = sys.argv[2:]; panes = []
for i in range(0, len(args), 6):
    mp, pair, x0, y0, x1, y1 = args[i], args[i + 1], *map(int, args[i + 2:i + 6])
    im = Image.fromarray(M.compose(pair, mp, x0, y0, x1, y1)).convert('RGB')
    s = 32; im = im.resize((im.width * 2, im.height * 2), Image.NEAREST); d = ImageDraw.Draw(im)
    for c in range(x1 - x0 + 1): d.line([(c * s, 0), (c * s, im.height)], fill=(255, 0, 0)); d.text((c * s + 2, 2), str(x0 + c), fill=(255, 255, 0))
    for r in range(y1 - y0 + 1): d.line([(0, r * s), (im.width, r * s)], fill=(255, 0, 0)); d.text((2, r * s + 12), str(y0 + r), fill=(0, 255, 255))
    pane = Image.new('RGB', (im.width, im.height + 14)); pane.paste(im, (0, 14)); ImageDraw.Draw(pane).text((2, 1), mp, fill=(255, 255, 255))
    panes.append(pane)
W = max(p.width for p in panes); H = sum(p.height for p in panes)
cols = 2; rows = (len(panes) + 1) // 2
out = Image.new('RGB', (sum(p.width for p in panes[:2]) + 10, sum(max(p.height for p in panes[k:k + 2]) for k in range(0, len(panes), 2))))
y = 0
for k in range(0, len(panes), 2):
    x = 0
    for p in panes[k:k + 2]: out.paste(p, (x, y)); x += p.width + 10
    y += max(p.height for p in panes[k:k + 2])
out.save(sys.argv[1])
