# Pidgey: wings folded on the follower sprite -> brown wings with tan leading edges, dark primaries; feet tucked.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(48, 34), outline=(0, 0, 0),
         wing=dict(length=11, chord=5, colours=((0xf0, 0xd0, 0x70), (0xc8, 0x70, 0x20), (0x60, 0x40, 0x20)),
                   feathers=3, rise=.2),
         tuck={0: (26, 2), 1: (26, 2), 2: (26, 2), 3: (26, 2)}, shoulder_frac=.4, side_frac=.3)


def build(nat, base, src):
    return D.build_spread(base, P)
