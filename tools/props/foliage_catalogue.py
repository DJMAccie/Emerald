#!/usr/bin/env python3
"""Catalogue of every foliage tile in the game, grouped by identical pixel art.
  cd tools/buildings && python3 ../props/foliage_catalogue.py [OUT.json]
A tile is foliage when the mod classifies it tree/shrub/grass/flowers (props.tsv) OR its overlay layer holds
mostly green pixels (a canopy drawn over the player). Each group: art hash, tile image sheet, and every
(pair, mid, kind, count, example map/cell)."""
import os, sys, json, hashlib, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'buildings'))
import bldmodel  # noqa
import layers, numpy as np
from PIL import Image, ImageDraw
W = json.load(open(os.path.expanduser('~/Documents/gen1recomp-modwork/world.json')))
rows = [l.rstrip('\n').split('\t') for l in open(os.path.join(HERE, 'props.tsv'))]
KINDS = {'tree', 'shrub', 'grass', 'flowers'}
want = {}
for r in rows:
    if len(r) == 8 and r[2] in KINDS:
        want[(r[0], int(r[1], 16))] = (r[2], int(r[4]), r[5], int(r[6]), int(r[7]))
cache = {}
def tile(pair, mid):
    if pair not in cache:
        cache[pair] = layers.load(pair)
    L = cache[pair]
    u = layers.tile(L, 'u', mid)
    if u is None: return None, None
    o = layers.tile(L, 'o', mid) if 'o' in L else None
    return u, o
use = collections.defaultdict(lambda: [0, None])
for m in W['maps']:
    if not m['pair'].startswith('general__'): continue
    for i, v in enumerate(m['cells']):
        mid = v & 0x3FF
        k = (m['pair'], mid)
        use[k][0] += 1
        if use[k][1] is None: use[k][1] = (m['id'], i % m['w'], i // m['w'], (v >> 10) & 3)
groups = collections.OrderedDict()
for (pair, mid), (n, ex) in sorted(use.items()):
    kind = want.get((pair, mid), (None,))[0]
    try: u, o = tile(pair, mid)
    except Exception: continue
    if u is None: continue
    green_over = 0
    if o is not None:
        a = o[..., 3] > 128
        if a.sum() >= 40:
            r_, g_, b_ = [o[..., c].astype(int) for c in range(3)]
            green_over = ((g_ > r_ * 1.1) & (g_ > b_ * 1.05) & a).sum() / a.sum()
    if not kind and green_over < 0.6: continue
    h = hashlib.md5(u.tobytes() + (o.tobytes() if o is not None else b'')).hexdigest()[:10]
    g = groups.setdefault(h, dict(hash=h, kind=kind or 'canopy-overlay', over=round(float(green_over), 2), uses=[], total=0))
    g['uses'].append(dict(pair=pair[9:], mid='%03X' % mid, count=n, ex=ex))
    g['total'] += n
    g.setdefault('img', (u, o))
out = sys.argv[1] if len(sys.argv) > 1 else '/tmp/foliage.json'
lst = sorted(groups.values(), key=lambda g: -g['total'])
json.dump([{k: v for k, v in g.items() if k != 'img'} for g in lst], open(out, 'w'), indent=1)
print(len(lst), 'distinct foliage drawings,', sum(len(g['uses']) for g in lst), '(pair,tile) uses')
per = 40
for s in range(0, len(lst), per):
    chunk = lst[s:s + per]
    cols = 8
    sheet = Image.new('RGB', (cols * 100, ((len(chunk) + cols - 1) // cols) * 122), (36, 36, 40)); d = ImageDraw.Draw(sheet)
    for i, g in enumerate(chunk):
        u, o = g['img']
        t = u.astype(float)
        if o is not None:
            k = o[..., 3:4] / 255.; t[..., :3] = o[..., :3] * k + t[..., :3] * (1 - k)
        im = Image.fromarray(t[..., :3].astype(np.uint8)).resize((96, 96), Image.NEAREST)
        x, y = (i % cols) * 100, (i // cols) * 122
        sheet.paste(im, (x, y + 12)); d.text((x + 1, y), '%d %s' % (s + i, g['kind'][:6]), fill=(255, 255, 0))
        u0 = g['uses'][0]; d.text((x + 1, y + 110), '%s %s' % (u0['pair'][:9], u0['mid']), fill=(200, 200, 200))
    sheet.save(os.path.splitext(out)[0] + '_sheet%d.png' % (s // per))
