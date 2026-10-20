#!/usr/bin/env python3
"""Contact sheet with labels:  contact.py OUT.png [--cols N] IMG [IMG ...]
Tiles images (default 4 columns) with their file names, for finding frames worth judging. Never judge from it."""
import sys
from PIL import Image, ImageDraw


def main(argv):
    cols = 4
    if '--cols' in argv:
        i = argv.index('--cols')
        cols = int(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    out, imgs = argv[0], argv[1:]
    if not imgs:
        return 1
    w, h = 426, 240
    rows = (len(imgs) + cols - 1) // cols
    sheet = Image.new('RGB', (w * cols, h * rows), 'black')
    d = ImageDraw.Draw(sheet)
    for i, f in enumerate(imgs):
        im = Image.open(f).convert('RGB').resize((w, h), Image.NEAREST)
        x, y = (i % cols) * w, (i // cols) * h
        sheet.paste(im, (x, y))
        d.rectangle([x, y, x + 60, y + 12], fill='black')
        d.text((x + 2, y + 1), f.split('/')[-1], fill='yellow')
    sheet.save(out)
    print(out, len(imgs), 'frames')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
