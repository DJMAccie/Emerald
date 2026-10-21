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




def segment_tiles(img, T=16, share_min=0.35):
    """Find the facade by the TILE grid (the game's own structure): every tile gets its dominant colour and that colour's
    share of the tile. The facade colour is the one covering the most tiles above `share_min`; the facade block is the
    bounding box of those tiles. This isolates a building from its scene far more reliably than pixel blobs, which pick
    plazas and sky (see docs/buildings/TILE-MEASURE.md)."""
    H, W = img.shape[:2]
    cols, rows = (W + T - 1) // T, (H + T - 1) // T
    grid = []
    for ty in range(rows):
        line = []
        for tx in range(cols):
            blk = img[ty * T:min(H, (ty + 1) * T), tx * T:min(W, (tx + 1) * T)].reshape(-1, 3)
            if not len(blk):
                line.append(None); continue
            c, n = collections.Counter(map(tuple, blk)).most_common(1)[0]
            line.append({'colour': [int(v) for v in c], 'share': round(n / float(len(blk)), 3)})
        grid.append(line)
    area = collections.Counter()
    for ty, line in enumerate(grid):
        for tx, t in enumerate(line):
            if t and t['share'] >= share_min:
                area[tuple(t['colour'])] += 1
    if not area:
        return None, grid
    colour, ntiles = area.most_common(1)[0]
    xs, ys = [], []
    for ty, line in enumerate(grid):
        for tx, t in enumerate(line):
            if t and t['colour'] == list(colour) and t['share'] >= share_min:
                xs.append(tx); ys.append(ty)
    if not xs:
        return None, grid
    return {'colour': list(colour), 'tiles': ntiles,
            'tile_rect': [min(xs), min(ys), max(xs), max(ys)],
            'px_rect': [min(xs) * T, min(ys) * T, min(W, (max(xs) + 1) * T) - 1, min(H, (max(ys) + 1) * T) - 1]}, grid



def detect_bands(img, min_h=6):
    """Split a drawing into horizontal BANDS: runs of rows whose dominant colour stays the same. A small house is a stack
    of bands (sky / roof / wall / paving) and a single "facade colour" test cannot express that. Returns
    [{rows:(y0,y1), colour, share}] with runs shorter than min_h merged into the neighbour above."""
    H, W = img.shape[:2]
    # the facade line is the middle third: a row's whole-width dominant colour is the BACKGROUND at the edges (sky, sea,
    # canopy), which is why the first version banded sky and canopy instead of roof/wall/paving
    c0, c1 = W // 3, W - W // 3
    dom = []
    for y in range(H):
        mid = img[y, c0:c1]
        c, n = collections.Counter(map(tuple, mid)).most_common(1)[0]
        dom.append((c, n / float(max(1, c1 - c0))))
    bands = []
    for y, (c, sh) in enumerate(dom):
        if bands and bands[-1]['colour'] == c:
            bands[-1]['rows'][1] = y
            bands[-1]['share'] = max(bands[-1]['share'], sh)
        else:
            bands.append({'rows': [y, y], 'colour': c, 'share': sh})
    merged = []
    for b in bands:
        if merged and (b['rows'][1] - b['rows'][0] + 1) < min_h:
            merged[-1]['rows'][1] = b['rows'][1]
        else:
            merged.append(b)
    for b in merged:
        b['colour'] = [int(v) for v in b['colour']]
        b['share'] = round(b['share'], 3)
        b['height'] = b['rows'][1] - b['rows'][0] + 1
    return merged


def segment_facade(img, top_colours=4, tol=6, min_frac=0.45):
    """Find the facade inside a scene: for each of the most common colours, the largest connected blob of that colour is a
    candidate wall; score it by area and by how much of its bounding box it fills (a wall is a rectangle, a sky or a sea is
    not). Returns {rect, colour, fill, area, period, windows, trim} or None."""
    from scipy import ndimage
    H, W = img.shape[:2]
    best = None
    cnt = collections.Counter(map(tuple, img.reshape(-1, 3)))
    for col, n in cnt.most_common(top_colours + 4):
        if n < 0.05 * W * H:
            continue
        m = np.abs(img - np.array(col)).max(axis=2) <= tol
        lab, k = ndimage.label(m)
        if not k:
            continue
        sizes = ndimage.sum(m, lab, range(1, k + 1))
        big = int(np.argmax(sizes)) + 1
        area = float(sizes[big - 1])
        ys, xs = np.where(lab == big)
        y0, y1, x0, x1 = int(ys.min()), int(ys.max()) + 1, int(xs.min()), int(xs.max()) + 1
        bw, bh = x1 - x0, y1 - y0
        if bw < 24 or bh < 20:
            continue
        fill = area / float(bw * bh)
        score = area * fill
        if best is None or score > best['score']:
            best = {'score': score, 'rect': [x0, y0, x1 - 1, y1 - 1], 'colour': [int(v) for v in col],
                    'fill': round(fill, 3), 'area': int(area), 'size': [bw, bh]}
    return best


def main(argv):
    pair, map_id = argv[0], argv[1]
    x0, y0, x1, y1 = (int(v) for v in argv[2:6])
    T = int(argv[argv.index('--tile') + 1]) if '--tile' in argv else 16
    # --facade y0,y1[,x0,x1]: name the facade band by hand (a small house is a stack of roof/wall/paving bands that the
    # automatic tests cannot separate), then everything below is measured inside that band
    fac = None
    if '--facade' in argv:
        parts = [int(v) for v in argv[argv.index('--facade') + 1].split(',')]
        fac = parts
    js = argv[argv.index('--json') + 1] if '--json' in argv else None
    img = M.compose(pair, map_id, x0, y0, x1, y1)[..., :3].astype(int)
    fac_off = [0, 0]
    if fac:
        fy0, fy1 = fac[0], fac[1]
        fx0, fx1 = (fac[2], fac[3]) if len(fac) > 3 else (0, img.shape[1] - 1)
        img = img[fy0:fy1 + 1, fx0:fx1 + 1]
        fac_off = [fx0, fy0]
    H, W = img.shape[:2]
    # wall = the most common colour of the whole drawing (a facade is mostly wall)
    cnt = collections.Counter(map(tuple, img.reshape(-1, 3)))
    wall, wall_n = cnt.most_common(1)[0]
    wall = np.array(wall)
    wall_share = wall_n / float(W * H)
    # AUTO-TRIM: in a scene the facade is the block of rows/columns that the wall colour dominates. Drop the rows and
    # columns whose wall-colour share is low, and measure again on that block (reported as the trimmed rect).
    def trim(img, wall, thr=0.35):
        """keep the contiguous block of rows and columns where the wall colour dominates, then slice once"""
        m = (np.abs(img - wall).max(axis=2) <= 8)
        rows = m.mean(axis=1) >= thr
        cols = m.mean(axis=0) >= thr
        if not rows.any() or not cols.any():
            return img, (0, 0)
        ys = np.where(rows)[0]; xs = np.where(cols)[0]
        y0, y1, x0, x1 = int(ys[0]), int(ys[-1]) + 1, int(xs[0]), int(xs[-1]) + 1
        if (y0, x0) == (0, 0) and (y1 - y0, x1 - x0) == img.shape[:2]:
            return img, (0, 0)
        return img[y0:y1, x0:x1], (x0, y0)
    trimmed = None
    if wall_share < 0.45:
        t_img, (tx, ty) = trim(img.copy(), wall)
        tc = collections.Counter(map(tuple, t_img.reshape(-1, 3)))
        t_share = float(tc.most_common(1)[0][1]) / float(t_img.shape[0] * t_img.shape[1])
        if t_share >= 0.45 and min(t_img.shape[:2]) >= 24:
            img = t_img
            H, W = img.shape[:2]
            cnt = collections.Counter(map(tuple, img.reshape(-1, 3)))
            wall2, wall_n = cnt.most_common(1)[0]
            wall = np.array(wall2)
            wall_share = float(wall_n) / float(W * H)
            trimmed = {'rect_px': [tx, ty, tx + W - 1, ty + H - 1], 'wall_share': round(wall_share, 3),
                       'size_px': [int(W), int(H)]}
    seg = None
    tseg = None
    seg_ok = bool(fac)   # a band named by hand is a facade by definition: measure it, do not judge it
    if wall_share < 0.45:
        tseg, _grid = segment_tiles(img)
        if tseg:
            x0t, y0t, x1t, y1t = tseg['px_rect']
            sub = img[y0t:y1t + 1, x0t:x1t + 1]
            wt = np.array(tseg['colour'])
            tshare = float((np.abs(sub - wt).max(axis=2) <= 6).mean())
            if tshare >= 0.30 and min(sub.shape[:2]) >= 32:
                img = sub
                wall = wt
                wall_share = tshare
                seg_ok = True        # a segmented facade may carry many windows, so a lower wall share is still a facade
        if not (tseg and wall_share >= 0.30):
            seg = segment_facade(img)
        if seg and seg['fill'] >= 0.45:
            x0s, y0s, x1s, y1s = seg['rect']
            sub = img[y0s:y1s + 1, x0s:x1s + 1]
            wall = np.array(seg['colour'])
            wall_share = float((np.abs(sub - wall).max(axis=2) <= 6).mean())
            if wall_share >= 0.45:
                img = sub
    if wall_share < 0.45 and not seg_ok:
        # Not a single facade: the rect holds a scene (building over sky/water/foliage) or several walls of different
        # colours. Facade numbers would be meaningless, so report the composition and stop (docs/buildings/TILE-MEASURE.md).
        comp = [{'colour': list(map(int, c)), 'share': round(n / float(W * H), 3)} for c, n in cnt.most_common(6)]
        print('drawing %dx%d px (%d x %d cells)  %s   pair %s' % (W, H, x1 - x0 + 1, y1 - y0 + 1, map_id, pair))
        print('MIXED DRAWING - no single facade here (largest colour is only %.1f%% of the pixels).' % (100 * wall_share))
        print('composition: %s' % ', '.join('%s %.0f%%' % (tuple(c['colour']), 100 * c['share']) for c in comp))
        print('bands (top to bottom): %s' % ', '.join('rows %d..%d %s (%.0f%%)' % (b['rows'][0], b['rows'][1], tuple(b['colour']), 100 * b['share']) for b in detect_bands(img)))
        if tseg:
            print('  tile facade (the game\'s own 16 px grid): colour %s over %d tiles, tile rect %s -> px %s'
                  % (tseg['colour'], tseg['tiles'], tseg['tile_rect'], tseg['px_rect']))
        if seg:
            print('  segmented facade candidate: %s px at %s, %.0f%% filled, colour %s%s'
                  % (seg['size'], seg['rect'], 100 * seg['fill'], seg['colour'],
                     ' (rejected: its box is not rectangular enough)' if seg['fill'] < 0.45 else ''))
        print('  -> this rect needs a region step (find the wall area first) before any facade measurement;')
        print('     the recipes that use it encode a hand crop or a scene-specific recipe instead.')
        if js:
            json.dump({'pair': pair, 'map': map_id, 'rect': [x0, y0, x1, y1], 'mixed': True,
                       'tile_facade': tseg, 'segmented_facade': seg,
                       'auto_trim_attempt': trimmed,
                       'composition': comp, 'wall_share': round(wall_share, 3)}, open(js, 'w'), indent=1)
            print('json -> %s' % js)
        return 0
    # the image may have been trimmed to its facade above: everything below works on the final pixels
    H, W = img.shape[:2]
    wall_share = float(sum(1 for c in img.reshape(-1, 3) if tuple(c) == tuple(int(v) for v in wall))) / float(W * H)
    mask = (np.abs(img - wall).max(axis=2) > 40)          # "not wall": windows, door, trim, sky
    bands = detect_bands(img)
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
            glass = [int(v) for v in collections.Counter(map(tuple, inside)).most_common(1)[0][0]]
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
        'facade_band': fac, 'facade_offset': fac_off,
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
    if tseg and wall_share >= 0.30:
        print('tile facade: colour %s over %d tiles, tile rect %s (measured inside it)'
              % (tseg['colour'], tseg['tiles'], tseg['tile_rect']))
    if seg and wall_share >= 0.45:
        print('segmented facade: %s px at %s, %.0f%% filled, colour %s (measured inside it)'
              % (seg['size'], seg['rect'], 100 * seg['fill'], seg['colour']))
    if trimmed: print('auto-trimmed to the facade: %s px at %s..%s (wall %.0f%%)' % (trimmed['size_px'], trimmed['rect_px'][:2], trimmed['rect_px'][2:], 100 * trimmed['wall_share']))
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
    if bands:
        print('bands (top to bottom): %s' % ', '.join('rows %d..%d %s (%.0f%%)' % (b['rows'][0], b['rows'][1], tuple(b['colour']), 100 * b['share']) for b in bands))
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
