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
        # deeper than drawn, like the flat roofs: over the blocked footprint
        nblk = 0
        for yy in range(y1, top - 1, -1):
            if sum(1 for xx in range(x0, x1 + 1) if (mc[yy * MW + xx] >> 10) & 3) * 2 > (x1 - x0 + 1): nblk += 1
            else: break
        sl_ = (nf - nb) / float(nf + nb)
        # one cell at most: the same house drawing must come out the same depth
        # wherever it stands (a tree or cliff behind one copy blocks one more row)
        gext = min(16, int(round((nblk * 16 - 2 * nf / (1.0 + sl_)) / 16.0)) * 16)
        if gext >= 16 and nf >= 14:
            P = 16 if nf >= 22 else 8
            segs = [('wall', wall), ('gable', nf, nb, gext, roof_bottom - 3, P)]
            kind += ' +%d deep' % gext
    elif nroof >= 4:
        # no ridge line: a flat roof seen from above
        segs = [('wall', wall), ('flat', nroof)]
        kind = 'flat roof %d' % nroof
    else:
        # all facade, no roof drawn: a flat top running back over the footprint
        segs = [('wall', wall)]
        kind = 'block'
    # the wall's own material for sides/back: the 4-px facade strip that is
    # most made of the wall's commonest colours (never a door or a window,
    # however calm), calmest on a tie
    from collections import Counter
    wb = img[H - wall:H - 2, :, :3].astype(int)
    okb = mask[H - wall:H - 2] & (L[H - wall:H - 2] >= 90)
    cnt = Counter(map(tuple, wb[okb]))
    tops = [c for c, _ in cnt.most_common(6)] or [(128, 128, 128)]
    # the wall is the biggest FAMILY of colours (planks are two or three tones
    # of one colour), not the commonest single colour, which can be a grey
    # frame or shadow
    dist = lambda p_, q_: sum(abs(a_ - b_) for a_, b_ in zip(p_, q_))
    fam = max(tops, key=lambda t: sum(n for c, n in cnt.items() if dist(c, t) <= 120))
    main = np.array([c for c in tops if dist(c, fam) <= 120] or [fam])
    near = (np.abs(wb[:, :, None, :] - main[None, None, :, :]).sum(3).min(2) <= 48) & okb
    # the widest strip that is plain wall all the way down (no outline, post,
    # door or window column in it): laid across a back wall, a strip holding a
    # dark column turns into a row of bars. Narrow down until one is clean; a
    # single clean column still gives plain courses.
    colshare = near.mean(0)
    best_c, best_w = 2, 1
    for w in (12, 8, 6, 4, 3, 2, 1):
        cands = [(colshare[c:c + w].min(), -L[H - wall:H - 2, c:c + w].var(), c) for c in range(2, max(3, W - 2 - w))]
        if not cands: continue
        q, _, c = max(cands)
        best_c, best_w = c, w
        if q >= 0.9: break
    side = (best_c, best_c + best_w)
    depth = max(32, (y1 - top + 1) * 16)       # the building's footprint depth
    if kind.startswith('flat roof'):
        # The engine's facade line can sit above the roof's real front edge
        # (the gyms: 16 rows of roof were stood up as wall, the roof draped
        # down the front). Find the edge in the drawing: carry the roof down
        # while a row is still mostly the roof's own colours.
        rb = img[roof_top + 2:roof_top + 10, :, :3].astype(int)
        rm = mask[roof_top + 2:roof_top + 10]
        rc = Counter(map(tuple, rb[rm]))
        rtops = [c for c, _ in rc.most_common(6)]
        if rtops:
            rfam = max(rtops, key=lambda t: sum(n for c, n in rc.items() if dist(c, t) <= 96))
            rmain = np.array([c for c in rtops if dist(c, rfam) <= 96] or [rfam])
            extra = 0
            for r in range(roof_bottom + 1, min(H - 8, roof_bottom + 25)):
                m = mask[r]
                if m.sum() < 8: break
                share = ((np.abs(img[r, :, None, :3].astype(int) - rmain[None, :, :]).sum(2).min(1) <= 32) & m).sum() / float(m.sum())
                if share < 0.6: break
                extra += 1
            # only where the facade's foot is stepped (a porch standing forward,
            # as on the gyms): a tent or a dome drawn in one colour is not a roof edge
            _f = np.array([(np.nonzero(mask[:, x])[0].max() if mask[:, x].any() else -1) for x in range(W)])
            _k = np.clip(H - 1 - _f[_f >= 0], 0, 16)
            _km = int(np.bincount(_k).argmax()) if len(_k) else 0
            if extra >= 4 and _km > 0 and (_k < _km).sum() >= 8:
                wall -= extra; nroof += extra; roof_bottom += extra
                segs = [('wall', wall), ('flat', nroof)]
                kind = 'flat roof %d' % nroof
    pieces = [dict(x=(0, W), B=H - 1, d0=0, segs=segs, side=side, fill=side, **({'depth': depth} if kind == 'block' else {}))]
    if kind.startswith('flat roof'):
        # The foot of the facade is not one line: most columns stand a few
        # rows above the drawing's last row (set back), a porch reaches it
        # (it stands forward). Every column is the same height; where the
        # foot is lower the roof starts lower too, and those rows are roof
        # seen from above, not wall. So: each run of columns starts as far
        # back as its foot is high, with one wall height for all.
        foot = np.array([(np.nonzero(mask[:, x])[0].max() if mask[:, x].any() else -1) for x in range(W)])
        k = np.where(foot >= 0, np.clip(H - 1 - foot, 0, 16), -1)
        ks = k[k >= 0]
        if len(ks):
            kmode = int(np.bincount(ks).argmax())
            k = np.where(k < 0, kmode, k)
            k = np.array([int(np.median(k[max(0, x - 2):x + 3])) for x in range(W)])   # ragged ground cut
            if 0 < kmode <= 16 and (k < kmode).sum() >= 8:
                hw = wall - kmode
                pieces, a0 = [], 0
                for x in range(1, W + 1):
                    if x == W or k[x] != k[a0]:
                        kk = int(k[a0])
                        pieces.append(dict(x=(a0, x), B=H - 1, d0=kk, segs=[('wall', hw), ('flat', nroof + kmode - kk)], side=side, fill=side))
                        a0 = x
                kind += ' porch'
    # The drawing is flatter than the building: its blocked footprint (rows of
    # cells nobody can enter, counted up from the door row) is deeper than the
    # roof is drawn. A flat roof is carried back over the whole footprint with
    # more of its own courses.
    ext = 0
    if kind.startswith('flat roof') and nroof >= 8:
        nblk = 0
        for yy in range(y1, top - 1, -1):
            if sum(1 for xx in range(x0, x1 + 1) if (mc[yy * MW + xx] >> 10) & 3) * 2 > (x1 - x0 + 1): nblk += 1
            else: break
        deep = max((pc_['d0'] if not callable(pc_['d0']) else 0) + sum(sg[1] for sg in pc_['segs'] if sg[0] == 'flat') for pc_ in pieces)
        # at most two cells more: a tall block's blocked rows are its height too
        ext = min(32, int(round((nblk * 16 - deep) / 16.0)) * 16)
        if ext >= 16:
            if nroof >= 28:
                # a coursed roof: one 16-row period of it, from its middle
                P = 16
                m = roof_top + 2 + P - 1 + (nroof - 4 - P) // 2
            else:
                # a small roof drawn as one piece (a lounge's lid): its most
                # uniform row carried back, no second copy of its bands
                P = 1
                def plain(r):
                    px = [tuple(v) for v in img[r, mask[r], :3]]
                    return Counter(px).most_common(1)[0][1] / float(len(px)) if px else 0
                m = max(range(roof_top + 2, roof_bottom - 1), key=plain)
            for pc_ in pieces:
                pc_['segs'] = [('flatx', sg[1], m, ext, P) if sg[0] == 'flat' else sg for sg in pc_['segs']]
            kind += ' +%d deep' % ext
        else:
            ext = 0
    prisms = []
    if kind.startswith('flat roof') and pair == 'general__rustboro':
        # Rustboro's roof vent (tile 0x223 over 0x22B): drawn as a box seen
        # from above with a 6-row front, so it stands as a box 6 px above the
        # roof. Its top is the 16 rows of the upper tile (20 px wide, starting
        # 8 px left of the tile), its front the 6 rows under it.
        for yy in range(top, y1 + 1):
            for xx in range(x0, x1 + 1):
                if (mc[yy * MW + xx] & 0x3ff) == 0x223:
                    tx, ty = (xx - x0) * 16, (yy - top) * 16
                    # behind the inserted courses the whole vent moves back with the roof
                    sh = ext if ext and ty + 21 <= m else 0
                    d0p = (H - 1 - (ty + 21)) - wall + sh
                    if d0p >= 0 and tx - 8 >= 0:
                        for pc_ in pieces: pc_['plainx'] = (tx - 12, W, 32)
                        prisms.append(dict(x=(tx - 8, min(W, tx + 12)), d=(d0p, d0p + 16), h=(wall, wall + 6), B=H - 1 + sh,
                                           mat=(tx, ty + 18), rows=(ty, ty + 22)))
                        kind += ' vent'
    relief = []
    if kind.startswith('flat roof') and pair == 'general__rustboro' and (mc[top * MW + x0] & 0x3ff) == 0x224:
        # Rustboro's grey houses: the roof is ringed by a crenellated parapet
        # (a light top line with dark notches every 8 px along the back and
        # the front edge, plain rails down the sides). It stands 3 px above
        # the roof; the notches stay 1 px up, so the merlons read as teeth.
        rt, rb_ = roof_top, roof_bottom
        def teeth(ra, rbx, probe):
            x = 0
            while x < W:
                tooth = L[probe, x] >= 150
                x2 = x
                while x2 < W and (L[probe, x2] >= 150) == tooth: x2 += 1
                relief.append(dict(x=(x, x2), rows=(ra, rbx), k=-3 if tooth else -1))
                x = x2
        teeth(rt, rt + 7, rt + 5)                 # back edge
        teeth(rb_ - 4, rb_ + 1, rb_ - 2)          # front edge
        relief.append(dict(x=(0, 5), rows=(rt + 7, rb_ - 4), k=-3))
        relief.append(dict(x=(W - 5, W), rows=(rt + 7, rb_ - 4), k=-3))
        kind += ' parapet'
    rec = dict(src=(pair, mp, x0, top, x1, y1), trim=True, bgmask=seen, keys=[], pieces=pieces, relief=relief, prisms=prisms)
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
