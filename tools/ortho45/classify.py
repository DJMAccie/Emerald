#!/usr/bin/env python3
"""Second pass over a sweep: is a building's picture WRONG, or the right
picture in the wrong place?

For every scored entry of docs/ortho45/buildings.json it slides the shot over
the reference inside the building's rectangle and
keeps the offset with the fewest differing pixels. Only BUILDING pixels count
(ref.building_mask, from the original art; the mask stays with the reference
while the shot slides):

  match      under 2% differ as shot
  near       under 6% left at the best offset (dx, dy) in screen px (2 per
             map px; dy < 0 = drawn higher/further north); a non-zero
             offset means the right drawing in the wrong place
  partly     6-20% left at the best offset
  wrong      over 20% left at any offset

  python3 classify.py <sweep-dir> [--json ../../docs/ortho45/buildings.json]
Writes class, local_shift and residual_percent back into the JSON and
docs/ortho45/CLASSES.md.
"""
import os, sys, json, glob, argparse
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ref

S, TOL = 2, 12

def main():
    ap = argparse.ArgumentParser(); ap.add_argument('sweep')
    ap.add_argument('--json', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../docs/ortho45/buildings.json'))
    a = ap.parse_args()
    d = json.load(open(a.json)); rows = []
    for e in d['entries']:
        if e.get('status') != 'scored': continue
        f = glob.glob(os.path.join(a.sweep, 'batch_*', e['shot']))
        if not f: e['class'] = 'no-shot'; continue
        shot = np.asarray(Image.open(f[0]).convert('RGB')).astype(np.int16)
        H, W = shot.shape[:2]; cx, cy = e['centre']; x0, y0, x1, y1 = e['rect']
        win = ref.window(e['map'], cx, cy, S, W, H, pair=e['pair'])
        rgba = np.asarray(win['rgba']); rf = rgba[..., :3].astype(np.int16); ok = rgba[..., 3] > 0
        bm = ref.building_mask(e['map'], (x0, y0, x1, y1), pair=e['pair'])
        mx, my = ref.screen_map_px(cx, cy, S, W, H)
        bsc = bm[np.clip(my, 0, bm.shape[0] - 1)[:, None], np.clip(mx, 0, bm.shape[1] - 1)[None, :]]
        px = lambda c, c0, half: half + (c * 16 - (c0 * 16 + 8)) * S
        ax0, ax1 = max(0, px(x0, cx, W // 2)), min(W, px(x1 + 1, cx, W // 2))
        ay0, ay1 = max(0, px(y0, cy, H // 2)), min(H, px(y1 + 1, cy, H // 2))
        R = rf[ay0:ay1, ax0:ax1]; M = ok[ay0:ay1, ax0:ax1] & bsc[ay0:ay1, ax0:ax1]
        best = None
        for dy in range(-32, 13):
            for dx in range(-12, 13):
                sy0, sy1, sx0, sx1 = ay0 + dy, ay1 + dy, ax0 + dx, ax1 + dx
                if sy0 < 0 or sx0 < 0 or sy1 > H or sx1 > W: continue
                diff = (np.abs(shot[sy0:sy1, sx0:sx1] - R).max(axis=2) > TOL) & M
                p = 100.0 * diff.sum() / max(1, M.sum())
                # prefer the smaller move on a near tie
                if best is None or p < best[0] - 0.25: best = (p, dx, dy)
        raw = 100.0 * ((np.abs(shot[ay0:ay1, ax0:ax1] - R).max(axis=2) > TOL) & M).sum() / max(1, M.sum())
        p, dx, dy = best
        cls = 'match' if e['rect_percent'] < 2 else 'near' if p < 6 else 'partly' if p < 20 else 'wrong'
        e['class'], e['local_shift'], e['residual_percent'], e['region_percent'] = cls, [dx, dy], round(p, 3), round(raw, 3)
        rows.append(e)
    json.dump(d, open(a.json, 'w'), indent=1)
    out = os.path.join(os.path.dirname(a.json), 'CLASSES.md')
    order = ['wrong', 'partly', 'near', 'match']
    with open(out, 'w') as fh:
        fh.write('# Buildings by kind of fault (ortho45, second pass)\n\n')
        fh.write('`tools/ortho45/classify.py`: the shot slid over the original inside the building rectangle. '
                 '`residual` = pixels still differing at the best offset; `shift` = that offset in screen px (2 per map px; dy < 0 = drawn higher or further north). '
                 'Only building pixels count (ground and water inside the rectangle are left out). '
                 'Flowers, trees and signs inside the rectangle count as differences.\n\n')
        for c in order:
            g = sorted([e for e in rows if e['class'] == c], key=lambda e: -e['residual_percent'])
            fh.write('## %s (%d)\n\n| name | map | rect | as shot %% | residual %% | shift dx,dy | sheet |\n|---|---|---|---|---|---|---|\n' % (c, len(g)))
            for e in g:
                fh.write('| %s | %s | %s | %.1f | %.1f | %d,%d | %s |\n' % (e['name'], e['map'], ','.join(map(str, e['rect'])), e['rect_percent'], e['residual_percent'], e['local_shift'][0], e['local_shift'][1], e['sheet']))
            fh.write('\n')
    import collections
    print(collections.Counter(e['class'] for e in rows))
    for n in ('birch_lab', 'littleroot_house', 'littleroot_house_may', 'trainer_hill_penthouse', 'b034_rustborocity_house3'):
        for e in rows:
            if e['name'] == n: print(n, e['class'], e['rect_percent'], e['residual_percent'], e['local_shift'])

if __name__ == '__main__': main()
