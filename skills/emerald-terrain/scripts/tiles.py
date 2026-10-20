#!/usr/bin/env python3
# tiles.py PAIR FIRST LAST OUT.png [scale=4] [cols=8]  labelled sheet of metatiles FIRST..LAST (hex ok)
import sys, os, zlib, struct, glob
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'tools'))
from sheet import png, FONT
C = os.path.expanduser('~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native')
def raw(p):
    b = open(p, 'rb').read()
    try: return zlib.decompress(b)
    except Exception: return b
pair = sys.argv[1]; a = int(sys.argv[2], 0); z = int(sys.argv[3], 0); out = sys.argv[4]
S = int(sys.argv[5]) if len(sys.argv) > 5 else 4; NC = int(sys.argv[6]) if len(sys.argv) > 6 else 8
d = os.path.join(C, pair)
b = raw(os.path.join(d, 'mids.idx')); count, cols, rows = struct.unpack_from('<HHH', b, 6); ids = struct.unpack_from('<%dH' % count, b, 12)
aw = cols * 16
L = [raw(glob.glob(os.path.join(d, 'atlas_%s_*.rgba' % t))[0]) if glob.glob(os.path.join(d, 'atlas_%s_*.rgba' % t)) else None for t in 'umo']
m2s = {m: i for i, m in enumerate(ids)}
mids = list(range(a, z + 1)); G = 16 * S + 4; LB = 9
W = NC * G; H = ((len(mids) + NC - 1) // NC) * (G + LB)
img = [bytearray(b'\x40\x40\x40\xff' * W) for _ in range(H)]
def put(x, y, c):
    if 0 <= x < W and 0 <= y < H: img[y][x*4:x*4+4] = bytes((c[0], c[1], c[2], 255))
for k, m in enumerate(mids):
    gx, gy = (k % NC) * G, (k // NC) * (G + LB)
    s = '%X' % m
    for i, ch in enumerate(s):
        for yy, row in enumerate(FONT.get(ch, [])):
            for xx, bit in enumerate(row):
                if bit == '1':
                    for q in range(2):
                        for p in range(2): put(gx + 2 + (i * 4 + xx) * 2 + p, gy + 1 + yy * 2 + q - 1, (255, 255, 0))
    sl = m2s.get(m)
    if sl is None: continue
    sx, sy = (sl % cols) * 16, (sl // cols) * 16
    for y in range(16):
        for x in range(16):
            o = ((sy + y) * aw + sx + x) * 4
            r, g, bb = L[0][o], L[0][o+1], L[0][o+2]
            for Ly in L[1:]:
                if Ly is None: continue
                al = Ly[o+3]
                if al:
                    kk = al / 255; r, g, bb = int(Ly[o]*kk + r*(1-kk)), int(Ly[o+1]*kk + g*(1-kk)), int(Ly[o+2]*kk + bb*(1-kk))
            for q in range(S):
                for p in range(S): put(gx + x * S + p, gy + LB + y * S + q, (r, g, bb))
open(out, 'wb').write(png(W, H, [bytes(r) for r in img]))
