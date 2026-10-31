#!/usr/bin/env python3
"""p5_sheet.py GOLD_DIR NEW_DIR OUT_PREFIX -- the P5 75-spot sheet: installed look | rewrite, per spot and level.

GOLD_DIR holds the M0 golden batches (y0_*/<MAP>_<L>.png, .rewrite/baseline/s4a/caps), NEW_DIR the rewrite's
batches (y0_*/<MAP>_L<L>.png from clean_try). One row per spot: gold L4 | new L4 | gold L7 | new L7, each
labelled with its mean absolute difference (0-255). Writes OUT_PREFIX_<n>.png pages of 15 rows and
OUT_PREFIX.tsv (map, level, mad, missing). The golden frames have actors, the rewrite's (cap_driver) do not.
"""
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

TW, TH, ROWS = 320, 180, 15


def index(root, pat):
    out = {}
    for p in glob.glob(os.path.join(root, 'y0_*', '*.png')):
        name = os.path.basename(p)[:-4]
        m, _, lv = name.rpartition('_')
        lv = lv.lstrip('L')
        if lv.isdigit():
            out[(m, int(lv))] = p
    return out


def thumb(p):
    if not p:
        return Image.new('RGB', (TW, TH), (60, 0, 60)), None
    im = Image.open(p).convert('RGB')
    return im.resize((TW, TH), Image.BILINEAR), np.asarray(im.resize((640, 360)), dtype=np.int16)


def main():
    gold, new, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
    G, N = index(gold, ''), index(new, '')
    maps = sorted({m for m, _ in G} | {m for m, _ in N})
    rows, tsv = [], ['map\tlevel\tmad\tmissing']
    for m in maps:
        cells = []
        for lv in (4, 7):
            tg, ag = thumb(G.get((m, lv)))
            tn, an = thumb(N.get((m, lv)))
            mad = float(np.abs(ag - an).mean()) if ag is not None and an is not None else None
            miss = ('gold ' if ag is None else '') + ('new' if an is None else '')
            tsv.append(f'{m}\t{lv}\t{"" if mad is None else f"{mad:.1f}"}\t{miss.strip()}')
            cells += [(tg, f'{m} L{lv} installed'), (tn, f'rewrite  mad {"-" if mad is None else f"{mad:.1f}"}')]
        rows.append(cells)
    with open(prefix + '.tsv', 'w') as f:
        f.write('\n'.join(tsv) + '\n')
    for page in range(0, len(rows), ROWS):
        chunk = rows[page:page + ROWS]
        sheet = Image.new('RGB', (4 * TW, len(chunk) * (TH + 14)), (20, 20, 20))
        d = ImageDraw.Draw(sheet)
        for r, cells in enumerate(chunk):
            for c, (im, label) in enumerate(cells):
                x, y = c * TW, r * (TH + 14)
                sheet.paste(im, (x, y + 14))
                d.text((x + 3, y + 1), label, fill=(255, 255, 0))
        sheet.save(f'{prefix}_{page // ROWS + 1}.png')
    print(f'{len(maps)} spots, {len(rows)} rows, pages {(len(rows) + ROWS - 1) // ROWS}')


if __name__ == '__main__':
    main()
