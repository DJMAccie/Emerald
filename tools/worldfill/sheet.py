#!/usr/bin/env python3
"""Before/after sheet for task 34: the same flight's mid-air frames without and with the whole-world ground.

  python3 sheet.py <before_root> <after_root> <out.png> flight[,flight...] [--frames 03_30,04_50,05_70]

<root>/<flight>/<flight>_<frame>.png are qa_flights.sh captures. Each flight is two rows (before, after), frames
side by side at 1/3 scale, labelled.
"""
import os, sys, argparse
from PIL import Image, ImageDraw


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('before'); ap.add_argument('after'); ap.add_argument('out'); ap.add_argument('flights')
    ap.add_argument('--frames', default='03_30,04_50,05_70')
    ap.add_argument('--scale', type=float, default=1 / 3)
    a = ap.parse_args()
    flights = a.flights.split(','); frames = a.frames.split(',')
    W, H = int(1280 * a.scale), int(720 * a.scale)
    pad, lab = 6, 18
    rows = []
    for f in flights:
        for tag, root in (('before', a.before), ('after', a.after)):
            rows.append((f, tag, [os.path.join(root, f, '%s_%s.png' % (f, fr)) for fr in frames]))
    sheet = Image.new('RGB', (pad + len(frames) * (W + pad), pad + len(rows) * (H + lab + pad)), (22, 22, 26))
    d = ImageDraw.Draw(sheet)
    for r, (f, tag, paths) in enumerate(rows):
        y = pad + r * (H + lab + pad)
        d.text((pad, y + 3), '%s - %s (no fill)' % (f, tag) if tag == 'before' else '%s - %s (whole-world ground)' % (f, tag),
               fill=(230, 230, 230))
        for c, p in enumerate(paths):
            x = pad + c * (W + pad)
            if os.path.exists(p):
                sheet.paste(Image.open(p).convert('RGB').resize((W, H), Image.LANCZOS), (x, y + lab))
            else:
                d.rectangle((x, y + lab, x + W, y + lab + H), outline=(120, 60, 60))
                d.text((x + 8, y + lab + 8), 'missing ' + os.path.basename(p), fill=(200, 120, 120))
    sheet.save(a.out)
    print('wrote', a.out, sheet.size)


if __name__ == '__main__':
    main()
