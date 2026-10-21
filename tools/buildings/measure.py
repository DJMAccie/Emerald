#!/usr/bin/env python3
"""Measure a building's ORIGINAL drawing instead of guessing recipe constants.

  measure.py PAIR MAP x0 y0 x1 y1 [--json OUT] [--tile 16]

Composes the drawing exactly as the baker does (bldmodel.compose: under + over layers) and measures what a hand recipe
currently has to be told: the facade PERIOD, the window rects inside it, the wall/glass colours (as drawing pixel positions
the recipe can use), the door, and the facade's symmetry. Everything is measured in the drawing's own pixels; the period is
searched in whole tiles because a facade repeats on the tile grid.

Why: recipes like `_sky_pillar` encode these as hand constants (mat=(40,20), repeat=32, windows at x18..30/50..62, pilasters
0..8/72..80). A wrong constant is invisible until the render is compared with the art, and each new building repeats the
guesswork. This tool prints the measured skeleton instead.

Run WITHOUT -I (it needs numpy/Pillow).
"""
import os, sys, json, collections
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'voxel_proto'))
sys.path.insert(0, os.path.join(HERE, '..', 'analysis'))
import bldmodel as M


def runs(mask, minlen=1):
    out, s = [], None
    for i, v in enumerate(mask):
        if v and s is None:
            s = i
        elif not v and s is not None:
            if i - s >= minlen:
                out.append((s, i - 1))
            s = None
    if s is not None and len(mask) - s >= minlen:
        out.append((s, len(mask) - 1))
    return out


def main(argv):
    pair, map_id = argv[0], argv[1]
    x0, y0, x1, y1 = (int(v) for v in argv[2:6])
    T = int(argv[argv.index('--tile') + 1]) if '--tile' in argv else 16
    js = argv[argv.index('--json') + 1] if '--json' in argv else None
    img = M.compose(pair, map_id, x0, y0, x1, y1)[..., :3].astype(int)
    H, W = img.shape[:2]
    # wall = the most common colour of the whole drawing (a facade is mostly wall)
    cnt = collections.Counter(map(tuple, img.reshape(-1, 3)))
    wall, wall_n = cnt.most_common(1)[0]
    wall = np.array(wall)
    mask = (np.abs(img - wall).max(axis=2) > 40)          # "not wall": windows, door, trim, sky
    wall_share = wall_n / float(W * H)
    if wall_share < 0.45:
        # Not a single facade: the rect holds a scene (building over sky/water/foliage) or several walls of different
        # colours. Facade numbers would be meaningless, so report the composition and stop (docs/buildings/TILE-MEASURE.md).
        comp = [{'colour': list(map(int, c)), 'share': round(n / float(W * H), 3)} for c, n in cnt.most_common(6)]
        print('drawing %dx%d px (%d x %d cells)  %s   pair %s' % (W, H, x1 - x0 + 1, y1 - y0 + 1, map_id, pair))
        print('MIXED DRAWING - no single facade here (largest colour is only %.1f%% of the pixels).' % (100 * wall_share))
        print('composition: %s' % ', '.join('%s %.0f%%' % (tuple(c['colour']), 100 * c['share']) for c in comp))
        print('  -> this rect needs a region step (find the wall area first) before any facade measurement;')
        print('     the recipes that use it encode a hand crop or a scene-specific recipe instead.')
        if js:
            json.dump({'pair': pair, 'map': map_id, 'rect': [x0, y0, x1, y1], 'mixed': True,
                       'composition': comp, 'wall_share': round(wall_share, 3)}, open(js, 'w'), indent=1)
            print('json -> %s' % js)
        return 0
    # 1. PERIOD: correlate the per-row mask pattern at whole-tile lags
    best = []
    for lag in range(T, H // 2 + 1, T):
        a, b = mask[:-lag].astype(float), mask[lag:].astype(float)
        score = float((a * b).sum() / (np.sqrt((a * a).sum() * (b * b).sum()) + 1e-9))
        best.append((score, lag))
    best.sort(reverse=True)
    top = best[0][0] if best else 0.0
    period = next(l for sc, l in sorted(best, key=lambda t: t[1]) if sc >= 0.9 * top) if best else T
    # Rows that carry windows (inside one period) and the columns that carry them. A window is a small part of a period
    # (Sky Pillar: 6 px of 32), so the fractions are low: a column that is "not wall" for >8 % of the period is a window
    # column, and a row that is >12 % not-wall is a window row.
    per = mask[:period] if period <= H else mask
    colfrac = per.mean(axis=0)
    xruns = runs(colfrac > 0.08, 3)
    yruns = runs(per.mean(axis=1) > 0.12, 2)
    # the ground band: the bottom rows whose dominant colour is not the wall colour (the paving under the facade)
    strip = []
    for r in range(0, H, 8):
        block = img[r:r + 8].reshape(-1, 3)
        col = collections.Counter(map(tuple, block)).most_common(1)[0][0]
        strip.append((r, '+wall' if np.abs(np.array(col) - wall).max() <= 8 else tuple(int(v) for v in col)))
    ground_top = next((r for r, c in reversed(strip) if c != '+wall'), None) if any(c != '+wall' for _, c in strip) else None
    if ground_top is not None:
        # walk up while the strip stays non-wall
        gr = [r for r, c in strip if c != '+wall']
        ground_top = min(gr)
    # 2. glass colour = the dominant colour inside the biggest window run
    glass = None
    if xruns:
        xa = max(xruns, key=lambda r: r[1] - r[0])
        xs = slice(xa[0], xa[1] + 1)
        inside = img[0:period, xs].reshape(-1, 3)
        inside = inside[np.abs(inside - wall).max(axis=1) > 40]
        if len(inside):
            glass = list(collections.Counter(map(tuple, inside)).most_common(1)[0][0])
    def pos_of(colour):
        d = np.abs(img - np.array(colour)).max(axis=2)
        ys, xs = np.where(d <= 2)
        return [int(xs[0]), int(ys[0])] if len(xs) else None
    # 3. the door: a vertical structure rising out of the paving. The colours inside a door are usually the palette's own
    #    (Sky Pillar's arch is wall brown, navy and gold), so measure the SHAPE: in the strip just above the paving band the
    #    only thing that is not wall is the door.
    door = []
    if H >= 26:
        dstrip = mask[H - 22:H - 12].mean(axis=0)
        door = runs(dstrip > 0.5, 6)
    # 4. symmetry and the top/bottom of the drawn facade
    sym = float(np.abs(img - img[:, ::-1]).mean())
    rowfull = runs(mask.mean(axis=1) > 0.02, 1)
    # classify every "not wall" column run: one that carries the glass colour is a WINDOW, the others are TRIM (pilaster
    # edges, quoins, sill lines) - recipes want the windows in `recess` and the trim columns in `_proud`/corner art
    gl = np.array(glass) if glass else None
    windows, trim = [], []
    for a, b in xruns:
        col = img[:min(H, period * 3), a:b + 1]
        has_glass = bool(gl is not None and (np.abs(col - gl).max(axis=2) <= 24).mean() > 0.05)
        (windows if has_glass else trim).append([a, b])
    out = {
        'pair': pair, 'map': map_id, 'rect': [x0, y0, x1, y1], 'size_px': [W, H], 'tile': T,
        'windows': windows, 'trim': trim,
        'wall_colour': [int(v) for v in wall], 'wall_share': round(wall_n / (W * H), 3), 'wall_sample_xy': pos_of(wall),
        'period_px': int(period), 'period_candidates': [{'lag': int(l), 'score': round(s, 3)} for s, l in best[:4]],
        'window_x_runs': [list(r) for r in xruns], 'window_y_runs': [list(r) for r in yruns],
        'glass_colour': glass, 'glass_sample_xy': pos_of(glass) if glass else None,
        'door_x_runs': [list(r) for r in door], 'ground_top': ground_top, 'mirror_cost': round(sym, 1),
        'row_bands': [{'row': r, 'colour': c} for r, c in strip],
        'drawn_row_range': [list(r) for r in rowfull][:4],
    }
    print('drawing %dx%d px (%d x %d cells)  %s   pair %s' % (W, H, x1 - x0 + 1, y1 - y0 + 1, map_id, pair))
    print('wall colour   %s  at pixel %s   (%.1f%% of the drawing)' % (tuple(int(v) for v in wall), out['wall_sample_xy'], 100 * out['wall_share']))
    print('period        %d px   candidates %s' % (period, ', '.join('%dpx %.2f' % (c['lag'], c['score']) for c in out['period_candidates'])))
    print('window cols   %s   <- recess' % (windows,))
    print('trim cols     %s   <- pilaster/quoins (_proud, corner)' % (trim,))
    print('window rows   %s   (inside one period)' % (out['window_y_runs'],))
    print('glass colour  %s  at pixel %s' % (out['glass_colour'], out['glass_sample_xy']))
    print('ground from   row %s to %d%s' % (ground_top, H, '' if ground_top is None else '  (the paving band)'))
    print('door cols     %s' % (out['door_x_runs'],))
    print('mirror cost   %.1f' % sym)
    print()
    print('MEASURED RECIPE:')
    print("  src=(%r, %r, %d, %d, %d, %d)" % (pair, map_id, x0, y0, x1, y1))
    print("  plan volume: mat=%s   repeat=%d" % (tuple(out['wall_sample_xy']), period))
    if windows and yruns:
        print('  recess rows %d..%d, windows %s' % (yruns[0][0], yruns[0][1], windows))
        print('  -> recess=[%s]' % ', '.join('(%d, %d, %d, %d, 2)' % (a, b, yruns[0][0], yruns[0][1]) for a, b in windows))
    if door:
        print('  door columns %s -> porch/carve rows %s..%d' % ([list(r) for r in door], ground_top, H))
    if js:
        json.dump(out, open(js, 'w'), indent=1)
        print('json -> %s' % js)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
