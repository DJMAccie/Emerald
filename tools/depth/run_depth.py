#!/usr/bin/env python3
"""Depth-estimator experiment: can Depth Anything V2 guess our heights from the original 2D art?

Run with the venv (.autoloop/depth/venv/bin/python), from anywhere:
    run_depth.py Route112 Route111 MtChimney [--out DIR]
Per map: renders the 2D art (tools/relief/emdata.py), runs the model, compares per-cell depth with the relief port's
height lattice (tools/relief/terraces.py), writes <Map>_sheet.png, <Map>_depth.npy and one line per map to REPORT.md.
Depth Anything gives relative inverse depth (bigger = nearer); the sign against height is not known in advance, so we
report the rank correlation and the sign it came out with.
"""
import argparse
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image
from scipy.stats import spearmanr

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RELIEF = os.path.join(ROOT, "tools", "relief")
sys.path.insert(0, RELIEF)
import emdata as E  # noqa: E402


def relief_json(name, outdir):
    d = os.path.join(outdir, "relief")
    os.makedirs(d, exist_ok=True)
    L = E.Layout(name)
    p = os.path.join(d, L.id + ".json")
    if not os.path.exists(p):
        subprocess.run([sys.executable, os.path.join(RELIEF, "terraces.py"), name, "--out", d], check=True)
    return L, json.load(open(p))


def render_2d(L):
    im = np.zeros((L.h * 16, L.w * 16, 3), np.uint8)
    for y in range(L.h):
        for x in range(L.w):
            im[y * 16:(y + 1) * 16, x * 16:(x + 1) * 16] = L.art.image(L.metatile(x, y))
    return Image.fromarray(im)


def depth_of(pipe, img, scale):
    big = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    d = pipe(big)["predicted_depth"]
    d = d.squeeze().float().cpu().numpy()
    return np.array(Image.fromarray(d).resize(img.size, Image.BILINEAR))


def per_cell(a, w, h):
    return a.reshape(h, 16, w, 16).mean(axis=(1, 3))


def heat(a, lo=None, hi=None):
    lo = np.nanmin(a) if lo is None else lo
    hi = np.nanmax(a) if hi is None else hi
    g = np.clip((a - lo) / max(hi - lo, 1e-9), 0, 1)
    return np.stack([g * 255, (1 - abs(g - .5) * 2) * 200, (1 - g) * 255], -1).astype(np.uint8)


def rank01(a):
    r = a.ravel().argsort().argsort().astype(float)
    return (r / max(r.max(), 1)).reshape(a.shape)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("maps", nargs="+")
    ap.add_argument("--out", default=os.path.join(ROOT, ".autoloop", "depth", "out"))
    ap.add_argument("--scale", type=int, default=3)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    from transformers import pipeline
    pipe = pipeline("depth-estimation", model="depth-anything/Depth-Anything-V2-Small-hf", device="mps")
    lines = []
    for name in a.maps:
        L, J = relief_json(name, a.out)
        img = render_2d(L)
        D = depth_of(pipe, img, a.scale)
        np.save(os.path.join(a.out, L.id + "_depth.npy"), D)
        dc = per_cell(D, L.w, L.h)
        hc = np.array(J["grids"], float).reshape(L.h, L.w, -1).mean(-1)
        kind = np.array([list(r) for r in J["kind"]])
        rock = np.isin(kind, ["R", "T"])
        ok = np.ones_like(rock)
        rho_all = spearmanr(dc[ok], hc[ok])[0]
        rho_rock = spearmanr(dc[rock], hc[rock])[0] if rock.sum() > 10 else float("nan")
        # cliff edges: neighbours whose relief heights differ by >= 8 px; is the model's order the same way round?
        sgn = 1 if rho_all >= 0 else -1
        agree = tot = 0
        for dy, dx in ((0, 1), (1, 0)):
            h0, h1 = hc[:L.h - dy, :L.w - dx], hc[dy:, dx:]
            d0, d1 = dc[:L.h - dy, :L.w - dx], dc[dy:, dx:]
            m = np.abs(h1 - h0) >= 8
            agree += int((np.sign(h1 - h0)[m] == sgn * np.sign(d1 - d0)[m]).sum())
            tot += int(m.sum())
        edge = agree / tot if tot else float("nan")
        # sheet: 2D | model depth | relief heights | disagreement (rank difference), per-cell panels at 8 px a cell
        S = 8
        up = lambda c: Image.fromarray(c).resize((L.w * S * 2, L.h * S * 2), Image.NEAREST)
        dis = np.abs(rank01(sgn * dc) - rank01(hc))
        panels = [img.resize((L.w * S * 2, L.h * S * 2), Image.NEAREST),
                  Image.fromarray(heat(D)).resize((L.w * S * 2, L.h * S * 2), Image.BILINEAR),
                  up(heat(hc)), up(heat(dis, 0, 1))]
        sheet = Image.new("RGB", (panels[0].width * 2, panels[0].height * 2))
        for i, p in enumerate(panels):
            sheet.paste(p, ((i % 2) * p.width, (i // 2) * p.height))
        sheet.save(os.path.join(a.out, L.id + "_sheet.png"))
        lines.append("%-22s cells %5d  rock %4d  spearman all %+.2f  rock %+.2f  cliff-edge agreement %.0f%% (%d edges)  "
                     "depth std %.3f  sign %s" % (L.id, L.w * L.h, rock.sum(), rho_all, rho_rock, 100 * edge, tot,
                                                  float(D.std()), "+" if sgn > 0 else "-"))
        print(lines[-1], flush=True)
    with open(os.path.join(a.out, "REPORT.md"), "w") as f:
        f.write("# Depth Anything V2 Small vs the relief heights\n\n" + "\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
