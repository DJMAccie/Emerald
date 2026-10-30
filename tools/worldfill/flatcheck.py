#!/usr/bin/env python3
"""Gate for task 34: how much of a mid-air frame is flat, textureless colour (the old plain sea plane, or sky where
ground should be). Counts 8x8 blocks with a colour spread under 3 in the lower two thirds of the frame (the rider's
box in the middle is left out).

  python3 flatcheck.py <root> [flight ...]      -> one line per mid-air shot: flat share, and the old plane colour share
"""
import os, sys, glob
import numpy as np
from PIL import Image

OLD = np.array([66, 99, 224])


def check(p):
    a = np.asarray(Image.open(p).convert('RGB')).astype(np.int32)
    H, W = a.shape[:2]
    a = a[H // 3:H // 3 * 3 // 8 * 8 + H // 3, :W // 8 * 8]
    h, w = a.shape[0] // 8, a.shape[1] // 8
    a = a[:h * 8, :w * 8]
    b = a.reshape(h, 8, w, 8, 3)
    spread = (b.max(axis=(1, 3)) - b.min(axis=(1, 3))).max(axis=2)
    mask = np.ones((h, w), bool)
    cy, cx = h // 2 - h // 6, w // 2   # the rider sits a little above the middle of the full frame
    mask[max(0, cy - 10):cy + 10, cx - 12:cx + 12] = False
    flat = (spread < 3) & mask
    old = (np.abs(a - OLD).sum(axis=2) < 12).mean()
    return flat.sum() / mask.sum(), old


def main():
    root = sys.argv[1]
    flights = sys.argv[2:] or sorted(os.listdir(root))
    for f in flights:
        for p in sorted(glob.glob(os.path.join(root, f, '*_0[3-6]_*.png'))):
            fl, old = check(p)
            print('%-34s flat %5.1f%%  old plane colour %5.1f%%' % (os.path.basename(p), 100 * fl, 100 * old))


if __name__ == '__main__':
    main()
