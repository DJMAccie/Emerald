#!/usr/bin/env python3
"""The counted pieces over the drawing (3DS: voxel_terraces.overlay):
each cell's piece kind and top level written on the map art, with the
kind letter (G ground, T top, R rock, ? unknown) in the corner.

    python3 proof.py RELIEF.json X0 Y0 X1 Y1 OUT.png [scale=4]
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import emdata as E  # noqa: E402

PAL = [(0, 170, 0), (0, 120, 255), (255, 200, 0), (255, 90, 0), (230, 0, 0), (200, 0, 200)]


def main():
    path = sys.argv[1]
    x0, y0, x1, y1 = map(int, sys.argv[2:6])
    out = sys.argv[6]
    S = int(sys.argv[7]) if len(sys.argv) > 7 else 4
    J = json.load(open(path))
    L = E.Layout(J["map"])
    cw = 16 * S
    im = Image.new("RGB", ((x1 - x0 + 1) * cw, (y1 - y0 + 1) * cw))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < J["w"] and 0 <= y < J["h"]:
                t = Image.fromarray(L.art.image(L.metatile(x, y))).resize((cw, cw), Image.NEAREST)
                im.paste(t, ((x - x0) * cw, (y - y0) * cw))
    d = ImageDraw.Draw(im)
    try:
        f = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", max(9, S * 3))
    except Exception:
        f = ImageFont.load_default()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if not (0 <= x < J["w"] and 0 <= y < J["h"]):
                continue
            k, top = J["pieces"][y][x]
            lv = int(round(top / 16.0))
            col = PAL[lv % len(PAL)]
            px, py = (x - x0) * cw, (y - y0) * cw
            d.rectangle([px, py, px + cw - 1, py + cw - 1], outline=(40, 40, 40))
            d.rectangle([px + 1, py + 1, px + cw * 0.9, py + S * 4], fill=(0, 0, 0))
            d.text((px + 2, py + 1), "%s%d" % (k, lv), font=f, fill=col)
            d.text((px + 2, py + cw - S * 4), J["kind"][y][x] + J["band"][y][x].replace(".", ""),
                   font=f, fill=(255, 255, 255))
    im.save(out)
    print(out)


if __name__ == "__main__":
    main()
