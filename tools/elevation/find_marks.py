#!/usr/bin/env python3
# find_marks.py MAP [...]: diff the user's drawn sheet against a clean render, group the strokes into marks,
# print "cell x y  (bbox)" per mark and write /tmp/marks_<MAP>.png: a contact sheet of crops labelled with the cell,
# so the digits can be read in one image. Never touches docs/elevation/draw.
import sys, os, subprocess, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'tools', 'relief'))
from emdata import Layout
CROP = os.path.join(ROOT, 'skills', 'emerald-terrain', 'scripts', 'crop2d.py')
S, H0 = 48, 40
font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 22)
for m in sys.argv[1:]:
    L = Layout(m)
    tmp = tempfile.mktemp(suffix='.png')
    subprocess.run(['python3', CROP, L.slot, L.pair, '0', '0', str(L.w-1), str(L.h-1), tmp, str(S//16)], check=True, capture_output=True)
    clean = np.asarray(Image.open(tmp).convert('RGB')).astype(int); os.unlink(tmp)
    drawn = Image.open(os.path.join(ROOT, 'docs', 'elevation', 'draw', m + '.png')).convert('RGB')
    d = np.asarray(drawn).astype(int)[H0:H0+clean.shape[0], :clean.shape[1]]
    diff = (np.abs(d - clean).sum(axis=2) > 60)
    diff = ndimage.binary_opening(diff, iterations=1)
    lab, n = ndimage.label(ndimage.binary_dilation(diff, iterations=14))
    marks = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        ys, xs = sl; comp = diff[sl] & (lab[sl] == i)
        if comp.sum() < 40: continue
        yy, xx = np.nonzero(comp); cy, cx = ys.start + yy.mean(), xs.start + xx.mean()
        marks.append((int(cx // S), int(cy // S), xs.start, ys.start, xs.stop, ys.stop))
    marks.sort(key=lambda t: (t[1] // 5, t[0]))
    print(m, L.w, L.h, 'marks:', len(marks))
    for k, (x, y, x0, y0, x1, y1) in enumerate(marks): print('  %2d  cell %2d %2d' % (k, x, y))
    # contact sheet
    cw, ch = 220, 180; cols = 6; rows = (len(marks) + cols - 1) // cols or 1
    sheet = Image.new('RGB', (cols * cw, rows * ch), (255, 255, 255)); dr = ImageDraw.Draw(sheet)
    for k, (x, y, x0, y0, x1, y1) in enumerate(marks):
        pad = 30; box = (max(0, x0-pad), max(0, y0-pad+H0), min(drawn.width, x1+pad), min(drawn.height, y1+pad+H0))
        c = drawn.crop(box); c.thumbnail((cw-8, ch-34))
        ox, oy = (k % cols) * cw, (k // cols) * ch
        sheet.paste(c, (ox+4, oy+30)); dr.text((ox+6, oy+4), '#%d  (%d,%d)' % (k, x, y), fill=(0, 0, 0), font=font)
    out = '/tmp/marks_%s.png' % m; sheet.save(out); print('  sheet', out, sheet.size)
