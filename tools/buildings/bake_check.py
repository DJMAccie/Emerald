#!/usr/bin/env python3
"""Offline bake checker: projects each baked building model into the 45-degree
oblique view and diffs it against the building's own drawing.

No game, no Lua: the quads of data/buildings/*.lua are parsed with a regex and the
drawing comes from bldmodel.compose() (the same pixels hf.py load_art uses).

Projection, in art pixels: a point at height h and depth d (d = -z) lands on art
row r = (H-1) - (h+d), column x.
  face 1 (south) at depth d = -zmin over heights [hmin,hmax)   -> rows k = h+d
  face 3 (top)   at height hmin over depths [-zmax,-zmin)     -> one row per depth
  faces 2, 4, 5 are edge-on or hidden in this view and are ignored.
Visibility per picture pixel: smallest key wins, key = 2d for a south cell at depth
d, 2d+1 for a top cell covering depth d..d+1.

Usage: python3 bake_check.py [name-substring ...] [--out DIR] [--sheet] [--mask ref|alpha]
"""
import argparse, glob, json, os, re, sys, time

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
DATA = os.path.expanduser('~/Documents/battle-art-notquiteog/data/buildings')
REF_DIR = os.path.join(HERE, '..', 'ortho45')
OUT = '/private/tmp/claude-501/-Users-user-Documents-Emerald/fec03359-0ca0-44c6-8339-007ace534169/scratchpad/bakecheck'
INGAME = os.path.expanduser('~/Documents/Emerald/docs/ortho45/buildings.json')
PAD = 48
BIG = 1 << 40
BG = np.array([30, 30, 34], np.float64)
DIM = 0.35
COMPARE = ['b034_rustborocity_house3', 'b030_rustborocity_house1', 'birch_lab', 'littleroot_house',
           'center2', 'mart2', 'b001_petalburgcity_house1', 'b092_lavaridgetown_herbshop',
           'b003_petalburgcity_gym', 'trainer_hill_penthouse', 'weather', 'devon2']


def parse(path):
    txt = open(path, encoding='utf-8').read()
    hdr = re.search(r"^return\s*\{([^\n]*)", txt, re.M).group(1)
    s = lambda k: re.search(r"\b%s='([^']*)'" % k, hdr).group(1)
    n = lambda k: int(re.search(r"\b%s=(-?\d+)" % k, hdr).group(1))
    qm = re.search(r"quads=\{([^}]*)\}", txt)
    nums = [int(v) for v in re.findall(r'-?\d+', qm.group(1))] if qm else []
    assert len(nums) % 10 == 0, path
    quads = [nums[i:i + 10] for i in range(0, len(nums), 10)]
    return dict(name=s('name'), map=s('map'), pair=s('pair'), rect=(n('x0'), n('y0'), n('x1'), n('y1')),
                quads=quads)


def load_ref():
    try:
        sys.path.insert(0, REF_DIR)
        import ref
        return ref.building_mask, None
    except Exception as e:  # ref.py is being rewritten: fall back to alpha
        return None, '%s: %s' % (type(e).__name__, e)


def project(quads, H, W):
    """Z-buffered oblique projection. Returns canvas key/colour (PAD rows above the art)."""
    CH = H + PAD
    key = np.full((CH, W), BIG, np.int64)
    col = np.zeros((CH, W, 3), np.uint8)
    st = dict(ignored=0, z_mismatch=0, h_mismatch=0, above_units=0, below_units=0,
              beside_px=0, ties=0, transparent_src=0, faces={})
    return key, col, st


def render(quads, art):
    H, W = art.shape[:2]
    CH = H + PAD
    key, col, st = project(quads, H, W)
    for q in quads:
        f, x0, x1, h0, h1, z0, z1, px, py, _ = q
        st['faces'][f] = st['faces'].get(f, 0) + 1
        if f not in (1, 3):
            st['ignored'] += 1
            continue
        assert 0 <= py < H and 0 <= px < W, q
        if art[py, px, 3] < 128:
            st['transparent_src'] += 1
        rgb = art[py, px, :3]
        cols = np.arange(x0, x1)
        st['beside_px'] += int(((cols < 0) | (cols >= W)).sum()) * max(0, h1 - h0)
        cols = cols[(cols >= 0) & (cols < W)]
        if cols.size == 0:
            continue
        if f == 1:
            if z0 != z1:
                st['z_mismatch'] += 1
            d = -z0
            ks = np.arange(h0, h1) + d
            rows = (H - 1 - ks) + PAD
            keys = np.full(rows.shape, 2 * d, np.int64)
        else:
            if h0 != h1:
                st['h_mismatch'] += 1
            ds = np.arange(-z1, -z0)
            rows = (H - 1 - (h0 + ds)) + PAD
            keys = 2 * ds + 1
        st['above_units'] += int((rows < 0).sum())
        st['below_units'] += int((rows >= CH).sum())
        ok = (rows >= 0) & (rows < CH)
        R, K = rows[ok], keys[ok]
        if R.size == 0:
            continue
        ix = np.ix_(R, cols)
        cur = key[ix]
        Kc = K[:, None]
        win = Kc < cur
        st['ties'] += int(((Kc == cur) & (cur < BIG)).sum())
        key[ix] = np.where(win, Kc, cur)
        col[ix] = np.where(win[..., None], rgb, col[ix])
    return key < BIG, col, st


def rankdata(a):
    _, inv, cnt = np.unique(a, return_inverse=True, return_counts=True)
    cum = np.cumsum(cnt)
    avg = ((cum - cnt + 1) + cum) / 2.0
    return avg[inv]


def spearman(x, y):
    rx, ry = rankdata(np.asarray(x, float)), rankdata(np.asarray(y, float))
    rx, ry = rx - rx.mean(), ry - ry.mean()
    return float((rx * ry).sum() / np.sqrt((rx * rx).sum() * (ry * ry).sum()))


def sheet(art, cov, col, bmask, wrong, bare, extra):
    H, W = art.shape[:2]
    CH = H + PAD
    a = art[..., 3:4].astype(np.float64) / 255.0
    p1 = np.tile(BG, (CH, W, 1))
    p1[PAD:] = art[..., :3] * a + BG * (1 - a)
    p2 = np.tile(BG, (CH, W, 1))
    p2[cov] = col[cov]
    p3 = np.tile(BG, (CH, W, 1))
    p3[PAD:] = (art[..., :3] * a + BG * (1 - a)) * DIM
    for m, c in ((wrong, (255, 0, 255)), (bare, (255, 255, 0)), (extra, (0, 255, 255))):
        p3[PAD:][m] = c
    gap = np.tile(BG, (CH, 4, 1))
    img = np.concatenate([p1, gap, p2, gap, p3], axis=1).clip(0, 255).astype(np.uint8)
    im = Image.fromarray(img)
    return im.resize((im.width * 3, im.height * 3), Image.NEAREST)


def check(info, M, mask_fn):
    x0, y0, x1, y1 = info['rect']
    art = M.compose(info['pair'], info['map'], x0, y0, x1, y1)
    H, W = art.shape[:2]
    cov, col, st = render(info['quads'], art)
    if mask_fn is not None:
        full = mask_fn(info['map'], info['rect'], pair=info['pair'])
        bm = full[y0 * 16:(y1 + 1) * 16, x0 * 16:(x1 + 1) * 16]
        assert bm.shape == (H, W), (bm.shape, H, W)
        bmask = (art[..., 3] >= 128) & bm
    else:
        bmask = art[..., 3] >= 128
    mc, mcov = col[PAD:], cov[PAD:]
    eq = (mc == art[..., :3]).all(axis=2)
    match = bmask & mcov & eq
    wrong = bmask & mcov & ~eq
    bare = bmask & ~mcov
    extra = ~bmask & mcov
    art_px = int(bmask.sum())
    wb = wrong | bare
    rows = []
    for r in range(H):
        nb = int(bmask[r].sum())
        if nb == 0:
            rows.append('-')
        else:
            rows.append(str(min(9, int(10 * int(wb[r].sum()) / nb))))
    res = dict(name=info['name'], map=info['map'], pair=info['pair'], rect=list(info['rect']),
               W=W, H=H, quads=len(info['quads']), art_px=art_px, match=int(match.sum()),
               wrong=int(wrong.sum()), bare=int(bare.sum()), extra=int(extra.sum()),
               above=int(cov[:PAD].sum()), percent=(100.0 * int(wb.sum()) / art_px) if art_px else None,
               rows=''.join(rows), faces=st['faces'], ignored_quads=st['ignored'],
               z_mismatch=st['z_mismatch'], h_mismatch=st['h_mismatch'], ties=st['ties'],
               transparent_src=st['transparent_src'], above_units_off_canvas=st['above_units'],
               below_units=st['below_units'], beside_px=st['beside_px'])
    return res, (art, cov, col, bmask, wrong, bare, extra)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('names', nargs='*')
    ap.add_argument('--out', default=OUT)
    ap.add_argument('--sheet', action='store_true')
    ap.add_argument('--mask', choices=['ref', 'alpha'], default='alpha')
    ap.add_argument('--dir', help='read bakes from this folder instead of the mod tree (freshly exported ones)')
    a = ap.parse_args()
    t0 = time.perf_counter()
    import bldmodel as M
    mask_fn, note = None, 'alpha >= 128 (no ground removal)'
    if a.mask == 'ref':
        mask_fn, err = load_ref()
        if mask_fn is None:
            note = 'alpha >= 128 (FALLBACK: ref.building_mask not importable: %s)' % err
        else:
            note = 'alpha >= 128 AND ref.building_mask (ref ground rule)'
    os.makedirs(a.out, exist_ok=True)
    if a.sheet:
        os.makedirs(os.path.join(a.out, 'sheets'), exist_ok=True)
    files = sorted(p for p in glob.glob(os.path.join(a.dir or DATA, '*.lua'))
                   if os.path.basename(p) != 'index.lua')
    if a.names:
        files = [p for p in files if any(s in os.path.basename(p) for s in a.names)]
    results = []
    for p in files:
        info = parse(p)
        ts = time.perf_counter()
        res, parts = check(info, M, mask_fn)
        res['file'] = os.path.basename(p)
        res['ms'] = round(1000 * (time.perf_counter() - ts), 1)
        results.append(res)
        if a.sheet:
            sheet(*parts).save(
                os.path.join(a.out, 'sheets', info['name'] + '.png'))
    total = time.perf_counter() - t0
    ing = {}
    if os.path.exists(INGAME):
        for e in json.load(open(INGAME))['entries']:
            v = e.get('rect_percent_all', e.get('rect_percent'))
            ing[e['name']] = v
    for r in results:
        r['ingame_percent'] = ing.get(r['name'])
    json.dump(dict(mask=note, buildings=results, total_seconds=round(total, 2)),
              open(os.path.join(a.out, 'bakes.json'), 'w'), indent=1)

    order = sorted(results, key=lambda r: (-(r['percent'] or 0), r['name']))
    L = ['# Bake check (offline, 45-degree projection vs drawing)', '',
         'Mask: %s. Buildings: %d. Runtime: %.1f s.' % (note, len(results), total), '',
         '| name | file | WxH | percent | wrong | bare | extra | above | rows (0-9 wrong+bare per art row) |',
         '|---|---|---|---|---|---|---|---|---|']
    for r in order:
        pc = '-' if r['percent'] is None else '%.2f' % r['percent']
        L.append('| %s | %s | %dx%d | %s | %d | %d | %d | %d | `%s` |' % (
            r['name'], r['file'], r['W'], r['H'], pc, r['wrong'], r['bare'], r['extra'], r['above'], r['rows']))
    pairs = [(r['percent'], r['ingame_percent']) for r in results
             if r['percent'] is not None and r['ingame_percent'] is not None]
    rho = spearman([p[0] for p in pairs], [p[1] for p in pairs]) if len(pairs) > 2 else float('nan')
    L += ['', 'Spearman (mine vs in-game rect_percent_all), n=%d: %.3f' % (len(pairs), rho), '',
          '| name | mine % | in-game % |', '|---|---|---|']
    byname = {r['name']: r for r in results}
    cmp_rows = []
    for nm in COMPARE:
        r = byname.get(nm)
        mine = None if r is None or r['percent'] is None else round(r['percent'], 2)
        g = ing.get(nm)
        cmp_rows.append((nm, mine, None if g is None else round(g, 2)))
        L.append('| %s | %s | %s |' % (nm, '-' if mine is None else mine, '-' if g is None else round(g, 2)))
    open(os.path.join(a.out, 'BAKES.md'), 'w').write('\n'.join(L) + '\n')

    print('mask:', note)
    print('buildings:', len(results), ' runtime %.1f s' % total)
    print('exactly 0%%: %d' % sum(1 for r in results if r['percent'] == 0))
    print('worst 10:')
    for r in order[:10]:
        print('  %-36s %7.2f  wrong %5d bare %5d extra %5d above %4d  %s' % (
            r['name'], r['percent'] or 0, r['wrong'], r['bare'], r['extra'], r['above'], r['rows']))
    print('best 10:')
    for r in order[::-1][:10]:
        print('  %-36s %7.2f  wrong %5d bare %5d extra %5d above %4d  %s' % (
            r['name'], r['percent'] or 0, r['wrong'], r['bare'], r['extra'], r['above'], r['rows']))
    print('compare: name | mine | in-game')
    for nm, mine, g in cmp_rows:
        print('  %-30s %8s %8s' % (nm, '-' if mine is None else mine, '-' if g is None else g))
    print('Spearman n=%d: %.3f' % (len(pairs), rho))
    print('faces/ignored/z_mismatch/h_mismatch/ties/transparent_src totals:',
          sum(sum(r['faces'].values()) for r in results), sum(r['ignored_quads'] for r in results),
          sum(r['z_mismatch'] for r in results), sum(r['h_mismatch'] for r in results),
          sum(r['ties'] for r in results), sum(r['transparent_src'] for r in results))
    print('above_units_off_canvas:', sum(r['above_units_off_canvas'] for r in results),
          ' below_units:', sum(r['below_units'] for r in results),
          ' beside_px:', sum(r['beside_px'] for r in results))
    print('outdir:', a.out)


if __name__ == '__main__':
    main()
