# Togetic: its wings are small white tabs on the follower sprite. The tabs on the front/back views are erased and
# a real wing (white, blue feather tips) is drawn out of each shoulder and beaten; sides get the same wing.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D
from PIL import Image

P = dict(canvas=(52, 40), outline=(0x20, 0x28, 0x48),
         wing=dict(length=15, chord=7, colours=((0xf8, 0xf8, 0xff), (0xdc, 0xe0, 0xf4), (0x60, 0x78, 0xc0)),
                   feathers=3, rise=.22),
         side_len=.9, side_frac=.4, shoulder_frac=.5, shoulder_inset=1, slopes=D.beat_slopes(-0.7, 0.55),
         tuck={0: (24, 1), 1: (24, 1), 2: (24, 1), 3: (24, 1)})


def clean(base):
    """Erase the small wing tabs beside the torso on the front and back rows (all four columns)."""
    for r, (lx, rx) in ((0, (9, 22)), (3, (9, 22))):
        for c in range(4):
            f = base['frames'][r][c]
            for box in ((0, 10, lx, 22), (rx, 10, 32, 22)):
                part, rest = D.mask_box(f, box)
                f = rest
            base['frames'][r][c] = f
    return base


def build(nat, base, src):
    return D.build_spread(clean(base), P)
