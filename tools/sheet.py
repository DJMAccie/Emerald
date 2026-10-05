#!/usr/bin/env python3
"""Render labelled metatile contact sheets from a gen1recomp Gen 3 native cache.

Reads <cache>/native/<pair>/mids.idx (SVMI header + mid id list) and the baked
atlas_u_*.rgba (under layer) / atlas_o_*.rgba (over layer) and writes PNG
sheets, one per band of rows, with each 16x16 metatile scaled up and its hex
id drawn in the corner.  Pure Python (zlib PNG writer, 3x5 bitmap font) so it
runs without PIL.

  python3 sheet.py <cache-root> <pair> <out-dir> [--scale 4] [--rows-per-sheet 8]
"""
import os, sys, struct, zlib, glob, json, argparse

FONT = {  # 3x5 glyphs, rows top->bottom, 1 = lit
    '0': ["111","101","101","101","111"], '1': ["010","110","010","010","111"],
    '2': ["111","001","111","100","111"], '3': ["111","001","111","001","111"],
    '4': ["101","101","111","001","001"], '5': ["111","100","111","001","111"],
    '6': ["111","100","111","101","111"], '7': ["111","001","001","001","001"],
    '8': ["111","101","111","101","111"], '9': ["111","101","111","001","111"],
    'A': ["111","101","111","101","101"], 'B': ["110","101","110","101","110"],
    'C': ["111","100","100","100","111"], 'D': ["110","101","101","101","110"],
    'E': ["111","100","111","100","111"], 'F': ["111","100","111","100","100"],
}

def read_idx(path):
    b = open(path, 'rb').read()
    assert b[:4] == b'SVMI', "bad mids.idx magic"
    count, cols, rows = struct.unpack_from('<HHH', b, 6)
    ids = struct.unpack_from('<%dH' % count, b, 12)
    return count, cols, rows, ids

def read_rgba(path, w, h):
    b = open(path, 'rb').read()
    assert len(b) == w * h * 4, "atlas size mismatch %d != %d" % (len(b), w * h * 4)
    return b

def png(w, h, rgba_rows):
    raw = b''.join(b'\x00' + r for r in rgba_rows)
    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 6)) + chunk(b'IEND', b''))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('cache'); ap.add_argument('pair'); ap.add_argument('out')
    ap.add_argument('--scale', type=int, default=4)
    ap.add_argument('--rows-per-sheet', type=int, default=8)
    ap.add_argument('--layer', default='composite', choices=['under', 'over', 'composite'])
    a = ap.parse_args()
    d = os.path.join(a.cache, 'native', a.pair)
    count, cols, rows, ids = read_idx(os.path.join(d, 'mids.idx'))
    w, h = cols * 16, rows * 16
    under = read_rgba(glob.glob(os.path.join(d, 'atlas_u_*.rgba'))[0], w, h)
    over_files = glob.glob(os.path.join(d, 'atlas_o_*.rgba'))
    over = read_rgba(over_files[0], w, h) if over_files else None
    mid_files = glob.glob(os.path.join(d, 'atlas_m_*.rgba'))
    mid = read_rgba(mid_files[0], w, h) if mid_files else None
    S = a.scale
    os.makedirs(a.out, exist_ok=True)
    # per-slot -> mid id
    slot_to_mid = {i: mid for i, mid in enumerate(ids)}
    # composite pixel fetch
    def blend(base, layer, o):
        r, g, b, al = base
        ro, go, bo, ao = layer[o], layer[o+1], layer[o+2], layer[o+3]
        if ao == 0:
            return r, g, b, al
        k = ao / 255.0
        return (int(ro*k + r*(1-k)), int(go*k + g*(1-k)), int(bo*k + b*(1-k)), 255)
    def px(x, y):
        o = (y * w + x) * 4
        base = (under[o], under[o+1], under[o+2], under[o+3])
        if a.layer == 'under':
            return base
        if a.layer == 'over':
            return (over[o], over[o+1], over[o+2], over[o+3]) if over else base
        if mid is not None:
            base = blend(base, mid, o)
        if over is not None:
            base = blend(base, over, o)
        return base
    band = a.rows_per_sheet
    cell = 16 * S + 1  # 1px grid line
    made = []
    for r0 in range(0, rows, band):
        r1 = min(rows, r0 + band)
        H = (r1 - r0) * cell + 1
        W = cols * cell + 1
        img = [bytearray(b'\x30\x30\x30\xff' * W) for _ in range(H)]
        for ry in range(r0, r1):
            for cx in range(cols):
                slot = ry * cols + cx
                if slot >= count:
                    continue
                ox, oy = cx * cell + 1, (ry - r0) * cell + 1
                for y in range(16):
                    for x in range(16):
                        r, g, b, al = px(cx * 16 + x, ry * 16 + y)
                        if al == 0:
                            r, g, b = (200, 60, 200) if (x // 4 + y // 4) % 2 else (150, 40, 150)
                        for sy in range(S):
                            row = img[oy + y * S + sy]
                            for sx in range(S):
                                p = (ox + x * S + sx) * 4
                                row[p:p+4] = bytes((r, g, b, 255))
                # label: hex id, white on black box, top-left
                label = '%03X' % slot_to_mid[slot]
                lw = len(label) * 4 + 1
                for y in range(7):
                    row = img[oy + y]
                    for x in range(lw):
                        p = (ox + x) * 4
                        row[p:p+4] = b'\x00\x00\x00\xff'
                for i, ch in enumerate(label):
                    g_ = FONT[ch]
                    for y in range(5):
                        for x in range(3):
                            if g_[y][x] == '1':
                                p = (ox + 1 + i * 4 + x) * 4
                                img[oy + 1 + y][p:p+4] = b'\xff\xff\x00\xff'
        name = '%s_%s_r%02d-%02d.png' % (a.pair, a.layer, r0, r1 - 1)
        open(os.path.join(a.out, name), 'wb').write(png(W, H, [bytes(r) for r in img]))
        made.append(name)
    json.dump({'pair': a.pair, 'count': count, 'cols': cols, 'rows': rows, 'sheets': made},
              open(os.path.join(a.out, a.pair + '.json'), 'w'), indent=1)
    print('wrote', len(made), 'sheets for', a.pair, 'mids=%d cols=%d rows=%d' % (count, cols, rows))

if __name__ == '__main__':
    main()
