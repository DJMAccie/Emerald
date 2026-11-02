#!/usr/bin/env python3
"""Score an ortho45 screenshot against the original 2D map art, per map cell.

  python3 diff.py <MAP_ID> <x> <y> <shot.png> <outdir> [--scale 2] [--tol 12] [--shift auto]
                  [--rect x0,y0,x1,y1] [--mask none|building]

--rect (map cells, inclusive) adds: rect_differ / rect_of / rect_percent (pixels
inside the rectangle) and above_differ / above_of (the 3 cell rows directly above
it, same columns), to the JSON and the summary line; the cmp.png strip is then
cropped to the rectangle plus 3 cells of margin on every side, at full resolution.
--mask building (with --rect) counts only BUILDING pixels in rect_* (ref.building_mask:
water, ground and terrain inside the rectangle are left out); the unmasked numbers
go to rect_percent_all / rect_differ_all / rect_of_all, and mask_px / rect_px give
the mask size in map pixels. In the cmp.png the reference panel has the mask's
border in cyan; the dimmed panel has magenta only on differing BUILDING pixels.

A pixel differs when its max channel difference from the reference is > tol.
Pixels where the reference is transparent (outside the map, no art) are not
compared.  --shift auto tries dx,dy in -4..4 (shot pixel (sx,sy) is compared
with reference pixel (sx+dx, sy+dy)) and keeps the offset with the lowest
differing fraction of compared pixels (ties: smaller |dx|+|dy|).
Writes <outdir>/<MAP>_<x>_<y>_cmp.png and <MAP>_<x>_<y>_diff.json.
Shot is read with Pillow; the reference comes from ref.window (numpy).
"""
import os, sys, json, argparse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image
import ref

MAGENTA = np.array([255, 0, 255], np.uint8)
CYAN = np.array([0, 255, 255], np.uint8)
BG = 40

def score(win, shot, shot_ok, tol):
    r = win['rgba']
    valid = (r[..., 3] > 0) & shot_ok
    dif = np.abs(shot[..., :3].astype(np.int16) - r[..., :3].astype(np.int16)).max(axis=2) > tol
    return valid & dif, valid

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('map'); ap.add_argument('x', type=int); ap.add_argument('y', type=int)
    ap.add_argument('shot'); ap.add_argument('outdir')
    ap.add_argument('--scale', type=int, default=2); ap.add_argument('--tol', type=int, default=12)
    ap.add_argument('--shift', default='none', choices=['none', 'auto'])
    ap.add_argument('--rect')
    ap.add_argument('--mask', default='none', choices=['none', 'building'])
    ap.add_argument('--cache'); ap.add_argument('--slot'); ap.add_argument('--pair'); ap.add_argument('--world')
    a = ap.parse_args()
    im = Image.open(a.shot).convert('RGBA')
    w, h = im.size
    shot = np.asarray(im)
    shot_ok = shot[..., 3] > 0
    kw = dict(cache=a.cache, slot=a.slot, pair=a.pair, world=a.world)
    def win(dx, dy):
        return ref.window(a.map, a.x, a.y, a.scale, w, h, dx=dx, dy=dy, **kw)
    dx = dy = 0
    if a.shift == 'auto':
        best = None
        for ddx in range(-4, 5):
            for ddy in range(-4, 5):
                d, v = score(win(ddx, ddy), shot, shot_ok, a.tol)
                nd, nv = int(d.sum()), int(v.sum())
                if nv == 0:
                    continue
                key = (nd / nv, abs(ddx) + abs(ddy))
                if best is None or key < best[0]:
                    best = (key, ddx, ddy, nd, nv)
        _, dx, dy, _, _ = best
        print('shift auto: chose dx=%d dy=%d (shot(sx,sy) vs ref(sx+dx,sy+dy)), %.3f%% of %d px differ at that offset'
              % (dx, dy, best[0][0] * 100, best[4]))
    W = win(dx, dy)
    r = W['rgba']
    differ, valid = score(W, shot, shot_ok, a.tol)
    rect = above = bmask = bm_full = None
    if a.rect:
        rx0, ry0, rx1, ry1 = (int(t) for t in a.rect.split(','))
        assert rx1 >= rx0 and ry1 >= ry0, '--rect wants x0,y0,x1,y1 with x1>=x0, y1>=y0'
        inx = (W['cx'] >= rx0) & (W['cx'] <= rx1)
        rect = ((W['cy'] >= ry0) & (W['cy'] <= ry1))[:, None] & inx[None, :]
        above = ((W['cy'] >= ry0 - 3) & (W['cy'] <= ry0 - 1))[:, None] & inx[None, :]
        if a.mask == 'building':
            # the mask is from the reference, so it is sampled at the same (shifted) window pixels
            bm_full = ref.building_mask(a.map, (rx0, ry0, rx1, ry1), cache=a.cache, slot=a.slot, pair=a.pair, world=a.world)
            mx, my = ref.screen_map_px(a.x, a.y, a.scale, w, h, dx, dy)
            bmask = bm_full[np.clip(my, 0, bm_full.shape[0] - 1)[:, None], np.clip(mx, 0, bm_full.shape[1] - 1)[None, :]] & W['inside']
    elif a.mask == 'building':
        raise SystemExit('--mask building needs --rect')
    m = W['map']
    nd, nv = int(differ.sum()), int(valid.sum())
    # per-cell stats: cell index relative to the window's own cell range
    cxs, cys = W['cx'], W['cy']
    x0, y0 = int(cxs.min()), int(cys.min())
    nx = int(cxs.max()) - x0 + 1
    key = (cys - y0)[:, None] * nx + (cxs - x0)[None, :]
    nkey = nx * (int(cys.max()) - y0 + 1)
    of = np.bincount(key[valid], minlength=nkey)
    df = np.bincount(key[differ], minlength=nkey)
    cells = []
    for k in np.nonzero(of)[0]:
        cx, cy = x0 + int(k) % nx, y0 + int(k) // nx
        mid = int(m['mid'][cy, cx]) if 0 <= cy < m['H'] and 0 <= cx < m['W'] else -1
        coll = int(m['coll'][cy, cx]) if mid >= 0 else -1
        cells.append({'cx': cx, 'cy': cy, 'metatile': mid, 'collision': coll,
                      'differ': int(df[k]), 'of': int(of[k])})
    cells.sort(key=lambda c: (-c['differ'], -c['of'], c['cy'], c['cx']))
    bym = {}
    for c in cells:
        t = bym.setdefault(c['metatile'], [0, 0, 0])
        t[0] += 1; t[1] += c['differ']; t[2] += c['of']
    by_mt = [{'metatile': k, 'cells': v[0], 'differ': v[1], 'of': v[2],
              'percent': round(100.0 * v[1] / v[2], 2)} for k, v in bym.items()]
    by_mt.sort(key=lambda t: (-t['percent'], -t['differ']))
    pct = round(100.0 * nd / nv, 3) if nv else 0.0
    extra = {}
    if rect is not None:
        rd, rv = int((differ & rect).sum()), int((valid & rect).sum())
        ad, av = int((differ & above).sum()), int((valid & above).sum())
        extra = {'rect': [rx0, ry0, rx1, ry1],
                 'rect_differ': rd, 'rect_of': rv,
                 'rect_percent': round(100.0 * rd / rv, 3) if rv else 0.0,
                 'above_differ': ad, 'above_of': av}
        if bmask is not None:
            # masked: the rect_* numbers above move to *_all; rect_* now count BUILDING pixels only
            bd, bv = int((differ & rect & bmask).sum()), int((valid & rect & bmask).sum())
            cw = min(m['W'] - 1, rx1) - max(0, rx0) + 1
            ch = min(m['H'] - 1, ry1) - max(0, ry0) + 1
            extra.update({'rect_percent_all': extra['rect_percent'], 'rect_differ_all': rd, 'rect_of_all': rv,
                          'rect_differ': bd, 'rect_of': bv,
                          'rect_percent': round(100.0 * bd / bv, 3) if bv else 0.0,
                          'mask': 'building', 'mask_px': int(bm_full.sum()), 'rect_px': max(0, cw) * max(0, ch) * 256})
    os.makedirs(a.outdir, exist_ok=True)
    base = os.path.join(a.outdir, '%s_%d_%d' % (m['id'], a.x, a.y))
    out = {'map': m['id'], 'x': a.x, 'y': a.y, 'scale': a.scale, 'tol': a.tol,
           'shift': [dx, dy], 'pixels_compared': nv, 'pixels_differ': nd, 'percent': pct,
           'cells': cells, 'by_metatile': by_mt}
    out.update(extra)
    json.dump(out, open(base + '_diff.json', 'w'), indent=1)
    # cmp.png: reference | shot | reference dimmed to 35% with differing px in magenta
    a_ = r[..., 3:4].astype(np.float64) / 255.0
    refc = np.floor(r[..., :3] * a_ + BG * (1 - a_)).astype(np.uint8)
    dim = np.floor(refc * 0.35).astype(np.uint8)
    dmask = differ if bmask is None else differ & bmask
    dim[dmask] = MAGENTA
    if bmask is not None:
        # cyan: the mask's border, drawn on the reference panel (inside edge, 1 screen px)
        p = np.pad(bmask, 1)
        inner = p[1:-1, 1:-1] & p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:]
        refc[bmask & ~inner] = CYAN
    panels = [refc, shot[..., :3].copy(), dim]
    if rect is not None:
        # full resolution: the rectangle's bounding box plus 3 cells on every side
        rows = np.nonzero(rect.any(axis=1))[0]
        cols = np.nonzero(rect.any(axis=0))[0]
        if rows.size and cols.size:
            mg = 3 * 16 * a.scale
            t, b = max(0, int(rows.min()) - mg), min(h, int(rows.max()) + 1 + mg)
            l, rr = max(0, int(cols.min()) - mg), min(w, int(cols.max()) + 1 + mg)
            panels = [p[t:b, l:rr] for p in panels]
            h, w = b - t, rr - l
    elif 3 * w + 16 > 3000:
        hh, ww = h // 2 * 2, w // 2 * 2
        def half(p):
            p = p[:hh, :ww].astype(np.float64).reshape(hh // 2, 2, ww // 2, 2, 3)
            return np.floor(p.mean(axis=(1, 3))).astype(np.uint8)
        panels = [half(panels[0]), half(panels[1]), half(panels[2])]
        dmask = dmask[:hh, :ww].reshape(hh // 2, 2, ww // 2, 2).any(axis=(1, 3))
        panels[2][dmask] = MAGENTA
        h, w = hh // 2, ww // 2
    canvas = np.zeros((h, 3 * w + 16, 3), np.uint8)
    for i, p in enumerate(panels):
        canvas[:, i * (w + 8):i * (w + 8) + w] = p
    Image.fromarray(canvas).save(base + '_cmp.png')
    print('%s %d %d: %.3f%% differ (%d of %d px), worst cells: %s' % (
        m['id'], a.x, a.y, pct, nd, nv,
        ' '.join('(%d,%d,0x%03X %d/%d)' % (c['cx'], c['cy'], c['metatile'], c['differ'], c['of'])
                 for c in cells[:5])))
    if rect is not None:
        print('rect %s: rect_percent %.3f rect_differ %d rect_of %d above_differ %d above_of %d'
              % (extra['rect'], extra['rect_percent'], extra['rect_differ'], extra['rect_of'],
                 extra['above_differ'], extra['above_of']))
        if 'mask' in extra:
            print('mask building: %d of %d rect px are building (%.1f%%); rect_percent_all %.3f (rect_differ %d of %d)'
                  % (extra['mask_px'], extra['rect_px'], 100.0 * extra['mask_px'] / max(1, extra['rect_px']),
                     extra['rect_percent_all'], extra['rect_differ_all'], extra['rect_of_all']))
    print('worst metatiles:', ' '.join('0x%03X %.1f%% (%d/%d)' % (t['metatile'], t['percent'], t['differ'], t['of'])
                                        for t in by_mt[:8]))
    print('wrote', base + '_cmp.png', base + '_diff.json')

if __name__ == '__main__':
    main()
