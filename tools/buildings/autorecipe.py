#!/usr/bin/env python3
"""Derive a voxel recipe for every building the engine recognises, from its
own drawing (Gen 3 oblique projection: screen row = height + depth).

 * facade: the rows below the engine's facade line (wallTop) stand as walls;
 * roof: the rows above it. The darkest full-width line in the roof is the
   RIDGE of a symmetric gable: the rows under it are the front slope, the
   rows above it the back slope seen foreshortened (hf.py 'gable');
   with no ridge line the roof is one slope and its mirror;
 * walls/back/sides sample a calm column of the facade; ground colours from
   the row in front of the building are cut away.

python3 autorecipe.py <groups.json> <inventory.json> <outdir> [--export DIR] [--only NAME]
"""
import sys, os, json, argparse
import numpy as np
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import hf, bldmodel as M


def lum(p): return 0.3 * p[..., 0] + 0.59 * p[..., 1] + 0.11 * p[..., 2]


def derive(g, it):
    pair, mp = g['pair'], g['map']
    x0, y0, x1, y1 = g['box']
    top = y0                                   # the engine's box already holds the roof rows
    img = M.compose(pair, mp, x0, top, x1, y1)
    H, W = img.shape[:2]
    # ground: a pixel is ground when it equals, AT THE SAME POSITION, one of
    # the walkable tiles around the building, and is reachable from outside
    # through such pixels (a wall painted the path's colour stays)
    import voxproto, layers
    L_ = layers.load(pair); MW, MH, mc = voxproto.map_cells(mp)
    cand = set()
    for xx in range(x0 - 1, x1 + 2):
        for yy in (y1 + 1, y1 + 2):
            if 0 <= xx < MW and 0 <= yy < MH: cand.add(mc[yy * MW + xx] & 0x3ff)
    for yy in range(top, y1 + 1):
        for xx in (x0 - 1, x1 + 1):
            if 0 <= xx < MW and 0 <= yy < MH: cand.add(mc[yy * MW + xx] & 0x3ff)
    inside = {mc[yy * MW + xx] & 0x3ff for yy in range(top, y1 + 1) for xx in range(x0, x1 + 1)}
    cand -= inside          # the building's own tiles are never its ground
    tiles = [voxproto.art(L_, t).astype(int) for t in cand if t in L_['u'][2]]
    # nor a walkable tile drawn exactly like one of them (a door the same art
    # as a doorway elsewhere)
    own = [voxproto.art(L_, t).astype(int) for t in inside if t in L_['u'][2]]
    tiles = [t for t in tiles if not any(np.array_equal(t, o) for o in own)]
    H, W = img.shape[:2]
    # flood each ground tile on its own: ground is a run of ONE tile's pixels
    # reaching the edge, so outline pixels several tiles share one each (a
    # door's dark frame) never add up to a hole
    from scipy import ndimage
    im3 = img[..., :3].astype(int)
    seen = np.zeros((H, W), bool)
    for t in tiles:
        tt = np.tile(t, (H // 16, W // 16, 1))
        lab, n = ndimage.label(np.abs(im3 - tt).sum(2) == 0)
        edge = set(lab[0]) | set(lab[-1]) | set(lab[:, 0]) | set(lab[:, -1])
        edge.discard(0)
        if edge: seen |= np.isin(lab, list(edge))
    mask = ~seen
    keys = []
    wall = (y1 - g['wallTop'] + 1) * 16
    roof_bottom = H - wall - 1                  # last roof row
    rows = [r for r in range(roof_bottom + 1) if mask[r].mean() > 0.35]
    roof_top = rows[0] if rows else roof_bottom
    nroof = roof_bottom - roof_top + 1
    # the ridge: the darkest wide row in the upper part of the roof band
    L = lum(img[..., :3].astype(float))
    # the ridge: the TOPMOST full-width outline row in the upper roof band
    ridge, best = None, 0
    for r in range(roof_top + 2, roof_top + int(nroof * 0.6)):
        m = mask[r]
        if m.mean() < 0.5: continue
        dark = ((L[r] < 110) & m).sum() / max(1, m.sum())
        if dark > 0.8:
            ridge, best = r, dark
            break
    if ridge is not None and best > 0.55 and nroof >= 8 and ridge - roof_top + 1 <= 6:
        ridge = None          # a parapet or rail along the top: a flat roof, not a gable
    if ridge is not None and best > 0.55 and nroof >= 8:
        nf, nb = roof_bottom - ridge, ridge - roof_top + 1
        segs = [('wall', wall), ('gable', nf, nb)]
        kind = 'gable %d/%d' % (nf, nb)
    elif nroof >= 4:
        # no ridge line: a flat roof seen from above
        segs = [('wall', wall), ('flat', nroof)]
        kind = 'flat roof %d' % nroof
    else:
        # all facade, no roof drawn: a flat top running back over the footprint
        segs = [('wall', wall)]
        kind = 'block'
    # a calm facade column for sides/back: lowest variance, not dark
    best_c, best_v = 2, 1e9
    for c in range(2, max(3, W - 6)):
        band = L[H - wall:H - 2, c:c + 4]
        v = band.var() + (200 if band.mean() < 90 else 0)
        if v < best_v: best_c, best_v = c, v
    side = (best_c, best_c + 4)
    depth = max(32, (y1 - top + 1) * 16)       # the building's footprint depth
    rec = dict(src=(pair, mp, x0, top, x1, y1), trim=True, bgmask=seen, keys=[],
               pieces=[dict(x=(0, W), B=H - 1, d0=0, segs=segs, side=side, fill=side, **({'depth': depth} if kind == 'block' else {}))],
               relief=[])
    return rec, img, kind


# 80-82: hand-built Littleroot. The rest read wrong automatically and need hand recipes:
# Mauville House1 merged, Sootopolis drums, Lavaridge red houses, Verdanturf tent,
# Pacifidlog huts, Cycling Road gates, Battle Frontier halls.
SKIP = {80, 81, 82, 21, 54, 69, 70, 71, 72, 73, 74, 75, 76, 77, 103, 110, 111, 112, 113, 114,
        119, 120, 121, 122, 123, 141, 142, 150, 151}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('groups'); ap.add_argument('inventory'); ap.add_argument('out')
    ap.add_argument('--export'); ap.add_argument('--only')
    ap.add_argument('--nums', type=lambda v: {int(x) for x in v.split(',')})
    a = ap.parse_args()
    G = json.load(open(a.groups)); I = json.load(open(a.inventory))
    os.makedirs(a.out, exist_ok=True)
    panes, done, report = [], set(), []
    for it in I:
        if a.only and a.only not in it['name']: continue
        if a.nums and it['n'] not in a.nums: continue
        if 'PokemonCenter' in it['name'] or it['name'].endswith('_Mart'): continue   # family models
        if it['n'] in SKIP: continue   # hand-built, or the automatic read is wrong (see BUILDINGS-REBUILD.md)
        dx = sum(d[0] for d in it['doors']) / len(it['doors']); dy = it['doors'][0][1]
        c = [g for g in G if g['map'] == it['map'] and g['box'][0] - .5 <= dx <= g['box'][2] + .5 and g['box'][1] <= dy <= g['box'][3] + 1]
        if not c: continue
        g = dict(min(c, key=lambda g: (g['box'][2] - g['box'][0]) * (g['box'][3] - g['box'][1])))
        # one building per door: cut the engine's group halfway between this
        # door and its neighbours' doors in the same group (Center/Mart
        # neighbours included: their own family models take their cells)
        others = sorted(sum(d[0] for d in o['doors']) / len(o['doors']) for o in I
                        if o is not it and o['map'] == it['map'] and g['box'][0] - .5 <= sum(d[0] for d in o['doors']) / len(o['doors']) <= g['box'][2] + .5
                        and g['box'][1] <= o['doors'][0][1] <= g['box'][3] + 1)
        bx0, by0, bx1, by1 = g['box']
        for ox in others:
            if ox < dx: bx0 = max(bx0, int((ox + dx) / 2) + 1)
            else: bx1 = min(bx1, int((ox + dx) / 2))
        g['box'] = [bx0, by0, bx1, by1]
        key = (g['map'], tuple(g['box']))
        if key in done: continue
        done.add(key)
        try:
            rec, img, kind = derive(g, it)
            v = hf.build(img, rec); q = hf.mesh(v)
            views = [hf.crop_to_content(hf.render(q, v, level=4, yaw=y)) for y in (0, 35, 215)]
        except Exception as e:
            report.append('%3d %-34s FAILED %s' % (it['n'], it['name'][:34], e)); continue
        name = 'b%03d_%s' % (it['n'], it['name'].split('_1F')[0].lower()[:40])
        if a.export:
            hf.export(name, rec, img, q, v, os.path.join(a.export, name + '.lua'))
        report.append('%3d %-34s %-12s box=%s' % (it['n'], it['name'][:34], kind, g['box']))
        art = Image.fromarray(img).convert('RGB')
        ims = [art] + [im.convert('RGB') for im in views]
        ims = [i.resize((i.width * 2, i.height * 2), Image.NEAREST) for i in ims]
        Hh = max(i.height for i in ims); Ww = sum(i.width for i in ims) + 10 * len(ims)
        pane = Image.new('RGB', (Ww, Hh + 14), (20, 20, 24)); xx = 0
        for im in ims: pane.paste(im, (xx, 14)); xx += im.width + 10
        ImageDraw.Draw(pane).text((2, 1), '%03d %s  [%s]' % (it['n'], it['name'][:40], kind), fill=(255, 230, 0))
        panes.append(pane)
    open(os.path.join(a.out, 'report.txt'), 'w').write('\n'.join(report) + '\n')
    per = 8
    for i in range(0, len(panes), per):
        ch = panes[i:i + per]; Wd = max(p.width for p in ch); Hd = sum(p.height for p in ch)
        s = Image.new('RGB', (Wd, Hd), (0, 0, 0)); y = 0
        for p in ch: s.paste(p, (0, y)); y += p.height
        s.save(os.path.join(a.out, 'auto_%02d.png' % (i // per + 1)))
    print('\n'.join(report)); print(len(panes), 'buildings rendered')


if __name__ == '__main__':
    main()
