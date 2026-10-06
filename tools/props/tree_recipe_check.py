#!/usr/bin/env python3
"""Check every tree card the game built against the ORIGINAL map grid.
  1) run the card dump:  EM_DRIVER=tools/props/card_probe.lua EM_CASES=<maps>  tools/props/audit_capture.sh OUT   (writes OUT/cards.txt)
  2) cd tools/buildings && python3 ../props/tree_recipe_check.py OUT
For each card (label  pair:MID ground=GGG art=RxC): find a cell of that pair+MID on the original grid, compose the tree the
way the cartridge draws it (tile rows x cols above the root cell, floor + over layer), and compare with the card:
  LOST   = original pixel that is NOT ground colour but the card dropped it  (holes in the crown)
  LEFT   = card pixel that equals the ground colour at that spot             (ground painted on the tree)
Writes OUT/recipes.png : per card  [original grid | card | LOST red / LEFT blue]  and prints the table."""
import os, sys, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'buildings'))
import bldmodel as M, layers, numpy as np
from PIL import Image, ImageDraw
W = json.load(open(os.path.expanduser('~/Documents/gen1recomp-modwork/world.json')))
out = sys.argv[1]
lines = open(os.path.join(out, 'cards.txt')).read().split('\n')
cards = []; i = 0
while i < len(lines):
    if lines[i].startswith('CARD'):
        label = lines[i][5:]; w, h = map(int, lines[i + 1].split())
        a = np.zeros((h, w, 4), np.uint8)
        for y in range(h):
            for x, px in enumerate(lines[i + 2 + y].split(' ')):
                a[y, x] = [int(px[k:k + 2], 16) for k in (0, 2, 4, 6)]
        cards.append((label, a)); i += 2 + h
    else: i += 1
cache = {}
def tile(pair, mid, over=True):
    if pair not in cache: cache[pair] = layers.load(pair)
    L = cache[pair]
    u = layers.tile(L, 'u', mid)
    if u is None: return None
    t = u.astype(float)
    if over and 'o' in L:
        o = layers.tile(L, 'o', mid)
        if o is not None:
            k = o[..., 3:4] / 255.; t[..., :3] = o[..., :3] * k + t[..., :3] * (1 - k); t[..., 3:4] = np.maximum(t[..., 3:4], o[..., 3:4])
    return t.astype(np.uint8)
rows = []
def holes(opaque):
    """transparent pixels not connected (4-neighbour) to the card border: holes inside the tree"""
    h, w = opaque.shape; seen = np.zeros_like(opaque); st = []
    for x in range(w):
        for y in (0, h - 1):
            if not opaque[y, x] and not seen[y, x]: seen[y, x] = True; st.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not opaque[y, x] and not seen[y, x]: seen[y, x] = True; st.append((x, y))
    while st:
        x, y = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not opaque[ny, nx] and not seen[ny, nx]: seen[ny, nx] = True; st.append((nx, ny))
    return (~opaque) & (~seen)
for label, card in cards:
    first = label.split(' | ')[0]
    if first.startswith('obj:'):
        opaque = card[..., 3] > 128
        rows.append((first[:40], 'object card: %d holes' % holes(opaque).sum(), (None, card, None, holes(opaque), None, 0, 0))); continue
    try:
        pair, mid = first.split(' ', 1)[0].split(':'); mid = int(mid, 16)
        ground = int(first.split('ground=')[1].split()[0], 16)
        rowmids = [[int(x, 16) for x in r.split(',')] for r in first.split('rows=')[1].split()[0].split('/')]
        tip = int(first.split('tip=')[1].split()[0])
    except Exception: continue
    h, w = card.shape[:2]
    g = pair
    # the original drawing, exactly as the cartridge stacks it: tile rows, floor + over layer
    og = np.zeros((h, w, 4), np.uint8)
    for ry, r in enumerate(rowmids):
        for rx, m in enumerate(r):
            t = tile(g, m)
            if t is not None: og[ry * 16:(ry + 1) * 16, rx * 16:(rx + 1) * 16] = t
    gt = tile(g, ground, over=False)
    gcol = set(map(tuple, gt[..., :3].reshape(-1, 3).astype(int))) if gt is not None else set()
    isg = np.array([[tuple(og[y, x, :3].astype(int)) in gcol for x in range(w)] for y in range(h)])
    opaque = card[..., 3] > 128
    hl = holes(opaque)
    # a pixel that is clearly crown in the original (not ground colour, and surrounded by crown) yet missing in the card
    crown_og = (~isg) & (og[..., 3] > 128)
    lost = (~opaque) & crown_og & hl
    rows.append((first[:44], 'holes %3d  lost-inside %3d  card px %4d' % (hl.sum(), lost.sum(), opaque.sum()), (og, card, lost, hl, g, 0, 0)))
for r in rows: print('%-44s %s' % (r[0], r[1]))
panels = [r for r in rows if r[2]]
S = 4
sheet = Image.new('RGB', (len(panels) * (3 * 16 * 2 * S // 2 + 40) + 10, 3 * 16 * S + 40), (40, 40, 44)); d = ImageDraw.Draw(sheet); x0 = 6
for name, txt, (og, card, lost, left, mp, cx, cy) in panels:
    h, w = card.shape[:2]
    a = Image.fromarray(og[..., :3]).resize((w * S, h * S), Image.NEAREST) if og is not None else Image.new('RGB', (w * S, h * S), (60, 60, 60))
    b = Image.new('RGB', (w, h), (255, 0, 255)); b.paste(Image.fromarray(card[..., :3]), (0, 0), Image.fromarray(card[..., 3])); b = b.resize((w * S, h * S), Image.NEAREST)
    c = np.zeros((h, w, 3), np.uint8); c[left] = (255, 40, 40); c[(~left)] = (30, 30, 34); c[card[..., 3] > 128] = (60, 90, 60); c = Image.fromarray(c).resize((w * S, h * S), Image.NEAREST)
    for k, im in enumerate((a, b, c)): sheet.paste(im, (x0 + k * (w * S + 4), 30))
    d.text((x0, 4), name[:30], fill=(255, 255, 0)); d.text((x0, 16), txt[:34], fill=(255, 255, 255))
    x0 += 3 * (w * S + 4) + 14
sheet.save(os.path.join(out, 'recipes.png'))
