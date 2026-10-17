#!/usr/bin/env python3
"""A/B sheets: our in-game captures beside the 3DS relief prototype.

    python3 ab.py RELIEF_DIR OURS_DIR OUT_DIR

RELIEF_DIR holds terraces.py's JSON; OURS_DIR one qa_run.sh capture of
CASES at levels "4,7" (files MAP_L.png, MAP_L_<frame>.png in case order).
Renders "theirs" and "soft" for every case and level, then one sheet per
group: rows = spot x camera, columns = ours | 3DS relief | 3DS + soft tops.
"""
import glob
import os
import re
import sys
from multiprocessing import Pool

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# (layout key, x, y, rock class): walkable cells 1-2 rows south of rock
CASES = [
    ("EM_ROUTE114", 20, 10, "brown terrace (Fallarbor tiles)"),
    ("EM_ROUTE114", 8, 13, "brown terrace (Fallarbor tiles)"),
    ("EM_ROUTE114", 7, 50, "beige mountain (General rock, recoloured)"),
    ("EM_ROUTE114", 26, 58, "beige mountain (General rock, recoloured)"),
    ("EM_FALLARBOR_TOWN", 12, 6, "brown terrace (Fallarbor tiles)"),
    ("EM_ROUTE111", 32, 128, "pink General mountain"),
    ("EM_ROUTE111", 7, 63, "pink General mountain"),
    ("EM_ROUTE111", 22, 102, "pink General mountain"),
    ("EM_ROUTE112", 11, 26, "red mountain (Lavaridge tiles)"),
    ("EM_ROUTE112", 20, 22, "red mountain (Lavaridge tiles)"),
    ("EM_ROUTE112", 24, 44, "red mountain (Lavaridge tiles)"),
    ("EM_MT_CHIMNEY", 30, 29, "red mountain (Lavaridge tiles)"),
    ("EM_MT_CHIMNEY", 10, 31, "red mountain (Lavaridge tiles)"),
]
GROUPS = [
    ("route114", "Route 114", ["EM_ROUTE114"]),
    ("route111", "Route 111", ["EM_ROUTE111"]),
    ("route112_chimney", "Route 112 + Mt. Chimney", ["EM_ROUTE112", "EM_MT_CHIMNEY"]),
    ("fallarbor", "Fallarbor Town", ["EM_FALLARBOR_TOWN"]),
]
JSON_NAME = {"EM_ROUTE114": "Route114", "EM_ROUTE111": "Route111", "EM_ROUTE112": "Route112",
             "EM_MT_CHIMNEY": "MtChimney", "EM_FALLARBOR_TOWN": "FallarborTown"}
LEVELS = (4, 7)
CAMERA = {4: "player camera (level 4)", 7: "low camera (level 7)"}


def ours_files(ours):
    """{(case index, level): png} - a map's shots come in case order."""
    out = {}
    for level in LEVELS:
        by_map = {}
        for i, (m, x, y, _) in enumerate(CASES):
            by_map.setdefault(m, []).append(i)
        for m, idx in by_map.items():
            files = []
            for f in glob.glob(os.path.join(ours, "%s_%d*.png" % (m, level))):
                k = re.match(r".*_%d(?:_(\d+))?\.png$" % level, f)
                if k and os.path.basename(f).startswith(m + "_%d" % level):
                    files.append((int(k.group(1) or 0), f))
            files.sort()
            for i, (_, f) in zip(idx, files):
                out[(i, level)] = f
    return out


def _job(args):
    import render
    path, x, y, level, out, variant = args
    if not os.path.exists(out):
        render.render(path, x, y, level, out, variant)
    return out


def font(size):
    for f in ("/System/Library/Fonts/HelveticaNeue.ttc", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(f, size)
        except Exception:
            pass
    return ImageFont.load_default()


def main():
    relief, ours, outdir = sys.argv[1:4]
    os.makedirs(outdir, exist_ok=True)
    rd = os.path.join(outdir, "renders")
    os.makedirs(rd, exist_ok=True)
    jobs = []
    for i, (m, x, y, _) in enumerate(CASES):
        for level in LEVELS:
            for variant in ("theirs", "soft"):
                jobs.append((os.path.join(relief, JSON_NAME[m] + ".json"), x, y, level,
                             os.path.join(rd, "%s_%d_%d_L%d_%s.png" % (m, x, y, level, variant)), variant))
    with Pool(6) as p:
        p.map(_job, jobs)
    shots = ours_files(ours)
    TW, TH = 640, 360
    head, lab = font(30), font(20)
    cols = ["OURS (in game now)", "3DS RELIEF (ported, offline)", "3DS + OUR SOFT TOPS (offline)"]
    sheets = []
    for key, title, maps in GROUPS:
        rows = [(i, level) for i, c in enumerate(CASES) if c[0] in maps for level in LEVELS]
        W = 3 * TW + 4 * 10
        H = 70 + 40 + len(rows) * (TH + 34) + 10
        sheet = Image.new("RGB", (W, H), (24, 24, 28))
        d = ImageDraw.Draw(sheet)
        d.text((10, 14), "%s - rock A/B: ours vs Emerald 3DS's relief method" % title, font=head, fill=(255, 255, 255))
        d.text((W - 900, 22), "offline: grey = outside the map; trees are flat cards, houses flat (3DS models those apart)",
               font=font(17), fill=(170, 170, 170))
        for k, cname in enumerate(cols):
            d.text((10 + k * (TW + 10), 76), cname, font=lab, fill=(255, 220, 120))
        yy = 110
        for (i, level) in rows:
            m, x, y, cls = CASES[i]
            d.text((10, yy + 6), "%s (%d,%d)  -  %s  -  %s" % (m[3:], x, y, cls, CAMERA[level]),
                   font=lab, fill=(200, 220, 255))
            yy += 34
            imgs = [shots.get((i, level)),
                    os.path.join(rd, "%s_%d_%d_L%d_theirs.png" % (m, x, y, level)),
                    os.path.join(rd, "%s_%d_%d_L%d_soft.png" % (m, x, y, level))]
            for k, f in enumerate(imgs):
                if f and os.path.exists(f):
                    im = Image.open(f).convert("RGB").resize((TW, TH), Image.LANCZOS)
                    sheet.paste(im, (10 + k * (TW + 10), yy))
                else:
                    d.text((10 + k * (TW + 10) + 20, yy + 20), "missing", font=lab, fill=(255, 80, 80))
            yy += TH
        path = os.path.join(outdir, "relief_ab_%s.png" % key)
        sheet.save(path)
        sheets.append(path)
        print(path)
    return sheets


if __name__ == "__main__":
    main()
