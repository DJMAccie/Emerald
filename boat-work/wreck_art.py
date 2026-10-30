#!/usr/bin/env python3
"""Compose the Abandoned Ship wreck drawing exactly as BuildingVoxels does (mid layer + over)."""
import glob
import json
import os
import struct
import sys
import zlib

from PIL import Image

C = os.path.expanduser("~/Library/Application Support/pokemon-love2d-rseqa/emerald/data/generated/gba")


def raw(p):
    b = open(p, "rb").read()
    try:
        return zlib.decompress(b)
    except Exception:
        return b


def atlas(pair):
    d = os.path.join(C, "native", pair)
    b = raw(os.path.join(d, "mids.idx"))
    count, cols, rows = struct.unpack_from("<HHH", b, 6)
    mids = struct.unpack_from("<%dH" % count, b, 12)
    m2s = {m: i for i, m in enumerate(mids)}
    layers = {}
    for tag in ("m", "o", "u"):
        f = glob.glob(os.path.join(d, "atlas_%s_*.rgba" % tag))
        layers[tag] = raw(f[0]) if f else None
    return m2s, cols, rows, layers


def main():
    slot, pair = "0_23", "general__slateport"
    x0, y0, x1, y1 = 27, 3, 33, 5
    mdir = os.path.join(C, "map_tree", "maps", slot)
    hdr = json.load(open(os.path.join(mdir, "header.json")))
    W, H = hdr["width"], hdr["height"]
    cells = struct.unpack("<%dH" % (W * H), open(os.path.join(mdir, "grid.bin"), "rb").read())
    m2s, cols, rows, L = atlas(pair)
    aw = cols * 16
    ow, oh = (x1 - x0 + 1) * 16, (y1 - y0 + 1) * 16
    img = Image.new("RGBA", (ow, oh), (0, 0, 0, 0))
    px = img.load()
    base = L["m"]
    over = L["o"]
    for cy in range(y0, y1 + 1):
        for cx in range(x0, x1 + 1):
            mid = cells[cy * W + cx] & 0x3FF
            sl = m2s.get(mid)
            if sl is None:
                print("no slot for mid %X" % mid, file=sys.stderr)
                continue
            sx, sy = (sl % cols) * 16, (sl // cols) * 16
            for y in range(16):
                for x in range(16):
                    o = ((sy + y) * aw + sx + x) * 4
                    r, g, b, a = base[o], base[o + 1], base[o + 2], base[o + 3]
                    if over is not None:
                        oa = over[o + 3]
                        if oa:
                            k = oa / 255
                            r, g, b = int(over[o] * k + r * (1 - k)), int(over[o + 1] * k + g * (1 - k)), int(over[o + 2] * k + b * (1 - k))
                            a = max(a, oa)
                    px[(cx - x0) * 16 + x, (cy - y0) * 16 + y] = (r, g, b, a)
    img.save("/tmp/wreck_drawing.png")
    img.resize((ow * 8, oh * 8), Image.NEAREST).save("/tmp/wreck_drawing_x8.png")
    print("wrote /tmp/wreck_drawing.png", img.size)


if __name__ == "__main__":
    main()
