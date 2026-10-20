#!/usr/bin/env python3
"""Score a folder (or list) of captures for visual artefacts and render a contact sheet of the worst 30.

  python3 -I tools/shot_filter.py <dir_or_png...> [--out DIR] [--json FILE] [--sheet FILE]

Metrics per capture:
  - magenta_low:   share of magenta probe pixels (R>190, G<80, B>190) in the lower 45% of the frame
                   (same threshold and band as tools/magenta_score.py)
  - magenta_total: share of magenta probe pixels over the whole frame
  - flat_share:    share of 4x4 pixel blocks that are a single flat colour (zero RGB range within the block)
  - edge_streak:   share of pixels lying on >=8 px horizontal or vertical streaks where a sharp colour step
                   (>20 across one axis) repeats nearly unchanged (<=2 along the perpendicular axis)
  - score:         combined ranking score (100 * magenta_low + 10 * edge_streak + flat_share)

Writes filter.json and a 6-column contact sheet (worst_30.png) of the 30 highest-scoring captures.
"""
import argparse
import glob
import json
import os
import sys

# Allow `python3 -I` to find Pillow when it is installed in the user site-packages directory
try:
    from PIL import Image, ImageDraw
except ModuleNotFoundError:
    _user_site = os.path.expanduser(
        '~/Library/Python/%d.%d/lib/python/site-packages' % sys.version_info[:2]
    )
    if os.path.isdir(_user_site) and _user_site not in sys.path:
        sys.path.append(_user_site)
    from PIL import Image, ImageDraw

import numpy as np

SKIP_NAMES = {'worst_30.png', 'filter_sheet.png'}


def collect_pngs(inputs, sheet_abs=None):
    paths = []
    seen = set()
    for item in inputs:
        if os.path.isdir(item):
            cands = sorted(glob.glob(os.path.join(item, '*.png')))
        elif os.path.isfile(item) and item.lower().endswith('.png'):
            cands = [item]
        else:
            cands = sorted(glob.glob(item))
        for p in cands:
            ap = os.path.abspath(p)
            if ap in seen or not os.path.isfile(ap):
                continue
            if sheet_abs and ap == sheet_abs:
                continue
            if os.path.basename(ap) in SKIP_NAMES:
                continue
            seen.add(ap)
            paths.append(p)
    return paths


def score_image(path):
    with Image.open(path) as im:
        rgb = im.convert('RGB')
        w, h = rgb.size
        a = np.asarray(rgb, dtype=np.int16)

    # 1. Magenta-hole score in the lower 45% of the frame (matches tools/magenta_score.py)
    mag = (a[..., 0] > 190) & (a[..., 1] < 80) & (a[..., 2] > 190)
    magenta_low = float(mag[int(h * 0.55):].mean()) if h > 0 else 0.0
    magenta_total = float(mag.mean()) if h > 0 and w > 0 else 0.0

    # 2. Flat single-colour area share: fraction of 4x4 blocks with zero RGB range
    bh, bw = h // 4, w // 4
    if bh > 0 and bw > 0:
        blk = a[:bh * 4, :bw * 4].reshape(bh, 4, bw, 4, 3)
        rng = (blk.max(axis=(1, 3)) - blk.min(axis=(1, 3))).max(axis=-1)
        flat_share = float((rng == 0).mean())
    else:
        flat_share = 0.0

    # 3. Edge-streak score: sharp edge (>20) across one axis repeated (<=2) for >=8 px along the other
    if h >= 9 and w >= 9:
        gx = np.abs(a[:, 1:] - a[:, :-1]).max(axis=-1)
        gy = np.abs(a[1:, :] - a[:-1, :]).max(axis=-1)
        v_cand = (gx[1:, :] > 20) & (gy[:, 1:] <= 2)
        h_cand = (gy[:, 1:] > 20) & (gx[1:, :] <= 2)
        v_run = v_cand.copy()
        for s in range(1, 8):
            v_run[s:, :] &= v_cand[:-s, :]
        h_run = h_cand.copy()
        for s in range(1, 8):
            h_run[:, s:] &= h_cand[:, :-s]
        edge_streak = float((v_run | h_run).mean())
    else:
        edge_streak = 0.0

    combined = 100.0 * magenta_low + 10.0 * edge_streak + flat_share
    return {
        'file': os.path.basename(path),
        'path': path,
        'width': w,
        'height': h,
        'magenta_low': round(magenta_low, 6),
        'magenta_total': round(magenta_total, 6),
        'flat_share': round(flat_share, 6),
        'edge_streak': round(edge_streak, 6),
        'score': round(combined, 6),
    }


def write_contact_sheet(rows, out_path, limit=30):
    worst = rows[:limit]
    if not worst:
        return 0
    tw, th = 320, 180
    cols = min(6, len(worst))
    nrows = (len(worst) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * tw, nrows * th), (20, 20, 24))
    dr = ImageDraw.Draw(sheet)

    for idx, r in enumerate(worst):
        with Image.open(r['path']) as im:
            thumb = im.convert('RGB').resize((tw, th))
        x = (idx % cols) * tw
        y = (idx // cols) * th
        sheet.paste(thumb, (x, y))

        title = '#%02d %s' % (idx + 1, r['file'][:34])
        metrics = 'mag %.4f  flat %.3f  strk %.4f' % (
            r['magenta_low'], r['flat_share'], r['edge_streak']
        )
        dr.rectangle([x, y, x + tw - 1, y + 26], fill=(0, 0, 0))
        dr.text((x + 4, y + 2), title, fill=(255, 230, 80))
        dr.text((x + 4, y + 14), metrics, fill=(230, 230, 230))

    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    sheet.save(out_path)
    return len(worst)


def main(argv=None):
    ap = argparse.ArgumentParser(description='Compute capture defect scores and worst-30 contact sheet.')
    ap.add_argument('inputs', nargs='+', help='folder(s) or PNG path(s) to score')
    ap.add_argument('--out', '-o', help='output directory for filter.json and worst_30.png')
    ap.add_argument('--json', dest='json_path', help='explicit path for filter.json')
    ap.add_argument('--sheet', dest='sheet_path', help='explicit path for worst-30 contact sheet PNG')
    ap.add_argument('--limit', type=int, default=30, help='max tiles in contact sheet (default: 30)')
    args = ap.parse_args(argv)

    if args.out:
        base_dir = args.out
    elif len(args.inputs) == 1 and os.path.isdir(args.inputs[0]):
        base_dir = args.inputs[0]
    else:
        base_dir = os.path.dirname(os.path.abspath(args.inputs[0])) or '.'

    json_out = args.json_path or os.path.join(base_dir, 'filter.json')
    sheet_out = args.sheet_path or os.path.join(base_dir, 'worst_30.png')

    pngs = collect_pngs(args.inputs, sheet_abs=os.path.abspath(sheet_out))
    if not pngs:
        sys.exit('no PNG files found in: ' + ' '.join(args.inputs))

    rows = [score_image(p) for p in pngs]
    rows.sort(key=lambda r: (-r['score'], -r['magenta_low'], -r['edge_streak'], -r['flat_share'], r['file']))

    os.makedirs(os.path.dirname(os.path.abspath(json_out)), exist_ok=True)
    n_sheet = write_contact_sheet(rows, sheet_out, limit=args.limit)

    payload = {
        'count': len(rows),
        'with_magenta_low': sum(1 for r in rows if r['magenta_low'] > 0.0005),
        'sheet': os.path.basename(sheet_out),
        'sheet_tiles': n_sheet,
        'worst_30': rows[:args.limit],
        'shots': rows,
    }
    with open(json_out, 'w') as f:
        json.dump(payload, f, indent=1)
        f.write('\n')

    print('%-42s %10s %10s %10s %10s' % ('Capture', 'MagLow', 'FlatShare', 'EdgeStrk', 'Score'))
    print('-' * 86)
    for r in rows[:args.limit]:
        print('%-42s %10.5f %10.4f %10.5f %10.4f' % (
            r['file'][:42], r['magenta_low'], r['flat_share'], r['edge_streak'], r['score']))
    print('-' * 86)
    print('frames %d  with_magenta_low %d  wrote %s and %s (%d tiles)' % (
        len(rows), payload['with_magenta_low'], json_out, sheet_out, n_sheet))
    return 0


if __name__ == '__main__':
    sys.exit(main())
