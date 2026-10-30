#!/usr/bin/env python3
"""Gate for the world fill: rebuild Hoenn from our maps plus assets/worldfill/fill.bin and compare with the reference.

  python3 render_check.py [--fill <dir>]

Per cell, the rebuilt 16x16 block (palette widened like the reference) must equal the reference block (taken at the
grid; the fill's shifted patches and open-sea cells are compared by what they stand for). Prints the share of exact
cells for the maps and for the fill, the worst maps, and writes ref/check.png: reference | rebuilt | misses, 1/8 scale.
"""
import os, sys, json, zlib, struct, argparse
import numpy as np
from PIL import Image
import world as Wd, ref as R
from make_fill import pair_looks, q8, SEA_MID

Image.MAX_IMAGE_PIXELS = None
HERE = os.path.dirname(os.path.abspath(__file__))


def read_fill(d):
    b = open(os.path.join(d, 'fill.bin'), 'rb').read()
    assert b[:4] == b'WFIL'
    ver, ox, oy, W, H, n = struct.unpack_from('<HhhHHH', b, 4)
    o = 4 + 12
    pairs = []
    for _ in range(n):
        ln = b[o]; pairs.append(b[o + 1:o + 1 + ln].decode()); o += 1 + ln
    cells = np.frombuffer(zlib.decompress(b[o:]), '<u2').reshape(H, W)
    return ox, oy, pairs, cells


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--fill', default=os.path.expanduser('~/Documents/battle-art-notquiteog/assets/worldfill'))
    a = ap.parse_args()
    os.chdir(HERE)
    gx0, gy0, pairs, cells = read_fill(a.fill)
    H, W = cells.shape
    refimg = np.asarray(Image.open('ref/filled.png').convert('RGB'))
    out = np.zeros((H * 16, W * 16, 3), np.uint8)
    looks = {p: pair_looks(p) for p in pairs + ['general__petalburg']}
    sea = looks['general__petalburg'][SEA_MID]
    out[:] = np.tile(sea, (H, W, 1))
    # fill
    for y, x in zip(*np.nonzero(cells)):
        c = int(cells[y, x]); p = pairs[(c >> 10) - 1]; m = c & 0x3FF
        out[y * 16:y * 16 + 16, x * 16:x * 16 + 16] = looks[p][m]
    # maps
    world = Wd.load_world()
    place = {}
    src = open(os.path.join(a.fill, 'placements.lua')).read()
    import re
    for k, ox, oy, w, h, ov in re.findall(r'(EM_\w+)=\{ox=(-?\d+),oy=(-?\d+),w=(\d+),h=(\d+)(,overlay=true)?\}', src):
        if not ov:
            place[k] = {'ox': int(ox), 'oy': int(oy)}
    permap = {}
    owner = np.full((H, W), -1, np.int32)
    names = []
    for k, e in list(world.items()) + list(place.items()):
        m = R.load_map(k)
        x, y = e['ox'] - gx0, e['oy'] - gy0
        out[y * 16:(y + m['H']) * 16, x * 16:(x + m['W']) * 16] = q8(m['img'][..., :3]).astype(np.uint8)
        names.append(k); owner[y:y + m['H'], x:x + m['W']] = len(names) - 1
    refc = refimg[:H * 16, :W * 16]
    eq = (out.reshape(H, 16, W, 16, 3) == refc.reshape(H, 16, W, 16, 3)).all(axis=(1, 3, 4))
    # the fill's shifted patches and sea frames: compare the class (sea vs land), not the pixels
    fillcell = owner < 0
    seaRef = np.abs(refc.reshape(H, 16, W, 16, 3).mean(axis=(1, 3)) - np.array([80, 104, 208])).sum(axis=2) < 60
    seaOut = cells == 0
    fill_ok = eq | (seaRef == seaOut)
    print('fill cells %d: exact %.2f%%, same class %.2f%%' % (fillcell.sum(), 100 * eq[fillcell].mean(), 100 * fill_ok[fillcell].mean()))
    print('map cells %d: exact %.2f%%' % ((~fillcell).sum(), 100 * eq[~fillcell].mean()))
    for i, k in enumerate(names):
        sel = owner == i
        permap[k] = float(eq[sel].mean())
    worst = sorted(permap.items(), key=lambda kv: kv[1])[:8]
    print('worst maps', [(k, round(v, 3)) for k, v in worst])
    miss = np.zeros((H, W, 3), np.uint8)
    miss[~fillcell & ~eq] = (255, 160, 0)
    miss[fillcell & ~fill_ok] = (255, 0, 255)
    miss[fillcell & fill_ok] = (40, 60, 120)
    miss[~fillcell & eq] = (40, 90, 40)
    s = 8
    a1 = Image.fromarray(refc).resize((W * 16 // s, H * 16 // s), Image.BOX)
    a2 = Image.fromarray(out).resize((W * 16 // s, H * 16 // s), Image.BOX)
    a3 = Image.fromarray(miss).resize((W * 2, H * 2), Image.NEAREST)
    sheet = Image.new('RGB', (a1.width, a1.height * 3 + 20), (20, 20, 24))
    sheet.paste(a1, (0, 0)); sheet.paste(a2, (0, a1.height + 10)); sheet.paste(a3, (0, 2 * a1.height + 20))
    sheet.save('ref/check.png')
    Image.fromarray(out).resize((W * 4, H * 4), Image.BOX).save('ref/rebuilt_quarter.png')
    json.dump(permap, open('ref/check_maps.json', 'w'), indent=1)


if __name__ == '__main__':
    main()
