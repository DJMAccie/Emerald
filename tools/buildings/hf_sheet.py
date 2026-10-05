#!/usr/bin/env python3
"""Contact sheet of one hf recipe: art | head-on | free-camera yaws."""
import sys, os
from PIL import Image
d = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'shots_bld', 'hf')
name = sys.argv[1]
parts = sys.argv[2:] or ['art', 'l4_y000', 'l7_y000', 'l7_y090', 'l7_y180', 'l7_y270']
ims = [Image.open(os.path.join(d, '%s_%s.png' % (name, p))) for p in parts]
h = max(i.height for i in ims); w = sum(i.width for i in ims) + 8 * len(ims)
s = Image.new('RGB', (w, h), (10, 10, 12)); x = 0
for i in ims:
    s.paste(i, (x, 0)); x += i.width + 8
s.save(os.path.join(d, 'sheet_%s.png' % name)); print(s.size)
