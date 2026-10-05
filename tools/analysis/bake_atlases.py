#!/usr/bin/env python3
"""Bake every tileset's atlases OFFLINE (no game, no display), exactly as the
engine's NativePack.bakeRgba does, from the cached mids*.idx + palettes.bin.
The engine now builds atlas_*.rgba only when a map is visited; offline tools
(layers.py -> pxmap.py, midgrid.py) fall back to these.

python3 bake_atlases.py [pair ...]      (default: every pair)
Output: ~/Documents/gen1recomp-modwork/offline_atlas/<pair>/atlas_{u,m,o}.rgba
(never written into the game's own cache)."""
import os, sys, glob, struct, zlib

NATIVE = os.path.expanduser('~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba/native')
OUT = os.path.expanduser('~/Documents/gen1recomp-modwork/offline_atlas')

def raw(path):
    b = open(path, 'rb').read()
    return zlib.decompress(b) if b[:1] == b'\x78' else b

def decode_idx(b):
    assert b[:4] == b'SVMI', 'bad mids.idx magic'
    count, cols, rows = struct.unpack_from('<HHH', b, 6)
    ids = struct.unpack_from('<%dH' % count, b, 12)
    pix = b[12 + 2 * count: 12 + 2 * count + 256 * count]
    return count, cols, rows, ids, pix

def palettes(b):
    assert b[:4] == b'SVMP', 'bad palettes.bin magic'
    vals = struct.unpack_from('<256H', b, 8)
    out = []
    for p in range(16):
        row = []
        for c in range(16):
            v = vals[p * 16 + c] % 32768
            r5, g5, b5 = v % 32, (v >> 5) % 32, (v >> 10) % 32
            row.append(bytes((int(r5 * 255 / 31 + .5), int(g5 * 255 / 31 + .5), int(b5 * 255 / 31 + .5), 255)))
        out.append(row)
    return out

def bake(count, cols, rows, pix, pals, transparent_zero):
    lut = []
    for byte in range(256):
        if transparent_zero and byte == 0: lut.append(b'\0\0\0\0')
        else: lut.append(pals[(byte >> 4) % 16][byte % 16])
    w, h = cols * 16, rows * 16
    out = bytearray(w * h * 4)
    for slot in range(count):
        sx, sy = (slot % cols) * 16, (slot // cols) * 16
        base = slot * 256
        for py in range(16):
            o = ((sy + py) * w + sx) * 4
            row = b''.join(lut[pix[base + py * 16 + px]] for px in range(16))
            out[o:o + 64] = row
    return bytes(out)

def run(pair):
    d = os.path.join(NATIVE, pair)
    if not os.path.exists(os.path.join(d, 'palettes.bin')): return False
    pals = palettes(raw(os.path.join(d, 'palettes.bin')))
    od = os.path.join(OUT, pair); os.makedirs(od, exist_ok=True)
    for tag, idx, tz in (('u', 'mids.idx', False), ('m', 'mids_mid.idx', True), ('o', 'mids_over.idx', True)):
        p = os.path.join(d, idx)
        if not os.path.exists(p): continue
        count, cols, rows, ids, pix = decode_idx(raw(p))
        open(os.path.join(od, 'atlas_%s.rgba' % tag), 'wb').write(bake(count, cols, rows, pix, pals, tz))
        open(os.path.join(od, idx), 'wb').write(raw(p))
    return True

if __name__ == '__main__':
    pairs = sys.argv[1:] or sorted(os.listdir(NATIVE))
    n = 0
    for p in pairs:
        try:
            if run(p): n += 1
        except Exception as e:
            print('skip', p, e)
    print('baked', n, 'pairs into', OUT)
