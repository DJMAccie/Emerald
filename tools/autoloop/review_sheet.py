#!/usr/bin/env python3
"""Before/after sheet of a gate's review captures:  review_sheet.py <gate dir>  -> <gate dir>/sheet_review.png"""
import sys, glob
from PIL import Image, ImageDraw
g = sys.argv[1]; b = sorted(glob.glob(g + '/review_base/b*.png')); f = sorted(glob.glob(g + '/review_fix/b*.png'))
W, H = 640, 360; n = min(len(b), len(f))
if n:
    s = Image.new('RGB', (W * 2, H * n)); d = ImageDraw.Draw(s)
    for i in range(n):
        s.paste(Image.open(b[i]).convert('RGB').resize((W, H), Image.NEAREST), (0, i * H))
        s.paste(Image.open(f[i]).convert('RGB').resize((W, H), Image.NEAREST), (W, i * H))
        d.text((6, i * H + 6), 'BEFORE ' + b[i].split('/')[-1], fill='yellow'); d.text((W + 6, i * H + 6), 'AFTER', fill='yellow')
    s.save(g + '/sheet_review.png'); print('[gate] review sheet', g + '/sheet_review.png', n)
