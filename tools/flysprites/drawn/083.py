# Farfetch'd: brown wings, pale leading edge, dark primaries; the leek stays in its wing on the body; feet tucked.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import drawlib as D

P = dict(canvas=(52, 34), outline=(0, 0, 0), wing=dict(length=11, chord=5, colours=((0xc8, 0xb8, 0x78), (0xb0, 0x80, 0x48), (0x48, 0x38, 0x28)), feathers=3, rise=.2), tuck={0: (25, 3), 1: (25, 3), 2: (25, 3), 3: (25, 3)}, shoulder_frac=.45, side_frac=.4)


def build(nat, base, src):
    return D.build_spread(base, P)
