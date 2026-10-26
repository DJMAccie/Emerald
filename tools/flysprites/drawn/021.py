# Spearow: brown wings with the red-orange primaries of its folded wing tips; feet tucked.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(48, 34), outline=(0, 0, 0), wing=dict(length=10, chord=5, colours=((0xb7, 0x80, 0x21), (0x80, 0x58, 0x20), (0xc8, 0x38, 0x18)), feathers=3, rise=.2), tuck={0: (26, 2), 1: (26, 2), 2: (26, 2), 3: (26, 2)}, shoulder_frac=.35, side_frac=.3)


def build(nat, base, src):
    return D.build_spread(base, P)
