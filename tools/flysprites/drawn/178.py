# Xatu: the follower sprite's folded red wing stubs are erased, then green wings with white leading edges and red
# primaries are drawn out of the shoulders and beaten.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

RED = [(120, 16, 32), (176, 40, 56), (216, 72, 88)]
P = dict(canvas=(56, 38), outline=(0, 0, 0),
         wing=dict(length=14, chord=7, colours=((0xe8, 0xe8, 0xf8), (0x60, 0x90, 0x38), (0xb0, 0x28, 0x38)),
                   feathers=3, rise=.2),
         tuck={0: (26, 2), 1: (26, 2), 2: (26, 2), 3: (26, 2)}, shoulder_frac=.42, side_frac=.4, shoulder_inset=3,
         slopes=D.beat_slopes(-0.65, 0.5))
# (x0, y0, x1, y1) boxes where the red stubs stick out, per row
STUBS = {0: [(0, 10, 10, 21), (22, 10, 32, 21)], 1: [(20, 10, 32, 21)], 2: [(0, 10, 12, 21)],
         3: [(0, 10, 13, 21), (20, 10, 32, 21)]}


def clean(base):
    for r, boxes in STUBS.items():
        for c in range(4):
            f = base['frames'][r][c]
            for box in boxes:
                w, rest = D.mask_colours(f, RED, box)
                f = rest
            base['frames'][r][c] = f
    return base


def build(nat, base, src):
    return D.build_spread(clean(base), P)
