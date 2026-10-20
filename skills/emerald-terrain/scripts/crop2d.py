#!/usr/bin/env python3
# crop2d.py SLOT PAIR X0 Y0 X1 Y1 OUT.png [scale=3] [ids]
# Original map art for cells x0..x1, y0..y1 (inclusive). Grid line every cell,
# coordinates printed every 5 cells; "ids" also prints metatile id + collision.
import sys, os, zlib, struct, json, glob
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'tools'))
from sheet import png, FONT
C = os.path.expanduser('~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba')
def raw(p):
    b = open(p, 'rb').read()
    try: return zlib.decompress(b)
    except Exception: return b
def idx(p):
    b = raw(p); count, cols, rows = struct.unpack_from('<HHH', b, 6)
    return count, cols, rows, struct.unpack_from('<%dH' % count, b, 12)
slot, pair = sys.argv[1], sys.argv[2]
x0, y0, x1, y1 = map(int, sys.argv[3:7]); out = sys.argv[7]
S = int(sys.argv[8]) if len(sys.argv) > 8 else 3
ids_on = len(sys.argv) > 9 and sys.argv[9] == 'ids'
mdir = os.path.join(C, 'map_tree', 'maps', slot)
hdr = json.load(open(os.path.join(mdir, 'header.json')))
W, H = hdr['width'], hdr['height']
cells = struct.unpack('<%dH' % (W * H), open(os.path.join(mdir, 'grid.bin'), 'rb').read())
d = os.path.join(C, 'native', pair)
count, cols, rows, mids = idx(os.path.join(d, 'mids.idx'))
aw, ah = cols * 16, rows * 16
layers = []
for tag in ('u', 'm', 'o'):
    f = glob.glob(os.path.join(d, 'atlas_%s_*.rgba' % tag))
    layers.append(raw(f[0]) if f else None)
m2s = {m: i for i, m in enumerate(mids)}
cw = 16 * S
OW, OH = (x1 - x0 + 1) * cw, (y1 - y0 + 1) * cw
img = [bytearray(b'\x00\x00\x00\xff' * OW) for _ in range(OH)]
def put(x, y, c):
    if 0 <= x < OW and 0 <= y < OH:
        img[y][x*4:x*4+4] = bytes((c[0], c[1], c[2], 255))
def text(ox, oy, s):
    for y in range(7):
        for x in range(len(s) * 4 + 1): put(ox + x, oy + y, (0, 0, 0))
    for i, ch in enumerate(s):
        g = FONT.get(ch)
        if not g: continue
        for yy, row in enumerate(g):
            for xx, bit in enumerate(row):
                if bit == '1': put(ox + 1 + i * 4 + xx, oy + 1 + yy, (255, 255, 0))
for cy in range(y0, y1 + 1):
    for cx in range(x0, x1 + 1):
        if not (0 <= cx < W and 0 <= cy < H): continue
        v = cells[cy * W + cx]; mid = v & 0x3FF
        sl = m2s.get(mid)
        if sl is None: continue
        sx, sy = (sl % cols) * 16, (sl // cols) * 16
        for y in range(16):
            for x in range(16):
                o = ((sy + y) * aw + sx + x) * 4
                r, g, b = layers[0][o], layers[0][o+1], layers[0][o+2]
                for L in layers[1:]:
                    if L is None: continue
                    a = L[o+3]
                    if a:
                        k = a / 255
                        r, g, b = int(L[o]*k + r*(1-k)), int(L[o+1]*k + g*(1-k)), int(L[o+2]*k + b*(1-k))
                for yy in range(S):
                    for xx in range(S):
                        put((cx - x0) * cw + x * S + xx, (cy - y0) * cw + y * S + yy, (r, g, b))
        # grid
        for k in range(cw):
            put((cx - x0) * cw + k, (cy - y0) * cw, (40, 40, 40))
            put((cx - x0) * cw, (cy - y0) * cw + k, (40, 40, 40))
        if ids_on:
            col = (v >> 10) & 3; el = (v >> 12) & 15
            text((cx - x0) * cw + 1, (cy - y0) * cw + 1, '%X' % mid)
            text((cx - x0) * cw + 1, (cy - y0) * cw + 9, '%d %d' % (col, el))
        if cx % 5 == 0 and cy % 5 == 0:
            text((cx - x0) * cw + 1, (cy - y0) * cw + cw - 9, '%d,%d' % (cx, cy))
open(out,'wb').write(png(OW, OH, [bytes(r) for r in img]))
